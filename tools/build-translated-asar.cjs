#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const inputPath = path.resolve(process.argv[2] || path.join(root, 'app.asar'));
const outputPath = path.resolve(process.argv[3] || path.join(root, 'app-pt.asar'));
const translationsPath = path.join(root, 'translations', 'pt-BR.json');
const defaultBlockSize = 4 * 1024 * 1024;

function fail(message) {
  throw new Error(message);
}

function verifyJavaScriptSyntax(source, outputPath) {
  const checkPath = `${outputPath}.syntax-check.mjs`;
  try {
    fs.writeFileSync(checkPath, source);
    const result = spawnSync(process.execPath, ['--check', checkPath], { encoding: 'utf8' });
    if (result.error) fail(`Não foi possível validar a sintaxe do bundle: ${result.error.message}`);
    if (result.status !== 0) {
      fail(`O bundle JavaScript gerado tem erro de sintaxe:\n${(result.stderr || result.stdout).trim()}`);
    }
  } finally {
    fs.rmSync(checkPath, { force: true });
  }
}

function readArchive(filePath) {
  const data = fs.readFileSync(filePath);
  if (data.length < 18 || data.readUInt32LE(0) !== 4) fail(`Cabeçalho ASAR inválido: ${filePath}`);

  const pickleSize = data.readUInt32LE(4);
  const jsonLength = data.readUInt32LE(12);
  const dataStart = 8 + pickleSize;
  if (dataStart > data.length || jsonLength > data.length - 16) fail(`Tamanho do cabeçalho ASAR inválido: ${filePath}`);

  let header;
  try {
    header = JSON.parse(data.subarray(16, 16 + jsonLength).toString('utf8'));
  } catch (error) {
    fail(`JSON do cabeçalho ASAR inválido: ${error.message}`);
  }
  if (!header || typeof header.files !== 'object') fail('O cabeçalho ASAR não contém a árvore de arquivos.');

  const files = [];
  const visit = (entries, parent = '') => {
    for (const [name, entry] of Object.entries(entries)) {
      const archivePath = parent ? `${parent}/${name}` : name;
      if (entry && entry.files) {
        visit(entry.files, archivePath);
        continue;
      }
      if (!entry || entry.unpacked || entry.link || entry.offset === undefined || !Number.isSafeInteger(Number(entry.size))) {
        fail(`Entrada ASAR não suportada ou inválida: ${archivePath}`);
      }
      const offset = Number(entry.offset);
      const size = Number(entry.size);
      if (!Number.isSafeInteger(offset) || offset < 0 || size < 0 || dataStart + offset + size > data.length) {
        fail(`Faixa de dados inválida no ASAR: ${archivePath}`);
      }
      files.push({ path: archivePath, entry, offset, size });
    }
  };
  visit(header.files);
  files.sort((a, b) => a.offset - b.offset);

  let expectedOffset = 0;
  let previousRange = null;
  for (const file of files) {
    if (file.offset < expectedOffset) {
      const isSharedFile = previousRange
        && file.offset === previousRange.offset
        && file.size === previousRange.size;
      if (!isSharedFile) fail(`Sobreposição no ASAR antes de ${file.path}`);
      const current = data.subarray(dataStart + file.offset, dataStart + file.offset + file.size);
      const previous = data.subarray(dataStart + previousRange.offset, dataStart + previousRange.offset + previousRange.size);
      if (!current.equals(previous)) fail(`Arquivos compartilhados divergentes no ASAR: ${file.path}`);
      continue;
    }
    if (file.offset !== expectedOffset) fail(`Lacuna no ASAR antes de ${file.path}`);
    previousRange = { offset: file.offset, size: file.size };
    expectedOffset += file.size;
  }
  if (dataStart + expectedOffset !== data.length) fail('O tamanho dos dados não corresponde ao cabeçalho ASAR.');
  return { data, dataStart, header, files };
}

function digest(buffer, blockSize = defaultBlockSize) {
  const blocks = [];
  for (let offset = 0; offset < buffer.length; offset += blockSize) {
    blocks.push(crypto.createHash('sha256').update(buffer.subarray(offset, Math.min(offset + blockSize, buffer.length))).digest('hex'));
  }
  if (blocks.length === 0) blocks.push(crypto.createHash('sha256').update(Buffer.alloc(0)).digest('hex'));
  return {
    algorithm: 'SHA256',
    hash: crypto.createHash('sha256').update(buffer).digest('hex'),
    blockSize,
    blocks
  };
}

