# 项目约定

## 代码结构（M1 原型）

```
src/main.rs       CLI（clap）+ 命令派发 + lp list
src/parse.rs      typst-syntax CST 遍历 → chunk（两种 label 写法）
src/tangle.rs     展开、缩进、严格报错、写文件、--check
src/map.rs        .lpmap.json 的 schema + 查找
src/explain.rs    诊断行 → .typ 行（纯查表 + 通用正则）
src/diag.rs       LpError（miette，指向 .typ 源 span）
lit/lit.typ       Typst 渲染库（`#show: lit`）
examples/demo/    可跑的多文件示例；run.sh 是端到端回归入口
tests/flow.rs     跑真二进制的端到端测试
```

常用命令：`nix develop -c cargo test`、`nix develop -c examples/demo/run.sh`（端到端）、`nix develop -c cargo clippy`。

实时回路（手测）：`nix develop -c cargo run -- watch examples/demo/literate.typ --out examples/demo/build --check-cmd "cargo build --manifest-path examples/demo/build/Cargo.toml --message-format=short"`，然后在另一个终端改 `.typ`。

## 硬规则

- **正交性**：算法里不得出现目标语言知识。语言差异只能是**数据表**（扩展名 → typst lang tag、将来可选的行指令模板）。
- **生成物不入库**：`examples/demo/build/` 之类一律 gitignore；CI 用 `lp tangle --check` 守漂移。`.typ` 是唯一真相。
- **报错必须指回 `.typ`**：新错误一律用 `LpError::at`（带 span），不要拼裸字符串。
- **解析只用 `typst-syntax`**（ADR D6）；`typst eval` 只当测试 oracle。
- **删除只在所有权范围内**（ADR D10）：只有 `.lpignore` 声明的目录会被扫描删除（规则即 gitignore，匹配=保护），没有 `.lpignore` 就什么都不删，只有 `.lpignore` 与 `.lpmap.json` 两个控制文件豁免，无 git 特例，`--check` 是干跑；开新的删除路径前先看 `tests/owned.rs`。
- **写盘只写变化的字节**（ADR D9）：不要无脑重写生成物或 `.lpmap.json`；有语法错误时不得 tangle。改这两条行为前先看 `tests/lazy.rs`。

- **语言**：与用户交流用中文；代码、标识符、注释用英文。注释只解释"为什么"（全局规则见 `~/.pi/agent/AGENTS.md`）。
- **调研优先**：本项目当前处于调研/设计阶段。任何"某方案可行/不可行"的结论要么附可复现命令，要么标 **未验证**。
- **agent-notes**：`agent-notes/README.md` 是索引，`research/YYYY-MM-DD-<topic>.md` 一个主题一份，结论放最前面。做了决定就新建 `agent-notes/decisions/`，追加不改写。事实过期就地改并注明修正。
- **实验代码不是产品**：`experiments/` 下是一次性验证，可以糙；产品代码不要从那里"长出来"，要新写。
- **工具链（NixOS）**：用 flake 的 devShell：`nix develop -c <cmd>`（提供 typst 0.15.1 / cargo 1.97 / rustfmt / clippy / python3）。临时单跑某个工具用 `nix shell nixpkgs#typst -c ...`。不要用非 Nix 的包管理器。
- **flake 的坑**：nix 只看 git 已跟踪的文件，新建/改完 `flake.nix` 要先 `git add`，否则 `nix develop` 报 `not tracked by Git`。
- **Typst 事实**：写代码前先读 `agent-notes/research/2026-09-11-typst-engine-facts.md`，那里记着 label/show rule/link 的几个反直觉行为和 fence info string 的坑。
- **依赖策略（ADR D7）**：能用成熟 crate 解决的一律不手写（`clap`、`notify`、`miette`、`cargo_metadata`…）；新增依赖必须在 `agent-notes/plan.md` 的依赖表里补一行"为什么是它"。
- **解析引擎（ADR D6）**：tangle 用官方 `typst-syntax` crate 直读源文件（有精确 span，不需要 typst 二进制）；`typst eval` 只当测试 oracle。
- **worktree**：功能开发走 `~/Projects/worktrees/literate/<topic>`；调研笔记与文档可以直接在 main 上改。
