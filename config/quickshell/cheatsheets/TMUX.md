# 🪟 Tmux Cheat Sheet

Resumo do tmux atual, com o básico, os popups e os modos avançados que você já configurou.

---

## Base
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `Prefix` | `Ctrl+b` | Prefixo padrão do tmux. |
| `1` | Índice inicial | Janelas e painéis começam em 1. |
| `vi` | Copy-mode | Navegação mais natural. |
| `mouse` | `on` | Clique, seleção e resize com mouse. |
| `wl-copy` | Clipboard | `y` e `Enter` no copy-mode copiam para Wayland. |
| `default` | Sessão padrão | O serviço de usuário sobe a sessão `default`. |

## Básico do tmux
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `c` | Nova janela | `Prefix + c` |
| `,` | Renomear janela | `Prefix + ,` |
| `&` | Fechar janela | `Prefix + &` |
| `n` | Próxima janela | `Prefix + n` |
| `p` | Janela anterior | `Prefix + p` |
| `l` | Última janela | `Prefix + l` |
| `w` | Lista de janelas/sessões | `Prefix + w` |
| `:` | Command prompt | `Prefix + :` |
| `?` | Lista de atalhos | `Prefix + ?` |
| `;` | Voltar ao último painel | `Prefix + ;` |
| `x` | Fechar painel | `Prefix + x` |
| `z` | Zoom do painel | `Prefix + z` |

## Painéis
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `%` | Dividir verticalmente | `Prefix + %` |
| `"` | Dividir horizontalmente | `Prefix + "` |
| `↑/↓/←/→` | Mover entre painéis | `Prefix + seta` |
| `o` | Próximo painel | `Prefix + o` no tmux puro; aqui fica sobrescrito pelo `sessionx` |
| `q` | Mostrar números dos painéis | `Prefix + q` |
| `!` | Destacar painel como janela | `Prefix + !` |

## Copy mode
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `[` | Entrar em copy-mode | `Prefix + [` |
| `v` | Iniciar seleção | `copy-mode-vi` |
| `Ctrl+v` | Seleção retangular | `copy-mode-vi` |
| `y` | Copiar para clipboard | `copy-mode-vi` |
| `Enter` | Copiar para clipboard | `copy-mode-vi` |
| `MouseDragEnd1Pane` | Copiar ao soltar o mouse | `copy-mode-vi` |
| `H` | Início da linha | `copy-mode-vi` |
| `L` | Fim da linha | `copy-mode-vi` |
| `]` | Colar buffer | `Prefix + ]` |

## Popups e sessionizer
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `f` | Sessionizer de projetos | `Prefix + f` |
| `o` | Sessionx | `Prefix + o` |
| `p` | Floax | `Prefix + p` |
| `g` | LazyGit | `Prefix + g` |
| `m` | Btop | `Prefix + m` |
| `t` | Shell temporário | `Prefix + t` abre `zsh` |
| `F` | Tmux-thumbs | `Prefix + F` |

## Layouts
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `L` | Abrir menu de layouts | `Prefix + L` |
| `h` | `even-horizontal` | Dentro do menu |
| `v` | `even-vertical` | Dentro do menu |
| `m` | `main-horizontal` | Dentro do menu |
| `n` | `main-vertical` | Dentro do menu |
| `t` | `tiled` | Dentro do menu |
| `Escape` | Sair do menu | Dentro do menu |

## Resize mode
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `r` | Entrar no resize mode | `Prefix + r` |
| `h/j/k/l` | Redimensionar 1 passo | Dentro do modo |
| `H/J/K/L` | Redimensionar 5 passos | Dentro do modo |
| `Escape` | Voltar ao root | Dentro do modo |

## Smart-splits
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `Ctrl+h` | Mover para a esquerda | Se o painel atual for `vim/nvim`, envia a tecla para o editor |
| `Ctrl+j` | Mover para baixo | Mesma lógica |
| `Ctrl+k` | Mover para cima | Mesma lógica |
| `Ctrl+l` | Mover para a direita | Mesma lógica |

## Avançado
| Comando | Ação | Nota |
| :--- | :--- | :--- |
| `P` | Ativar/desativar log do painel | Gera `~/tmux-#W.log` |
| `F12` | Inception mode | Desliga prefixo e key-table locais em sessões remotas |
| `resurrect` | Persistência de sessões | Plugin ativo |
| `continuum` | Auto save/restore | Plugin ativo |
| `sensible` | Defaults seguros | Plugin ativo |