function verifyIntegrity(archive) {
  for (const file of archive.files) {
    const actual = archive.data.subarray(archive.dataStart + file.offset, archive.dataStart + file.offset + file.size);
    const expected = file.entry.integrity;
    if (!expected || expected.algorithm !== 'SHA256') fail(`Hash SHA-256 ausente em ${file.path}`);
    const computed = digest(actual, expected.blockSize || defaultBlockSize);
    if (computed.hash !== expected.hash || JSON.stringify(computed.blocks) !== JSON.stringify(expected.blocks)) {
      fail(`Falha na verificação de integridade de ${file.path}`);
    }
  }
}

function matchingBrace(source, openIndex) {
  let depth = 0;
  let quote = '';
  let escaped = false;
  for (let i = openIndex; i < source.length; i += 1) {
    const char = source[i];
    if (quote) {
      if (escaped) escaped = false;
      else if (char === '\\') escaped = true;
      else if (char === quote) quote = '';
      continue;
    }
    if (char === '"' || char === "'" || char === '`') {
      quote = char;
      continue;
    }
    if (char === '{') depth += 1;
    else if (char === '}' && --depth === 0) return i;
  }
  fail('Não foi possível localizar o fim de um catálogo de tradução.');
}

function replaceDefaultCatalog(source, translations) {
  const marker = source.includes(',Oi={') ? ',Oi={' : 'Ki={';
  const markerIndex = source.indexOf(marker);
  if (markerIndex < 0) fail('Catálogo de interface não encontrado no bundle.');
  const openIndex = source.indexOf('{', markerIndex);
  const closeIndex = matchingBrace(source, openIndex);
  let catalog = source.slice(openIndex, closeIndex + 1);
  let matched = 0;
  const missing = [];

  for (const [key, value] of Object.entries(translations)) {
    const property = `${JSON.stringify(key)}:\``;
    const propertyIndex = catalog.indexOf(property);
    if (propertyIndex < 0) {
      missing.push(key);
      continue;
    }
    const valueStart = propertyIndex + property.length;
    const valueEnd = catalog.indexOf('`', valueStart);
    if (valueEnd < 0) fail(`Valor inválido para ${key} no catálogo base PT-BR.`);
    catalog = catalog.slice(0, valueStart) + value + catalog.slice(valueEnd);
    matched += 1;
  }
  if (matched < Math.floor(Object.keys(translations).length * 0.85)) {
    fail(`O catálogo desta versão mudou demais (${matched}/${Object.keys(translations).length} chaves localizadas); pacote não gerado.`);
  }
  if (missing.length) console.warn(`[AVISO] ${missing.length} chaves não existem neste catálogo e foram ignoradas: ${missing.join(', ')}`);
  return source.slice(0, openIndex) + catalog + source.slice(closeIndex + 1);
}

function addCurrentPtBrLocale(source, translations) {
  if (!source.includes('Ki={') || !source.includes('qi={')) return source;

  const catalogRange = findObjectRange(source, 'Ki={');
  const englishCatalog = source.slice(catalogRange.start, catalogRange.end + 1);
  const missingKeys = Object.keys(translations).filter(key => !englishCatalog.includes(`${JSON.stringify(key)}:`));
  if (missingKeys.length > Math.ceil(Object.keys(translations).length * 0.15)) {
    fail(`O catálogo desta versão mudou demais (${Object.keys(translations).length - missingKeys.length}/${Object.keys(translations).length} chaves localizadas); pacote não gerado.`);
  }
  if (missingKeys.length) console.warn(`[AVISO] ${missingKeys.length} chaves não existem neste catálogo e foram ignoradas: ${missingKeys.join(', ')}`);

  const languageOption = '{id:`pt-BR`,label:`Português (Brasil)`,locale:`pt-BR`}';
  if (!source.includes('id:`pt-BR`')) {
    const englishOption = '{id:`en`,label:`English`,locale:`en-US`}';
    if (!source.includes(englishOption)) fail('Não foi possível localizar as opções de idioma da interface.');
    source = source.replace(englishOption, `${englishOption},${languageOption}`);
  }

  const languageDetect = 'let e=typeof navigator>`u`?``:navigator.language||``;if(/^zh/i.test(e))';
  if (source.includes(languageDetect) && !source.includes('if(/^pt(?:-|$)/i.test(e))')) {
    source = source.replace(languageDetect, 'let e=typeof navigator>`u`?``:navigator.language||``;if(/^pt(?:-|$)/i.test(e))return`pt-BR`;if(/^zh/i.test(e))');
  }
  if (!source.includes('if(/^pt(?:-|$)/i.test(e))')) fail('A detecção automática do idioma do sistema mudou; não foi possível configurar pt-BR com segurança.');

  const localeRange = findObjectRange(source, 'qi={');
  if (source.slice(localeRange.start, localeRange.end + 1).includes('"pt-BR":')) return source;
  const entries = Object.entries(translations)
    .filter(([key]) => !missingKeys.includes(key))
    .map(([key, value]) => `${JSON.stringify(key)}:${JSON.stringify(value)}`);
  return source.slice(0, localeRange.end) + `,"pt-BR":{${entries.join(',')}}` + source.slice(localeRange.end);
}

