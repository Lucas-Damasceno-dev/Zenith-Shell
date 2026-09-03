# 🌌 Neovim Cheat Sheet

Cheat sheet alinhado ao seu Nixvim atual: base do Vim, atalhos custom, plugins e fluxos avançados.

---

## Perfil do editor
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `mapleader` | `Space` | `maplocalleader` também é `Space`. |
| `number` | Números de linha | `relativenumber` também está ativo. |
| `clipboard` | `unnamedplus` | Copia/cola com o clipboard do sistema. |
| `termguicolors` | `on` | Cores verdadeiras no terminal. |
| `expandtab` | `on` | Usa espaços. |
| `shiftwidth/tabstop` | `2` | Indentação de 2 espaços. |
| `smartindent` | `on` | Indentação automática básica. |
| `cursorline` | `on` | Linha atual destacada. |
| `wrap` | `off` | Sem quebra visual por padrão. |
| `undofile` | `on` | Undo persistente. |
| `mouse` | `a` | Mouse em todas as áreas. |
| `ignorecase/smartcase` | Busca inteligente | Case-insensitive por padrão. |
| `splitbelow/splitright` | `on` | Novos splits abrem abaixo/à direita. |
| `scrolloff/sidescrolloff` | `4 / 8` | Mantém contexto ao redor do cursor. |
| `signcolumn` | `yes` | Evita layout pulando. |
| `timeoutlen` | `300` | Leader e combos ficam responsivos. |
| `updatetime` | `200` | Feedback mais rápido. |

## Vim básico
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `h/j/k/l` | Mover cursor | Básico do Vim. |
| `w/b/e` | Navegar por palavras | Movimento rápido. |
| `0/^/$` | Início/fim de linha | Básico e útil. |
| `gg/G` | Topo/fim do arquivo | Navegação de arquivo. |
| `u` | Undo | Desfazer. |
| `Ctrl+r` | Redo | Refazer. |
| `v/V/Ctrl+v` | Seleção visual | Linha/Bloco/Retangular. |
| `p/P` | Colar | Antes/depois do cursor. |
| `/` | Buscar | Busca para frente. |
| `?` | Buscar para trás | Busca reversa. |
| `n/N` | Próximo/anterior match | Navegação de busca. |
| `.` | Repetir ação | Reexecução rápida. |
| `%` | Ir para par correspondente | Parênteses/chaves. |

