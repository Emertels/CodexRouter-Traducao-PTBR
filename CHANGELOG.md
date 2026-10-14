# Histórico de alterações

### Teste de instalação — Codex Router 0.6.0 — 14/10/2026
- O usuário confirmou que testou a instalação PT-BR e que o aplicativo está funcionando.


### Verificação da instalação atual — Codex Router 0.6.0 — 13/10/2026
- A versão do aplicativo instalado é 0.6.0; o hash de `resources/app.asar` coincide com o hash traduzido do manifesto do projeto.
- Auditoria do catálogo: 139/139 chaves cobertas; o pacote registra 708 textos diretos e 31 valores dinâmicos. A revisão dos candidatos estáticos não confirmou novas strings de interface sem tradução. Nenhuma alteração de interface foi necessária.


### Patcher dinâmico e console — 13/10/2026
- A revisão do construtor passou para 3. Os pontos dinâmicos já traduzidos são reconhecidos para evitar wrappers duplicados; pontos ausentes ou ambíguos causam interrupção segura.
- Corrigido o patch de literais: traduções parciais agora respeitam limites de identificadores e não alteram nomes de métodos como `controlLocalEnvironment`. A geração do bundle 0.6.0 voltou a concluir com validação sintática aprovada.
- Contagem consolidada da compilação: 139 entradas de catálogo, 708 textos literais, 31 traduções dinâmicas e 1 crédito visual — 879 ajustes; esta correção não acrescenta strings.
- Scripts PowerShell, lançadores CMD e prompt final mantêm UTF-8 e o padrão comum de S / N / Enter / Esc.
- Nenhuma string visível nova foi adicionada nesta correção.

## Em desenvolvimento — Codex Router Control Center 0.6.0 (13/10/2026)

### Correção da busca de instalações — 13/10/2026
- Instalador e restaurador validam primeiro caminhos do processo, registro e locais conhecidos; só quando nenhum candidato válido contém Codex Router.exe e `resources\app.asar` iniciam a busca profunda em unidades fixas e removíveis. A busca ignora pastas raiz do sistema e junctions, deduplica caminhos, mantém instalações distintas selecionáveis e não usa a barra sobreposta do PowerShell. Mantenha `Find-Installations.ps1` ao lado dos scripts.
- A busca mostra a unidade atual, o número de pastas verificadas e as candidatas encontradas; não segue junctions/reparse points para evitar ciclos. Por cobrir todo o volume, pode levar mais tempo em discos grandes ou externos.
- Esta correção altera apenas a localização: 0 novas strings de interface foram adicionadas nesta etapa.

### Busca em camadas sem barra sobreposta — 13/10/2026
- O instalador e o restaurador validam primeiro caminhos obtidos do processo, registro e locais conhecidos. Só se nenhum contiver `Codex Router.exe` e `resources\app.asar` fazem busca profunda em unidades fixas/removíveis.
- A busca profunda ignora pastas de sistema na raiz e junctions, valida o executável junto com `resources\app.asar`, deduplica caminhos e mantém instalações distintas selecionáveis. O progresso aparece no título da janela; a barra `Write-Progress` foi removida.
- Esta melhoria altera a busca, não a interface: 0 novas strings.

- Busca do instalador e do restaurador normalizada para eliminar caminhos duplicados sem ocultar instalações distintas.
- Busca automática ampliada para localizar `Codex Router.exe` em subpastas de todas as unidades montadas, incluindo discos externos; os resultados são filtrados pelo ASAR correspondente.
- Instalador e restaurador procuram `Codex Router.exe` recursivamente em todas as unidades montadas, além de processo, diretórios conhecidos e registro do Windows. Validam o executável e `resources\app.asar`; quando nenhum candidato válido é encontrado, aceitam caminho manual.
- Se houver mais de uma instalação, pedem seleção. A restauração continua validando os backups e hashes guardados junto à instalação escolhida.
- Confirmado pelo usuário que o Codex Router continua na versão 0.6.0, sem atualização recente. Auditoria do catálogo-base dessa versão: 139/139 chaves traduzidas e 697 textos literais anteriores. Foram traduzidos mais 11 rótulos estáticos (Workspaces, Router, Dashboard, Providers, output, Runtime, Installed, English, Español, Plan e Settings). Os nomes Qwen e o termo Harness foram preservados por serem nomes de modelos/termo técnico.
- Revisada a acentuação dos scripts; não foi encontrado texto visível sem acento que precisasse de ajuste nesta rodada (0 textos alterados, 0 novas strings).

