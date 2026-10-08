#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const archivePath = path.resolve(process.argv[2] || path.join(root, 'app.asar'));
const inlinePaths = [
  path.join(root, 'translations', 'inline-pt-BR.json'),
  path.join(root, 'translations', 'inline-pt-BR-extra.json')
];

function readMainBundle(filePath) {
  const data = fs.readFileSync(filePath);
  const pickleSize = data.readUInt32LE(4);
  const jsonLength = data.readUInt32LE(12);
  const dataStart = 8 + pickleSize;
  const header = JSON.parse(data.subarray(16, 16 + jsonLength).toString('utf8'));
  const entry = header.files?.dist?.files?.assets?.files;
  const bundle = Object.entries(entry || {}).find(([name]) => /^index-[^/]+\.js$/.test(name))?.[1];
  if (!bundle) throw new Error('Bundle principal da interface não encontrado no app.asar.');
  return data.subarray(dataStart + Number(bundle.offset), dataStart + Number(bundle.offset) + bundle.size).toString('utf8');
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
    if (char === '"' || char === "'" || char === '`') quote = char;
    else if (char === '{') depth += 1;
    else if (char === '}' && --depth === 0) return i;
  }
  throw new Error('Não foi possível percorrer o catálogo do bundle.');
}

function objectRange(source, marker, from = 0) {
  const markerIndex = source.indexOf(marker, from);
  if (markerIndex < 0) throw new Error(`Catálogo ausente: ${marker}`);
  const start = source.indexOf('{', markerIndex);
  return { start, end: matchingBrace(source, start) };
}

function quotedKeys(source) {
  return new Set([...source.matchAll(/"((?:\\.|[^"\\])+)":`/g)].map((match) => {
    try { return JSON.parse(`"${match[1]}"`); } catch { return match[1]; }
  }));
}

const bundle = readMainBundle(archivePath);
const englishRange = objectRange(bundle, 'Ki={');
const englishCatalog = bundle.slice(englishRange.start, englishRange.end + 1);
const englishKeys = quotedKeys(englishCatalog);
const additions = JSON.parse(fs.readFileSync(path.join(root, 'translations', 'pt-BR.json'), 'utf8'));
const missing = [...englishKeys].filter((key) => !(key in additions)).sort();
const inlineSources = new Set(inlinePaths.flatMap((filePath) => JSON.parse(fs.readFileSync(filePath, 'utf8')).map((item) => item.source)));
const staticUiText = new Set([...bundle.matchAll(/(?:title|description|placeholder|aria-label|label|detail):`([^`$]{3,180})`/g)]
  .map((match) => match[1])
  .filter((text) => /[A-Za-z]{3}/.test(text) && !inlineSources.has(text)));

console.log(`Chaves no catálogo inglês: ${englishKeys.size}`);
console.log(`Chaves traduzidas no catálogo PT-BR do pacote: ${Object.keys(additions).length}`);
console.log(`Chaves adicionais no pacote: ${Object.keys(additions).length}`);
console.log(`Textos literais mapeados: ${inlineSources.size}`);
if (missing.length) {
  console.log(`\nChaves do catálogo ainda sem versão pt-BR (${missing.length}):`);
  for (const key of missing) console.log(`- ${key}`);
  process.exitCode = 1;
} else {
  console.log('\nTodas as chaves do catálogo inglês estão cobertas pelo catálogo pt-BR ou pelas adições do pacote.');
}
if (staticUiText.size) {
  console.log(`\nDescrições, títulos e rótulos estáticos que pedem revisão (${staticUiText.size}):`);
  for (const text of staticUiText) console.log(`- ${text}`);
}
