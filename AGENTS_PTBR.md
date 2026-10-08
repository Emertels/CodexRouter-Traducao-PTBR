# Diretrizes de manutenção — Codex Router PT-BR

## Escopo

Este repositório mantém traduções e scripts para gerar e aplicar um pacote PT-BR do Codex Router Control Center no Windows. O código e o pacote original pertencem aos respectivos titulares; não afirme afiliação oficial.

## Fonte e geração

- Mantenha as traduções de catálogo em `translations/pt-BR.json` e as traduções literais fora do catálogo em `translations/inline-pt-BR.json`; as chaves do catálogo são identificadores estáveis do bundle.
- Gere `app-pt.asar` com `node tools/build-translated-asar.cjs app.asar app-pt.asar` ou `npm run build`.
- O ASAR de entrada deve vir da versão instalada que será traduzida. Não altere o pacote original.
- O construtor verifica hashes SHA-256, limites e offsets, atualiza os metadados do arquivo alterado e valida a saída.
- Não edite manualmente os binários `app.asar` ou `app-pt.asar`; atualize o catálogo e gere o artefato novamente.

## Segurança e instalação

- Nunca sobrescreva `_backup/app.asar` quando já existir. Valide-o antes de confiar nele.
- Por instrução do usuário, feche à força apenas os processos cujo caminho executável corresponda exatamente à instalação selecionada, antes de substituir ou restaurar arquivos.
- Faça cópias temporárias no mesmo volume e valide hash e estrutura antes da substituição.
- Preserve o backup do executável antes de modificar qualquer Electron Fuse. A restauração deve recuperar o executável original quando houver backup.
- Não instale a tradução durante o desenvolvimento. Use uma instalação de teste e confirme visualmente a interface antes de publicar uma versão.

## Terminologia

- Prefira **aplicativo**, **tokens**, **ativar/desativar** e **Painel de Controle**.
- Preserve marcas, nomes de modelos, provedores, comandos, variáveis, caminhos, identificadores e unidades técnicas.
- Use português brasileiro natural e mantenha placeholders como `{name}`, `{hours}` e `{tokens}` exatamente como aparecem na origem.

## Publicação

- Atualize `CHANGELOG.md`, `README.md` e `README_EN.md` a cada versão.
- Não inclua os ASAR locais, backups, executáveis ou dados de usuário no Git.
- Não declare a interface integralmente traduzida sem auditar o bundle e revisar a interface em execução.
