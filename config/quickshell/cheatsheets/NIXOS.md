# 📦 NixOS & Home Manager Cheatsheet

Guia das rotinas reais de manutenção do sistema.

---

## 🚀 Rotina de atualização
| Comando | Ação | Observação |
| :--- | :--- | :--- |
| `testos` | Verificação total | `nix flake check -L`. |
| `sysup` | Atualizar sistema | Roda `testos` antes do `nh os switch`. |
| `homeup` | Atualizar home | Roda `testos` antes do `nh home switch`. |
| `fullupgrade` | Sync total | Atualiza flakes e aplica system + home. |
| `garbage` | Limpeza | `nh clean all`. |
| `testvm` | VM do sistema | Sandbox para validar boot/driver. |

---

## 🧪 Validação e diagnóstico
| Comando | Ação | Observação |
| :--- | :--- | :--- |
| `nix flake check -L` | Suite completa | Testes Python, BATS e QML. |
| `nh os switch` | Switch do sistema | Aplica nova geração NixOS. |
| `nh home switch` | Switch do home | Aplica Home Manager. |
| `nix-shell -p pkg` | Shell temporário | Testar pacotes sem instalar globalmente. |
| `nix search nixpkgs pkg` | Busca de pacotes | Localizar nomes de pacotes oficiais. |

---

## 🧭 Estrutura importante
| Caminho | Papel |
| :--- | :--- |
| `/etc/nixos/flake.nix` | Entrada do sistema. |
| `/etc/nixos/configuration.nix` | Config principal. |
| `/etc/nixos/home/lucas/flake.nix` | Entrada do Home Manager. |
| `/etc/nixos/home/lucas/modules/` | Módulos do usuário. |

---

## ⚠️ Regras práticas
| Regra | Por quê |
| :--- | :--- |
| Rodar `testos` antes de switch | Evita aplicar config quebrada. |
| Usar `nh` para switch | Menos atrito e rollback melhor. |
| Revisar logs se falhar | Ajuda a separar erro de build de runtime. |