function addPtBrCatalogEntries(source, translations) {
  const localesIndex = source.indexOf('ki={');
  if (localesIndex < 0) fail('Catálogo de idiomas não encontrado no bundle.');
  const localeMarker = '"pt-BR":{';
  const localeIndex = source.indexOf(localeMarker, localesIndex);
  if (localeIndex < 0) fail('Catálogo pt-BR não encontrado no bundle.');
  const openIndex = source.indexOf('{', localeIndex);
  const closeIndex = matchingBrace(source, openIndex);
  const catalog = source.slice(openIndex, closeIndex + 1);
  const additions = [];

  for (const [key, value] of Object.entries(translations)) {
    if (catalog.includes(`${JSON.stringify(key)}:`)) continue;
    additions.push(`${JSON.stringify(key)}:${JSON.stringify(value)}`);
  }
  if (additions.length === 0) return source;
  return source.slice(0, closeIndex) + `,${additions.join(',')}` + source.slice(closeIndex);
}

function findObjectRange(source, marker, fromIndex = 0) {
  const markerIndex = source.indexOf(marker, fromIndex);
  if (markerIndex < 0) fail(`Catálogo não encontrado: ${marker}`);
  const openIndex = source.indexOf('{', markerIndex);
  return { start: openIndex, end: matchingBrace(source, openIndex) };
}

function replaceInlineLiterals(source, translations) {
  const catalogMarker = source.includes(',Oi={') ? ',Oi={' : 'Ki={';
  const localeMarker = source.includes('ki={') ? 'ki={' : 'qi={';
  const protectedRanges = [findObjectRange(source, catalogMarker), findObjectRange(source, localeMarker)]
    .sort((a, b) => a.start - b.start);
  const candidates = [];
  for (const translation of translations) {
    let index = source.indexOf(translation.source);
    while (index >= 0) {
      const protectedRange = protectedRanges.find(range => index >= range.start && index <= range.end);
      const quote = source[index - 1];
      const isWholeLiteral = !translation.exact || (
        (quote === '`' || quote === '"' || quote === "'")
        && source[index + translation.source.length] === quote
      );
      if (!protectedRange && isWholeLiteral) {
        candidates.push({ index, source: translation.source, target: translation.target });
      }
      index = source.indexOf(translation.source, index + translation.source.length);
    }
  }

  candidates.sort((a, b) => a.index - b.index || b.source.length - a.source.length);
  const replacements = [];
  const found = new Set();
  for (const candidate of candidates) {
    const previous = replacements[replacements.length - 1];
    if (previous && candidate.index < previous.index + previous.source.length) {
      const isContained = candidate.index >= previous.index
        && candidate.index + candidate.source.length <= previous.index + previous.source.length;
      if (!isContained) fail(`Traduções literais se sobrepõem sem contenção: ${previous.source} | ${candidate.source}`);
      found.add(candidate.source);
      continue;
    }
    replacements.push(candidate);
    found.add(candidate.source);
  }

  const missing = translations.map(item => item.source).filter(value => !found.has(value));
  if (missing.length) fail(`Literais de interface não localizados fora dos catálogos: ${missing.join(' | ')}`);
  replacements.sort((a, b) => b.index - a.index);
  let result = source;
  for (const replacement of replacements) {
    result = result.slice(0, replacement.index) + replacement.target + result.slice(replacement.index + replacement.source.length);
  }
  return result;
}

