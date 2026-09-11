# 项目约定

## 代码结构（自举 Stage 1，ADR D15）

```
self.typ              唯一真相：声明 Cargo.toml + src/*.rs + tests/*.rs + .agents/skills/**
bootstrap/            冻结的种子 crate（tracked，永不重新生成）
Cargo.toml src/ tests/ .agents/   生成物（gitignore）——只改 self.typ，不要手改这里
.lpignore             仓库根的保护清单（--out 就是仓库根）
lit/lp.typ            Typst 包：声明（#chunk/#file）+ 渲染
src/main.rs           CLI（clap）+ 命令派发
src/tangle.rs         展开、缩进、严格报错、写文件、--check
src/status.rs         输出目录所有权（.lpignore 交给 ignore crate）
src/map.rs            每目录一份 .lpmap.json（chunk 区间，schema v5）
src/watch.rs          notify + 去抖 + 只写变化的字节
src/metadata.rs       typst eval 'query(<lp-decl>)' → 声明流
src/explain.rs        诊断行 → chunk（纯查表 + 通用正则）
src/diag.rs           LpError（miette）
examples/demo/        可跑的多文件示例；run.sh 是端到端回归入口
tests/*.rs            跑真二进制的端到端测试（tests/self.rs 守自复现）
.agents/skills/       agent skill（也用 self.typ 写）：LP 纪律 + lp 机制 + 一个跑得通的例子
```

常用命令：`nix develop -c cargo test`、`nix develop -c examples/demo/run.sh`（端到端）、`nix develop -c cargo clippy`。**fresh clone 先按 README 的"自举"三步**（`src/` 不在 git 里）：`cargo build --manifest-path bootstrap/Cargo.toml` → `./bootstrap/target/debug/lp tangle self.typ --out .` → `cargo test`。

实时回路（手测）：`nix develop -c cargo run -- watch examples/demo/literate.typ --out examples/demo/build --check-cmd "cargo build --manifest-path examples/demo/build/Cargo.toml --message-format=short"`，然后在另一个终端改 `.typ`。

## 硬规则

- **优雅是准入条件**（用户定的规矩）：**活不能优雅地做 —— 不做**。任何功能的实现路径若必须依赖启发式搜索、字符串匹配源码、或与 Typst 版本耦合的重复解析，就**不做这个功能**，而不是先脏着做出来。已按此删掉：行号映射（lpmap）、label 当 chunk 名、`is_root` 文件名启发式、`#show raw` 埋点、`typst-syntax` 静态分析（见 ADR D11→D14）。**行号映射不是待办**：Typst 脚本层拿不到源位置，要行号就得重新解析 Typst，那先破这条规矩。

