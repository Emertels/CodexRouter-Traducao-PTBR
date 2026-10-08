# Histórico de alterações

## [1.0.0] - 2026-10-07

### Lançamento Oficial da Tradução PT-BR
- Localização profunda cobrindo 848 entradas PT-BR (139 chaves do catálogo, 692 textos diretos de telas e 17 dinâmicos de status, uso, provedores e modelos).
- Instalador automático (`Instalar-Traducao.bat`) e restaurador seguro (`Restaurar-Original.bat`) com prompt unificado de inicialização: `S` abre o app e encerra o console; `N`, `Esc` ou `Enter` encerram sem abrir.
- Formatos de datas, horas, números e unidades adaptados para o padrão brasileiro (`pt-BR`).
- Validação estrita de integridade SHA-256 no ASAR e backups imutáveis versionados em `_backup/versions`.
- Compatibilidade nativa com Electron Fuse de forma totalmente reversível.

## [1.2.3] - 2026-10-07

### Tradução de textos dinâmicos
- Atualizado o pacote para 848 entradas PT-BR: 139 chaves do catálogo, 692 textos diretos e 17 valores dinâmicos da interface.
- Traduzidos os avisos de login de contas, descrições de provedores, opções de nível de raciocínio, contadores de solicitações e informações de tráfego/limites exibidas nos prints recentes.
- Ajustado o auxiliar PowerShell de acompanhamento de processos para não abrir sua própria janela quando o Codex Router executa comandos com entrada e saída herdadas.

## [1.2.2] - 2026-10-07

### Tradução e execução
- Ampliado o pacote da versão atual de 813 para 825 entradas PT-BR, incluindo textos da tela de continuidade e do período de uso selecionado.
- Corrigido o lançamento de comandos de atualização e ativação de provedores no Windows para ocultar a janela de console do PowerShell.
- Confirmada a compilação do pacote e a integridade do ASAR de saída.
- Textos fornecidos por dados externos, como nomes de plano e algumas descrições de instalação, não existem como literais no ASAR e precisam de localização no ponto de origem desses dados.

## [1.2.1] - 2026-10-07

### Correção do fluxo de restauração
- O restaurador agora oferece as opções explícitas `S` para abrir o Codex Router e fechar o CMD, ou `N`, `Esc` e `Enter` para fechar sem abrir.
- Removida a pausa incondicional do arquivo `.bat` de restauração; em caso de sucesso, os consoles encerram após a escolha. A pausa fica restrita a erros para que a mensagem possa ser lida.
- O aplicativo é iniciado com a pasta de instalação como diretório de trabalho.
- Revisadas as mensagens dos scripts para corrigir acentos e cedilha; os arquivos `.bat` configuram UTF-8 para exibir os caracteres corretamente no console.

## [1.2.0] - 2026-10-07

### Correção do instalador
- Corrigida a substituição do ASAR no Windows: a chamada a `File.Replace` agora recebe um caminho válido de backup temporário em vez de `null`, que causava “O caminho tem um formato inválido”.
- Aplicada a mesma correção ao restaurador, incluindo a substituição do executável; os arquivos temporários de segurança são removidos após a validação.
- A pergunta para iniciar o app agora informa na mesma linha: `S` abre o app e fecha o CMD; `N`, `Esc` ou `Enter` fecham sem abrir. O CMD só aguarda uma tecla quando ocorre erro.
- Quando o instalador reconhece que a tradução já está instalada, ele não reaplica os arquivos e ainda oferece a mesma opção para abrir o app.