function localizeDynamicUiMessages(source) {
  const marker = 'function U({children:e,tone:t=`neutral`})';
  const helper = 'function codexRouterPtText(e){let t=document.documentElement.lang||navigator.language||``;if(!/^pt(?:-|$)/i.test(t)||typeof e!==`string`)return e;let n={"A previous sign-in may still be running. Verify that no Codex login process remains before manually clearing its saved ownership.":"Uma tentativa de login anterior ainda pode estar em andamento. Verifique se não há um processo de login do Codex ativo antes de limpar manualmente os dados de vínculo salvos.","Each model here names its own endpoint. Enabling the provider costs nothing; a model that needs a key says so on its own row.":"Cada modelo indica seu próprio endpoint. Ativar o provedor não tem custo; os modelos que exigem uma chave informam isso na própria linha.","Runs on this machine. Start the LM Studio local server before using these models.":"Executa neste computador. Inicie o servidor local do LM Studio antes de usar estes modelos.","Runs on this machine. Start Ollama before using these models.":"Executa neste computador. Inicie o Ollama antes de usar estes modelos.","Reads codes, numbers, and dates exactly. The default choice.":"Lê códigos, números e datas com precisão. É a opção padrão.","Larger sibling of the 3B. Not benchmarked here yet.":"Versão maior do modelo 3B. Ainda não foi avaliada neste teste.","Strongest reasoning of the set. Not benchmarked here yet.":"Maior capacidade de raciocínio do conjunto. Ainda não foi avaliado neste teste.","Tiny and quick, but transcribed none of the test text.":"Pequeno e rápido, mas não transcreveu nenhum texto do teste.","Scored zero on the benchmark and is the slowest. Avoid for text.":"Obteve pontuação zero no teste e é o mais lento. Evite usá-lo para textos.",accurate:`preciso`,untested:`não testado`,"cartoons-only":`somente desenhos`,Custom:`Personalizado`,"Per-model endpoints":`Endpoints por modelo`,"Sign-in":`Entrar`,Low:`Baixo`,Medium:`Médio`,High:`Alto`,Xhigh:`Extra alto`,Max:`Máximo`,Ultra:`Ultra`,Default:`Padrão do modelo`,low:`Baixo`,medium:`Médio`,high:`Alto`,xhigh:`Extra alto`,max:`Máximo`,ultra:`Ultra`};return n[e]??e}';
  const usageDetailHelper = 'function codexRouterPtUsageDetail(e,t,n){let r=document.documentElement.lang||navigator.language||``;if(!/^pt(?:-|$)/i.test(r))return e.id===`openai`?`Same subscription OpenAI reports below, counted here across ${t?`all retained`:`${n}-day`} router events; the two totals are not comparable`:`${e.credentialType?.toUpperCase()||`Provider`} traffic measured by this router${t?` across all retained events`:``}`;if(e.id===`openai`)return`A mesma assinatura informada pela OpenAI aparece abaixo, contabilizada aqui em ${t?`todos os eventos mantidos`:`${n} dias de eventos do roteador`}; os dois totais não são comparáveis`;let o=e.credentialType?.toUpperCase(),a=o===`OAUTH`?`Tráfego OAuth`:o===`API`?`Tráfego pela API`:`Tráfego do provedor`;return`${a} medido por este roteador${t?` em todos os eventos mantidos`:``}`}';
  const activitySummaryHelper = 'function codexRouterPtActivitySummary(e,t,n,r){let i=document.documentElement.lang||navigator.language||``;if(!/^pt(?:-|$)/i.test(i))return e?`${V(t)} measured tokens across the last year`:n?`Reading the retained router ledger`:r?`Recent event telemetry; retained daily totals are unavailable`:`Token history appears after the router reports usage`;return e?`${V(t)} tokens medidos ao longo do último ano`:n?`Lendo o histórico mantido pelo roteador`:r?`Telemetria recente de eventos; os totais diários mantidos não estão disponíveis`:`O histórico de tokens aparecerá quando o roteador informar o uso`}';
  const activityTooltipHelper = 'function codexRouterPtActivityTooltip(e,t,n,r,i){let a=document.documentElement.lang||navigator.language||``;if(!/^pt(?:-|$)/i.test(a))return e===`weekly`?`${V(t)} tokens from ${n.format(r)} to ${n.format(i)}`:e===`cumulative`?`${V(t)} cumulative tokens through ${n.format(r)}`:`${V(t)} tokens on ${n.format(r)}`;return e===`weekly`?`${V(t)} tokens de ${n.format(r)} a ${n.format(i)}`:e===`cumulative`?`${V(t)} tokens acumulados até ${n.format(r)}`:`${V(t)} tokens em ${n.format(r)}`}';
  const pluralizer = 'function codexRouterPtPlural(e,t){let n=document.documentElement.lang||navigator.language||``;if(/^pt(?:-|$)/i.test(n)){let r={request:[`solicitação`,`solicitações`],chat:[`conversa`,`conversas`],route:[`rota`,`rotas`],model:[`modelo`,`modelos`],provider:[`provedor`,`provedores`],session:[`sessão`,`sessões`]};if(r[t])return r[t][e===1?0:1]}return e===1?t:`${t}s`}';
  if (source.split(marker).length - 1 !== 1) fail('Ponto de inserção das traduções dinâmicas mudou.');
  source = source.replace(marker, `${helper}${usageDetailHelper}${activitySummaryHelper}${activityTooltipHelper}${pluralizer}${marker}`);

  const replacements = [
    ['children:l?.planNote||Hi(e,t?.account?.status,t?.account?.message,r===`darwin`)', 'children:codexRouterPtText(l?.planNote||Hi(e,t?.account?.status,t?.account?.message,r===`darwin`))'],
    ['n?.status===`failed`?(0,H.jsx)(`small`,{children:n.error}):null', 'n?.status===`failed`?(0,H.jsx)(`small`,{children:codexRouterPtText(n.error)}):null'],
    ['(0,H.jsx)(`strong`,{children:e.displayName}),(0,H.jsx)(`small`,{children:Vi(e)})', '(0,H.jsx)(`strong`,{children:codexRouterPtText(e.displayName)}),(0,H.jsx)(`small`,{children:codexRouterPtText(Vi(e))})'],
    [',t.requests===1?`request`:`requests`,` até agora`', ',codexRouterPtPlural(t.requests,`request`),` até agora`'],
    ['children:Ii(r)', 'children:codexRouterPtText(Ii(r))'],
    ['children:Ii(e)', 'children:codexRouterPtText(Ii(e))'],
    ['children:e.accuracy||`untested`', 'children:codexRouterPtText(e.accuracy||`untested`)'],
    ['children:e.note||`Local model for pasted-image transcription.`', 'children:codexRouterPtText(e.note||`Local model for pasted-image transcription.`)'],
    ['N.map(e=>(0,H.jsx)(`option`,{value:e,children:e},e))', 'N.map(e=>(0,H.jsx)(`option`,{value:e,children:codexRouterPtText(e)},e))'],
    ['children:[ue.length,` famil`,ue.length===1?`y`:`ies`,` · `,qr(ue),` `,p.trim()?`matches`:`tags`]', 'children:[ue.length,` `,ue.length===1?`família`:`famílias`,` · `,qr(ue),` `,p.trim()?`correspondências`:`etiquetas`]'],
    ['children:[e.models.length,` tags · `,Jr(e.models)]', 'children:[e.models.length,` etiquetas · `,Jr(e.models)]'],
    ['detail:n.id===`openai`?`Same subscription OpenAI reports below, counted here across ${f?`all retained`:`${ja}-day`} router events; the two totals are not comparable`:`${n.credentialType?.toUpperCase()||`Provider`} traffic measured by this router${f?` across all retained events`:``}`', 'detail:codexRouterPtUsageDetail(n,f,ja)'],
    ['t?`${V(l)} measured tokens across the last year`:n?`Reading the retained router ledger`:e?`Recent event telemetry; retained daily totals are unavailable`:`Token history appears after the router reports usage`', 'codexRouterPtActivitySummary(t,l,n,e)'],
    ['`${V(o)} tokens from ${n.format(t)} to ${n.format(i)}`', 'codexRouterPtActivityTooltip(`weekly`,o,n,t,i)'],
    ['`${V(i)} cumulative tokens through ${n.format(a.date)}`', 'codexRouterPtActivityTooltip(`cumulative`,i,n,a.date)'],
    ['`${V(a.tokens)} tokens on ${n.format(a.date)}`', 'codexRouterPtActivityTooltip(`daily`,a.tokens,n,a.date)'],
    ['function hr(e,t){return e===1?t:`${t}s`}', 'function hr(e,t){return codexRouterPtPlural(e,t)}']
  ];
  for (const [before, after] of replacements) {
    if (!source.includes(before)) fail(`Ponto de tradução dinâmica não encontrado: ${before}`);
    source = source.replace(before, after);
  }
  return { source, count: 31 };
}

