# Histórico de alterações

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
- Os arquivos `.bat` selecionam a página de código UTF-8 antes de abrir o PowerShell e fecham corretamente após a escolha.
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
- Adicionado o crédito **Tradução PT-BR: Emerson Teles** em azul turquesa no cartão **Aparência**, logo abaixo do seletor de idioma.
- Removida a regra obsoleta de `_translation_old`; `_Translation Old` não é criada nem usada. Os scripts guardam os originais versionados em `_backup/versions`, no diretório padrão do aplicativo, e restauram a cópia validada correspondente.