- **正交性**：算法里不得出现目标语言知识。语言差异只能是**数据表**（扩展名 → typst lang tag、将来可选的行指令模板）。
- **生成物不入库**：`examples/demo/build/` 之类一律 gitignore；CI 用 `lp tangle --check` 守漂移。`.typ` 是唯一真相。**工具自身的 crate 也是生成物**（ADR D15）：只改 `self.typ`，手改 `src/` 会被 `tests/self.rs` 抓住；`bootstrap/` 是冻结种子，不要跟着文档更新。
- **报错必须指回声明**：新错误一律用 `LpError`（miette），不要拼裸字符串。出处是 **chunk 级**（哪个声明、在它里面第几行），**没有 `.typ` 行号**（D14）。
- **chunk 由声明给出**（ADR D13）：文档 import `lit/lp.typ` 并用 `#chunk(name, ```…```)` / `#file(path, ```…```)` 声明；工具用 `typst eval` 读 `query(<lp-decl>)`，**从不解析 Typst**。出处是 **chunk 级**（哪个声明、在它里面第几行），**不记 `.typ` 行号**（ADR D14）。
- **不要**回头走这两条路：用 Rust 静态分析 Typst（构造上就错，见 D13）、用 `#show raw` 埋点（样式化规则会消费元素，见 D12）。
- **`typst` 是 tangle 的硬依赖**（`LP_TYPST` 或 PATH），`cargo test` 也需要它 —— 用 `nix develop -c cargo test`。
- **包在 `lit/lp.typ`**：改名/改参数要同步 `src/metadata.rs` 的 `QUERY`、`lit/lp.typ` 里的元数据字段（`lp: "chunk"|"file"`, `name`, `lang`, `text`）、以及文档里那段“怎么写 chunk”的说明。
- **工具只管机制，论证归写作者**（ADR D18，它推翻了 D16）：声明**顺序自由**（骨架在前、或“先讲想法与片段、最后组装”，都正当）；fence 的 `lang` 只是数据（高亮/映射），不做一致性检查。工具强制的只有：引用可解析、无环、非空、`--check` 与文本一致、输出目录被解释（D10）。“重思路、渐进式披露、逻辑自洽”无法机械判定，靠 skill 的纪律；别把不可判定的性质换成可判定的代理当同一条规则（D16 就是这么推错的）。
- **转义**（ADR D17）：要原样输出 `<<name>>` 独占一行的样子，写成 `@<<name>>`（tangle 去掉 `@`，weave 渲染成字面量，不计入引用图）。文档在引用这套语法本身时用它——`self.typ` 里的 skill 就是。
- **一个 chunk 的行可以来自多处**：同名声明按文档顺序拼接（可以跨多个文档）；出处只到 chunk 级。
- **未处置即错误，删除必须显式**（ADR D10）：`--out` 整个目录里的每个文件都要被 chunk 产出或被 `.lpignore` 声明，否则 `lp tangle` 失败并列出（两条出路：声明 / `lp unaccounted --delete`）。`lp` 从不自行删除。豁免只有 `.lpignore` 与 `.lpmap.json` 两个控制文件，无 git 特例。改这块前先看 `tests/owned.rs`。
- **写盘只写变化的字节**（ADR D9）：不要无脑重写生成物或 `.lpmap.json`；有语法错误时不得 tangle。改这两条行为前先看 `tests/lazy.rs`。

- **语言**：与用户交流用中文；代码、标识符、注释用英文。注释只解释"为什么"（全局规则见 `~/.pi/agent/AGENTS.md`）。
- **调研优先**：任何"某方案可行/不可行"的结论要么附可复现命令，要么标 **未验证**。
- **agent-notes**：`agent-notes/README.md` 是索引，`research/YYYY-MM-DD-<topic>.md` 一个主题一份，结论放最前面。做了决定就新建 `agent-notes/decisions/`，追加不改写。事实过期就地改并注明修正。
- **实验代码不是产品**：`experiments/` 下是一次性验证，可以糙；产品代码不要从那里"长出来"，要新写。
- **工具链（NixOS）**：用 flake 的 devShell：`nix develop -c <cmd>`（提供 typst 0.15.1 / cargo 1.97 / rustfmt / clippy / python3）。临时单跑某个工具用 `nix shell nixpkgs#typst -c ...`。不要用非 Nix 的包管理器。
- **flake 的坑**：nix 只看 git 已跟踪的文件，新建/改完 `flake.nix` 要先 `git add`，否则 `nix develop` 报 `not tracked by Git`。
- **Typst 事实**：写代码前先读 `agent-notes/research/2026-09-11-typst-engine-facts.md`，那里记着 label/show rule/link 的几个反直觉行为和 fence info string 的坑。
- **依赖策略（ADR D7）**：能用成熟 crate 解决的一律不手写（`clap`、`notify`、`miette`、`cargo_metadata`…）；新增依赖必须在 `agent-notes/plan.md` 的依赖表里补一行"为什么是它"。
- **解析引擎（ADR D6）**：tangle 用官方 `typst-syntax` crate 直读源文件（有精确 span，不需要 typst 二进制）；`typst eval` 只当测试 oracle。
- **worktree**：功能开发走 `~/Projects/worktrees/literate/<topic>`；调研笔记与文档可以直接在 main 上改。