## [1.0.0] - 2026-10-07

### Lançamento Oficial da Tradução PT-BR
- Localização cobrindo **868 ajustes PT-BR**: 139 chaves do catálogo, 697 textos diretos, 31 valores dinâmicos da interface e o crédito visual do tradutor.
- Traduzidos os avisos de login de contas, descrições de provedores, opções de nível de raciocínio, contadores de solicitações e informações de tráfego/limites.
- Datas, horas, separadores numéricos e unidades compactas agora acompanham o idioma selecionado na interface, incluindo o formato pt-BR.
- Adicionada a opção Português (Brasil) ao seletor de idioma e detecção automática da localidade do sistema na primeira inicialização.
- O catálogo em inglês permanece intacto; os textos PT-BR são carregados pela opção de idioma própria.

### Consistência do Instalador e Restaurador
- Unificado o prompt final de instalação e restauração: `S` abre o aplicativo e encerra o console; `N`, `Esc` ou `Enter` encerram sem abrir.
- A opção de restauração quando o app já está em inglês exibe a mensagem de que nada precisa ser restaurado e oferece o mesmo prompt.
- Os arquivos `.bat` chamam o PowerShell com encerramento explícito após a escolha; os scripts PowerShell configuram a entrada e saída do console em UTF-8.
- Adicionado BOM UTF-8 aos scripts PowerShell para que o Windows PowerShell 5.1 leia acentos e cedilhas corretamente desde o início.
- Corrigida a exibição de acentos e cedilha no CMD do instalador e do restaurador.
- O aplicativo é iniciado com a pasta de instalação como diretório de trabalho.

### Correções de Execução e Processos
- Fechamento seguro e forçado dos processos do executável da instalação selecionada antes de substituir arquivos; não afeta aplicativos com nomes parecidos em outros diretórios.
- Corrigida a substituição do ASAR e executável no Windows: caminho válido de backup temporário utilizado para evitar erros de formato inválido.
- Ajustado o auxiliar PowerShell de acompanhamento de processos para ocultar a janela de console ao executar comandos em segundo plano.

### Backups, Reversibilidade e Integridade
- Backups imutáveis do ASAR e do executável guardados por hash em `_backup/versions`, sem sobrescrever backups anteriores.
- Registro dos caminhos e hashes dos backups para que o restaurador recupere com precisão a instalação correspondente.
- Suporte à alteração segura e reversível do Electron Fuse para aceitar o pacote traduzido.
- Construtor reproduzível sem dependências npm (`tools/build-translated-asar.cjs`) com recálculo dos hashes SHA-256 e integridade de blocos do ASAR.
- Manifesto gerado com os hashes do original e da tradução para validar a compatibilidade antes da instalação.
- Corrigida a ordem de aplicação das traduções estáticas e dinâmicas para preservar os textos de fallback em inglês e compilar a interface atual.
- Adicionada uma revisão do construtor ao manifesto para o instalador detectar pacotes antigos e atualizá-los mesmo quando a versão original do app não mudou.
- Adicionado o crédito **Tradução PT-BR: Emerson Teles** em azul turquesa no cartão **Aparência**, logo abaixo do seletor de idioma; ele aparece somente quando **Português (Brasil)** está selecionado.
- Removida a regra obsoleta de `_translation_old`; `_Translation Old` não é criada nem usada. Os scripts guardam os originais versionados em `_backup/versions`, no diretório padrão do aplicativo, e restauram a cópia validada correspondente.