function localizeNumberDateFormatting(source) {
  const formatters = [
    ['.toLocaleString(`en-US`)', '.toLocaleString(document.documentElement.lang||navigator.language||`en-US`)', 2],
    ['new Intl.DateTimeFormat(`en-US`,', 'new Intl.DateTimeFormat(document.documentElement.lang||navigator.language||`en-US`,', 1],
    ['new Intl.NumberFormat(`en-US`,', 'new Intl.NumberFormat(document.documentElement.lang||navigator.language||`en-US`,', 1]
  ];
  for (const [before, after, minimum] of formatters) {
    const count = source.split(before).length - 1;
    if (count < minimum) fail(`Formatador localizado não encontrado ou mudou: ${before}`);
    source = source.replaceAll(before, after);
  }

  const compactMarker = 'function B(e){';
  const compactStart = source.indexOf(compactMarker);
  if (compactStart < 0) fail('Formatador compacto de números não encontrado.');
  const compactOpen = source.indexOf('{', compactStart);
  const compactEnd = matchingBrace(source, compactOpen);
  let compact = source.slice(compactStart, compactEnd + 1);
  compact = compact.replace('function B(e){let t=', 'function B(e){let n=document.documentElement.lang||navigator.language||`en-US`,t=');
  for (const [before, after] of [
    ['${et(t/1e3,+(t<1e4))}k', '${et(t/1e3,+(t<1e4))}${n.startsWith(\'pt\') ? \' mil\' : \'k\'}'],
    ['${et(t/1e6,+(t<1e7))}m', '${et(t/1e6,+(t<1e7))}${n.startsWith(\'pt\') ? \' mi\' : \'m\'}'],
    ['${et(t/1e9,+(t<1e10))}b', '${et(t/1e9,+(t<1e10))}${n.startsWith(\'pt\') ? \' bi\' : \'b\'}']
  ]) {
    if (!compact.includes(before)) fail(`Sufixo do formatador compacto não encontrado: ${before}`);
    compact = compact.replace(before, after);
  }
  source = source.slice(0, compactStart) + compact + source.slice(compactEnd + 1);

  const decimalBefore = 'function et(e,t){return e.toFixed(t).replace(/\\.0$/,``)}';
  const decimalAfter = 'function et(e,t){return new Intl.NumberFormat(document.documentElement.lang||navigator.language||`en-US`,{minimumFractionDigits:0,maximumFractionDigits:t}).format(e)}';
  if (!source.includes(decimalBefore)) fail('Formatador de decimais compactos não encontrado.');
  return source.replace(decimalBefore, decimalAfter);
}

