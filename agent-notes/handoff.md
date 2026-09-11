# 接手说明（handoff）— 2026-09-11

> 这是**快照**，会过期。行动前先 `git log --oneline -5`，然后读 `lp.typ`（唯一权威）与 `agent-notes/README.md`（索引 + 当前状态）。

## 30 秒

- **是什么**：`lp` —— 基于 Typst 的 literate programming 工具。同一个 `.typ` 既是可排版的文档（weave = `typst compile`），也是多种目标语言源码的唯一真相（tangle = `lp tangle`）。目标语言正交：算法里没有任何目标语言知识。
- **仓库形态（D19）**：tracked 只有 `README.md`（一行指针）、`AGENTS.md`（一行指针）、`lp.typ`（工具本身，自解释）、`seed/`（本代产物的冻结副本）、`agent-notes/`，外加 `flake.nix`/`flake.lock`（nix 只认 git 里的 flake，见下）。其余一切——crate、包、skill、示例、`.gitignore`/`.lpignore`——都是 `lp tangle lp.typ --out .` 的产物。
- **先跑什么**：`lp.typ` 的 "Starting from nothing" 三行：`nix develop -c cargo build --manifest-path seed/Cargo.toml` → 用种子 `tangle lp.typ --out .` → `nix develop -c cargo test`。

## 现在是什么（契约）

| 问题 | 谁回答 | 机制 |
| --- | --- | --- |
| 有哪些 chunk、顺序、文本、语言 | **Typst 求值** | 文档 `#chunk`/`#file` 声明；工具 `typst eval 'query(<lp-decl>)'` 读回，**从不解析 Typst**（D13） |
| 引用展开、缩进、悬空/环/空报错 | `lp`（`tangle.rs`） | 纯文本替换 + 缩进；`@<<name>>` 是转义，原样输出 `<<name>>` 且不计为引用（D17） |
| 每行输出来自哪个声明 | `lp`（`map.rs`，schema v5） | chunk 区间；**没有 `.typ` 行号**（D14） |
| 输出目录里的东西归谁 | `lp`（`status.rs`） | produced / declared（`.lpignore`，匹配=保护）/ unaccounted（错误）；检查在写盘**之后**跑（D20） |
| weave | `typst compile` | 包由文档自己产出（附录 "The package"） |

## 铁律

`lp.typ` 的 "The rules" 一节是权威——**别在这里抄一份**，抄了就会漂。一句话：工具能强制的只有机制（引用可解析、无环、非空、`--check`、所有权）；**顺序自由、`lang` 只当数据**（D18）；"重思路、渐进式披露、语义自洽"靠**写作者**，skill 是那半边的成文（`.agents/skills/literate-programming/`，同样是产物）。

## 踩过的坑（别回头走）

- 用 Rust 静态分析 Typst、用 `#show raw` 埋点、在源码里搜索声明 token 定位行号——三条都实测过、都不做（D12/D13/D14）。
- 手改生成物（`src/`、`tests/`、技能、包……）：`tests/self.rs` 会红。
- 把不可判定的性质换成可判定的代理然后当同一条规则（D16 就是这么推错的，见 D18）。
- `.lpignore` 是**逐目录**的，不能替另一个文档的产物背书；演示目录的边界在根 `.lpignore` 里声明（`/examples/demo/build`）。
- 新增顶层目录要写进 `.lpignore`，否则 `tangle` 报"未处置"。
- `flake.nix` 同时是 tracked 与生成物：nix 拒绝评估不在 git 里的 flake，所以这是唯一必须两边都在的文件；改它要改 `lp.typ`。

## 下一步候选

- **文档的 literate 化（Stage 2）**：`lp.typ` 现在是"按序声明各个文件 + 散文附录"；下一步是把重复片段抽成 `#chunk` 共享、让散文与代码真正交织，让文档从"能自举"变成"值得读"。
- `lp explain --format cargo`（`cargo_metadata` 解 `--message-format=json`）。
- 把 `lit/lp.typ` 发布到 `@preview`（包现在由文档产出，剩下的是流程问题）。

## 环境陷阱

- **`typst` 必须在 PATH**（或 `LP_TYPST`）：tangle 靠它读声明，`cargo test` 也需要 → 一律 `nix develop -c …`；临时单跑用 `nix shell nixpkgs#typst -c …`。
- **flake 只看 git 已跟踪的文件**：所以 `flake.nix`/`flake.lock` 必须在 index 里（D19 例外清单）。
- **`--out` 就是仓库根**：`lp tangle lp.typ --out . --check` 是干跑、随时可跑；`lp unaccounted … --delete` 等于对全仓库动刀，看清单再动手。
- 本会话里 pi-lens 偶尔报 `~/.config/pi-web/...` 的路径（例如 `src/main.rs`、`out/a.py`）：harness 把仓库相对路径按自己的 cwd 解析的假象，那些文件不存在；以仓库内路径为准。
