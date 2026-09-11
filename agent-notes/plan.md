# 实施计划（M0–M3）

- 日期：2026-09-11（v2：按 ADR D6/D7 修正引擎与依赖）
- 前置：`decisions/2026-09-11-mvp-decisions.md`（场景=多文件工程，形态=纯 `.typ`，实现=Rust→自举，生成物不入库，错误定位=D1）、`decisions/2026-09-11-engine-and-deps.md`（D6 引擎、D7 依赖策略）
- 原则：tangle 的语义与报错精度是产品本体；CLI/watch/诊断渲染用成熟库，不手写已被解决的问题。

## 里程碑

### M0 — 仓库与开发环境（已完成）
- `flake.nix` + `flake.lock`：`typst` + `rustc/cargo/rustfmt/clippy` + `python3`。实测 `cargo 1.97.0 / rustc 1.97.1 / typst 0.15.1`。
- 目录：`src/`（原型）、`lit/`（Typst 渲染库）、`experiments/`、`agent-notes/`。

### M1 — 原型 tangle + check + map（核心语义）
用 `typst-syntax` 直读 `.typ`（无子进程），把 Python spike 的语义做扎实并补上它故意没做的部分：

- `lp tangle <doc.typ>... [--out DIR] [--check]`
- 解析：递归遍历 CST，任一 `block: true` 且**后续 sibling 是 Label** 的 `Raw` 即 chunk；`raw.lines()` 取正文；`Source::lines().byte_to_line()` 得行号。
- 严格报错（`miette` 渲染，指向 `.typ` 源 span）：悬空引用、引用环、根 chunk 重名、根与非根重名、空 chunk。
- 同名 label 多块按文档顺序拼接（noweb 语义），并在 `cargo test` 里放 fixture 守住"Typst 容忍重复 label"这个未文档化行为。
- `lp map --file out/foo.rs --line 42` → `doc.typ:16`（消费 `.lpmap.json`）。
- `--check`：生成物与文档不一致 → 非零退出（CI 用）。
- **oracle 一致性测试**：同一批 fixture 上，`typst-syntax` 抽出的 `{label, lang, text}` 必须与 `typst eval`（CLI）输出完全一致。这条测试同时守住 trim 语义和将来的版本升级。
- 质量门：所有报错形如 `doc.typ:16:5: dangling chunk <<body>> referenced from <<main.c>>`，并带 `.typ` 源码片段。

**M1 起点（避免重新推导）**
- 布局：仓库根建 package `lp`（`src/main.rs` + `src/{syntax,chunks,tangle,map,cli}.rs`）；`experiments/` 不进 workspace（根 Cargo.toml 里 `[workspace] exclude = ["experiments/*"]`，probe 自带 Cargo.lock 与自己的 `cargo run` 用法）。
- 先写这三个测试再写实现：① `parse` fixture 化（复用 probe.typ 的 5 种形态：列表内嵌/同行 label/独行 label/重复 label/无 label）；② `typst eval` oracle 一致性；③ 同名 label 拼接顺序。
- `.lpmap.json` schema 在 M1 定死并写进仓库 README（形如 `{ "<输出文件>": { typ, lang, lines: [[outLine, typLine]], chunks: [{name, typLine}] } }`），`lp map` 只读它，不改它。

### M2 — 多文件工程 + watch + explain
- 多根 chunk → 目录结构（`src/`、`tests/`）；`--out` 与文档内相对路径的语义定死（相对 `.typ` 所在目录）。
- `lp watch <doc.typ>`：`notify` + `notify-debouncer-full`，正确处理编辑器原子写；出错只打印不退出。
- `lp explain`：读诊断（stdin 或文件）→ 翻译成 `.typ` 位置，`miette` 渲染。
  - 后端 1：`cargo_metadata` 解析 `cargo build --message-format=json`（自举时天天用）。
  - 后端 2：`regex` 表处理通用 `file:line:col:` 形式。
  - 纯查表 + 通用解析，**不含目标语言算法**。
- 负向测试：手改生成物 → `--check` 失败；`.typ` 引用写错 → 报错行号正确。

### M3 — 自举（bootstrap → self-host）
- 原型冻结为 `bootstrap/`（仍可编译可跑），工具自身源码改写为 `self.typ`（literate 文档）。
- **自举不变量（固定点测试）**：`bootstrap tangle self.typ --out src` 的产物与 `bootstrap/` 手写源码**逐字节相同**，且用产物 `cargo build` 出来的工具与原型行为一致（跑同一套测试）。
- 达标后 `self.typ` 成为唯一真相；`bootstrap/` 作为**非工具生成的种子**保留（因为生成物不入库，种子必须可编译）。
- 自举是可用性测试：如果天天退回手写源码，说明 chunk 语义或错误定位不可用。

## CLI 表面

```
lp tangle <doc.typ>... [--out DIR] [--check]
lp map    --file <generated> --line N [--col C]
lp explain [--format cargo|generic] [<diag-file>]
lp watch  <doc.typ> [--out DIR]
lp list   <doc.typ>            # 调试/agent 检索：chunk 名、根、引用图、源位置
```
- 退出码：0 成功；1 语义错误（悬空引用/环/漂移）；2 用法或环境错误。
- `typst` 二进制：**只在 weave 和 oracle 测试里需要**（tangle 走 `typst-syntax`）；定位顺序 `--typst` > `LP_TYPST` > `PATH`。

## 依赖（D7：成熟库优先）
见 ADR D7 的表格。首版新增依赖前必须在表里补一行"为什么是它"。当前：`typst-syntax`、`clap`、`serde`/`serde_json`、`thiserror`+`miette`、`notify`+`notify-debouncer-full`、`regex`、`cargo_metadata`、（dev）`tempfile`。

## 测试策略（ponytail：能失败的最小检查）
- `cargo test`：tangle 语义 fixture（拼接/缩进/嵌套块/悬空/环/重复 label）、oracle 一致性、固定点（M3）。
- 端到端沿用 `experiments/2026-09-11-chunk-spike/run.sh` 的模式：tangle → 跑生成物 → 比对期望输出 → `--check`。
- CI：`nix develop -c ./ci.sh`（`typst compile` + `cargo test` + `lp tangle --check` 无漂移）。

## 明确不做（YAGNI）
双向同步（Entangled 路线）、IR/provenance 数据库、多 markup 适配器（Ravel 路线）、代码块执行（Calepin 路线）、编辑器插件、`codly` 深度集成。