function updateEntryIntegrity(entry, content) {
  entry.size = content.length;
  entry.integrity = digest(content, entry.integrity?.blockSize || defaultBlockSize);
}

function packArchive(header, files) {
  const chunks = [];
  let offset = 0;
  for (const file of files) {
    file.entry.offset = String(offset);
    file.entry.size = file.content.length;
    offset += file.content.length;
    chunks.push(file.content);
  }

  const json = Buffer.from(JSON.stringify(header), 'utf8');
  const pickleSize = json.length + 10;
  const headerBuffer = Buffer.alloc(8 + pickleSize);
  headerBuffer.writeUInt32LE(4, 0);
  headerBuffer.writeUInt32LE(pickleSize, 4);
  headerBuffer.writeUInt32LE(json.length + 6, 8);
  headerBuffer.writeUInt32LE(json.length, 12);
  json.copy(headerBuffer, 16);
  return Buffer.concat([headerBuffer, ...chunks]);
}

function main() {
  if (inputPath === outputPath) fail('O arquivo de entrada e o de saída precisam ser diferentes.');
  const translations = JSON.parse(fs.readFileSync(translationsPath, 'utf8'));
  if (!translations || Object.keys(translations).length === 0) fail('O catálogo PT-BR está vazio.');
  const inlineTranslations = [
    ...JSON.parse(fs.readFileSync(path.join(root, 'translations', 'inline-pt-BR.json'), 'utf8')),
    ...JSON.parse(fs.readFileSync(path.join(root, 'translations', 'inline-pt-BR-extra.json'), 'utf8'))
  ];
  if (!Array.isArray(inlineTranslations)) fail('Os arquivos de traduções literais precisam conter listas.');
  const duplicateLiterals = inlineTranslations.map(item => item.source).filter((source, index, all) => all.indexOf(source) !== index);
  if (duplicateLiterals.length) fail(`Há traduções literais duplicadas: ${[...new Set(duplicateLiterals)].join(', ')}`);

  const archive = readArchive(inputPath);
  verifyIntegrity(archive);
  const bundleFiles = archive.files.filter(file => /^dist\/assets\/index-[^/]+\.js$/.test(file.path));
  if (bundleFiles.length !== 1) fail(`Esperado um bundle principal da interface; encontrados ${bundleFiles.length}.`);

  const bundleFile = bundleFiles[0];
  const originalBundle = archive.data.subarray(archive.dataStart + bundleFile.offset, archive.dataStart + bundleFile.offset + bundleFile.size);
  let bundle = originalBundle.toString('utf8');
  const isCurrentLocaleArchitecture = bundle.includes('Ki={') && bundle.includes('qi={');
  if (isCurrentLocaleArchitecture) {
    bundle = addCurrentPtBrLocale(bundle, translations);
  } else {
    bundle = replaceDefaultCatalog(bundle, translations);
    bundle = addPtBrCatalogEntries(bundle, translations);
  }
  bundle = replaceInlineLiterals(bundle, inlineTranslations);
  const dynamicUi = localizeDynamicUiMessages(bundle);
  bundle = dynamicUi.source;
  bundle = localizeNumberDateFormatting(bundle);
  verifyJavaScriptSyntax(bundle, outputPath);
  const translatedBundle = Buffer.from(bundle, 'utf8');
  if (translatedBundle.equals(originalBundle)) fail('Nenhuma tradução foi aplicada ao bundle.');
  updateEntryIntegrity(bundleFile.entry, translatedBundle);

  const files = archive.files.map(file => ({
    ...file,
    content: file === bundleFile
      ? translatedBundle
      : archive.data.subarray(archive.dataStart + file.offset, archive.dataStart + file.offset + file.size)
  }));
  const output = packArchive(archive.header, files);
  const tempPath = `${outputPath}.tmp`;
  const manifestPath = `${outputPath}.manifest.json`;
  const manifestTempPath = `${manifestPath}.tmp`;
  const manifest = {
    schemaVersion: 1,
    sourceSha256: crypto.createHash('sha256').update(archive.data).digest('hex'),
    translatedSha256: crypto.createHash('sha256').update(output).digest('hex'),
    bundlePath: bundleFile.path,
    translationCount: Object.keys(translations).length + inlineTranslations.length + dynamicUi.count
  };
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(tempPath, output);

  try {
    const rebuilt = readArchive(tempPath);
    verifyIntegrity(rebuilt);
    if (rebuilt.files.find(file => file.path === bundleFile.path).size !== translatedBundle.length) {
      fail('A validação pós-geração encontrou tamanho inesperado no bundle.');
    }
    fs.renameSync(tempPath, outputPath);
    fs.writeFileSync(manifestTempPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
    fs.renameSync(manifestTempPath, manifestPath);
  } catch (error) {
    try { fs.unlinkSync(tempPath); } catch {}
    try { fs.unlinkSync(manifestTempPath); } catch {}
    throw error;
  }

  console.log(`Pacote traduzido gerado: ${outputPath}`);
  console.log(`Manifesto de versão gerado: ${manifestPath}`);
  console.log(`Entradas PT-BR aplicadas: ${Object.keys(translations).length + inlineTranslations.length + dynamicUi.count} (${Object.keys(translations).length} no catálogo, ${inlineTranslations.length} textos diretos e ${dynamicUi.count} valores dinâmicos)`);
  console.log(`Tamanho original: ${archive.data.length} bytes; novo tamanho: ${output.length} bytes`);
}

try {
  main();
} catch (error) {
  console.error(`[ERRO] ${error.message}`);
  process.exitCode = 1;
}