## Básico custom
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `Ctrl+s` | Salvar arquivo | Normal, insert e visual. |
| `Esc` | Limpar highlight de busca | Também fecha o destaque. |
| `Ctrl+Up` | Aumentar altura | `resize +2`. |
| `Ctrl+Down` | Diminuir altura | `resize -2`. |
| `Ctrl+Left` | Diminuir largura | `vertical resize -2`. |
| `Ctrl+Right` | Aumentar largura | `vertical resize +2`. |
| `Alt+j` | Mover linha/bloco para baixo | Normal e visual. |
| `Alt+k` | Mover linha/bloco para cima | Normal e visual. |
| `Ctrl+h/j/k/l` | Navegar splits | `smart-splits`; conversa com tmux/kitty. |
| `Ctrl+\` | ToggleTerm | Normal e terminal. |

## Arquivos e navegação
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `Space+ff` | Buscar arquivos | Telescope. |
| `Space+fg` | Busca global | Telescope live grep. |
| `Space+fb` | Buffers | Telescope buffers. |
| `Space+fh` | Help tags | Ajuda do Vim/Nixvim. |
| `Space+fp` | Projetos | Telescope projects. |
| `-` | Abrir diretório pai | Oil. |
| `Space+y` | Abrir Yazi | File manager TUI. |
| `Space+a` | Adicionar ao Harpoon | Marca arquivo atual. |
| `Ctrl+e` | Abrir menu do Harpoon | Lista rápida. |
| `Alt+1` | Harpoon slot 1 | Selecionar item 1. |
| `Alt+2` | Harpoon slot 2 | Selecionar item 2. |
| `Alt+3` | Harpoon slot 3 | Selecionar item 3. |
| `Alt+4` | Harpoon slot 4 | Selecionar item 4. |
| `s` | Flash jump | Busca rápida no buffer. |
| `S` | Flash treesitter | Busca por árvore sintática. |

## Buffers e janelas
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `Shift+h` | Buffer anterior | Bufferline. |
| `Shift+l` | Buffer seguinte | Bufferline. |
| `[b` | Buffer anterior | Alternativa. |
| `]b` | Buffer seguinte | Alternativa. |
| `Space+bp` | Fixar buffer | Toggle pin. |
| `Space+bP` | Fechar buffers não fixados | Group close. |
| `Space+bo` | Fechar outros buffers | Keep current only. |
| `Space+bd` | Fechar buffer atual | `bdelete`. |
| `Space+gg` | Neogit | Git UI. |

## Sessões e UI
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `Space+qs` | Restaurar sessão | Persistence load. |
| `Space+ql` | Restaurar última sessão | Persistence load last. |
| `Space+qd` | Não salvar sessão | Persistence stop. |
| `Space+z` | Zen Mode | Oculta ruído. |
| `Space+Z` | Twilight | Diminui destaque fora do foco. |
| `Space+un` | Dismiss notifications | Noice/notify. |
| `Space+ut` | Toggle Undotree | Histórico de undo. |
| `Space+m` | Toggle split/join | Treesj. |

## Busca, diagnóstico e estrutura
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `Space+xx` | Diagnostics | Trouble diagnostics. |
| `Space+xX` | Diagnostics do buffer | Trouble buffer diagnostics. |
| `Space+cs` | Symbols | Trouble symbols. |
| `Space+cl` | LSP refs/defs/etc | Trouble LSP. |
| `Space+S` | Spectre | Search/replace global. |
| `Space+co` | Outline de código | Aerial. |
| `Space+xt` | TODOs | Trouble + todo-comments. |
| `Space+cn` | Neogen | Gera anotações. |

## Debug, testes e tarefas
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `Space+db` | Toggle breakpoint | DAP. |
| `Space+dc` | Continue | DAP. |
| `Space+di` | Step into | DAP. |
| `Space+do` | Step out | DAP. |
| `Space+dO` | Step over | DAP. |
| `Space+dt` | Terminate | DAP. |
| `Space+dr` | Toggle REPL | DAP. |
| `Space+tr` | Run nearest test | Neotest. |
| `Space+tf` | Run file tests | Neotest. |
| `Space+ts` | Toggle test summary | Neotest. |
| `Space+or` | Run task | Overseer. |
| `Space+ot` | Toggle task list | Overseer. |

## Refatoração
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `Space+re` | Extract | Refactoring.nvim, visual mode. |
| `Space+rf` | Extract to file | Refactoring.nvim, visual mode. |
| `Space+rv` | Extract var | Refactoring.nvim, visual mode. |
| `Space+ri` | Inline var | Refactoring.nvim, normal/visual. |
| `Space+rb` | Extract block | Refactoring.nvim. |
| `Space+rfb` | Extract block to file | Refactoring.nvim. |

## Java (buffer-local)
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `Space+co` | Organize imports | Só em arquivos Java. |
| `Space+ct` | Test class | Só em arquivos Java. |
| `Space+cn` | Test nearest method | Só em arquivos Java. |
| `Space+cx` | Extract variable | Seleção visual. |
| `Space+cm` | Extract method | Seleção visual. |

## LSP disponível
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `nixd` | Nix/NixOS/Home Manager | Configurado com `nixos` e `home-manager`. |
| `pyright` | Python | LSP ativo. |
| `vtsls` | TypeScript/JS | LSP ativo. |
| `gopls` | Go | LSP ativo. |
| `sqls` | SQL | LSP ativo. |
| `dockerls` | Dockerfile | LSP ativo. |
| `rust_analyzer` | Rust | LSP ativo. |