### Tradução da versão instalada
- Atualizado o pacote para o `app.asar` mais recente encontrado na instalação local, cujo bundle mudou de `index-DFLzbZaO.js` para `index-Bi7lS7oj.js`.
- Migradas 125 traduções PT-BR existentes para o novo catálogo e acrescentadas 14 entradas, totalizando 139 chaves de catálogo.
- Ampliada a varredura da interface para 613 textos diretos, cobrindo telas, estados, configurações, provedores, modelos, uso, erros e descrições. Total aplicado nesta compilação: 752 entradas PT-BR.
- Acrescentadas mais 61 traduções diretas com base nos prints de Modelos, Uso, Status, contas do ChatGPT e detalhes de ambientes locais; total atualizado: 674 textos diretos e 813 entradas PT-BR.
- Datas, horas, separadores numéricos e unidades compactas agora acompanham o idioma selecionado na interface, incluindo o formato pt-BR.
- Adicionada a opção Português (Brasil) ao seletor de idioma e a detecção de `pt-BR`/`pt-*` pelo idioma do sistema na primeira inicialização.
- O catálogo em inglês permanece intacto; os textos PT-BR são carregados pela opção de idioma própria.

### Instalação e restauração
- O instalador recompila automaticamente o pacote a partir do `app.asar` instalado quando detecta uma versão nova compatível com as traduções.
- Se a estrutura ou os textos esperados tiverem mudado, a geração é interrompida antes de substituir os arquivos instalados.
- O instalador fecha à força o processo principal e os processos auxiliares do executável encontrado antes de substituir arquivos; não fecha aplicativos com nomes parecidos em outros diretórios.
- ASARs e executáveis originais são guardados por hash em `_backup/versions`, sem sobrescrever backups de outras versões.
- O estado da instalação registra os hashes e os caminhos dos backups usados. Reexecutar o instalador na mesma versão não copia o pacote novamente.
- O restaurador fecha os processos da instalação alvo, seleciona o backup correspondente e não altera arquivos quando já não encontra as traduções PT-BR reconhecidas.

### Validação
- Gerado o pacote para o hash SHA-256 exato do ASAR atual (`69c456…fd57cd82`) e conferidas as 752 entradas PT-BR, o manifesto e a integridade do arquivo.
- A compatibilidade estrutural foi confirmada para esse pacote de origem; versões futuras precisam passar novamente pelo construtor e pela varredura.
- Ao detectar uma tradução instalada, o instalador compara o hash com o pacote PT-BR atual antes de ignorar a instalação; pacotes atualizados podem ser reaplicados usando os backups originais registrados.
- Mantida a validação estrutural do ASAR e dos metadados de integridade do bundle reconstruído.

## [1.1.0] - 2026-10-07

### Tradução PT-BR
- Traduzidos 77 textos identificados na varredura: 15 entradas do catálogo de idioma e 62 strings diretas de navegação, status, provedores, modelos, uso, aparência e manutenção.
- Mantidas as traduções e os nomes próprios já existentes no catálogo PT-BR.

### Construtor do pacote
- Adicionado um construtor reproduzível sem dependências npm para aplicar o catálogo PT-BR ao `app.asar` da versão instalada.
- Atualizados os metadados de integridade SHA-256 dos arquivos alterados e reconstruído o cabeçalho ASAR.
- O construtor valida offsets, hashes de entrada e saída e interrompe a geração quando o pacote é inválido ou não encontra o bundle esperado.
- Gerado um manifesto com os hashes do ASAR original e do traduzido para impedir a instalação em uma versão que não corresponde à base usada na geração.

### Instalação e restauração
- O instalador valida o pacote traduzido, confere o backup, não encerra o aplicativo à força e usa arquivo temporário antes da substituição.
- O instalador reconhece quando a mesma versão já está instalada e verifica se o backup corresponde à versão de origem.
- O restaurador valida o backup e reconhece quando o ASAR e o executável já estão restaurados, sem copiá-los novamente.
- Os scripts restauram ASAR e executável a partir de cópias temporárias quando a restauração é necessária.
- Corrigido o fluxo de cópia para preservar o backup original existente e evitar que uma falha durante a gravação deixe um pacote parcial instalado.

### Auditoria
- Confirmado que os arquivos `app.asar` e `app-pt.asar` fornecidos inicialmente eram idênticos. O pacote PT-BR agora é gerado a partir do original e contém as alterações documentadas.
- Criados README em português e inglês, licença, metadados npm sem dependências externas e regras Git para excluir arquivos binários locais.
