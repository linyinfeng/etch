# 实施计划（M0–M3）

> **历史文件**（2026-09-11 注）：M0–M3 都已落地——M3 Stage 1（自举）与仓库收敛见 `decisions/2026-09-11-final-shape.md`（D19）。仓库现在要读的是 `lp.typ`；本文保留作为"当时怎么计划的"记录，不再更新。

- 日期：2026-09-11（v3：D13/D14 之后——**工具不再解析 Typst**，chunk 由声明给出（`#chunk`/`#file`），行号映射删除；下文的 M1 段落保留为历史）
- v2：按 ADR D6/D7 修正引擎与依赖（D6 的解析引擎部分后来被 D13/D14 取代）
- 前置：`decisions/2026-09-11-mvp-decisions.md`（场景=多文件工程，形态=纯 `.typ`，实现=Rust→自举，生成物不入库，错误定位=D1）、`decisions/2026-09-11-engine-and-deps.md`（D6 引擎、D7 依赖策略）
- 原则：tangle 的语义与报错精度是产品本体；CLI/watch/诊断渲染用成熟库，不手写已被解决的问题。

## 里程碑

### M0 — 仓库与开发环境（已完成）

- `flake.nix` + `flake.lock`：`typst` + `rustc/cargo/rustfmt/clippy` + `python3`。实测 `cargo 1.97.0 / rustc 1.97.1 / typst 0.15.1`。
- 目录：`src/`（原型）、`lit/`（Typst 渲染库）、`experiments/`、`agent-notes/`。

### M1 — 原型 tangle + check + map（已完成，2026-09-11）

实现（历史，见 v3 修正）：当时是 `src/{main,parse,tangle,map,explain,diag}.rs` + `lit/lit.typ` + `tests/flow.rs`。现在 `parse.rs` 已删，代码是 `src/{main,tangle,status,map,watch,metadata,explain,diag}.rs`（~1.8k 行），`lit/lp.typ` 是包（渲染 + `#chunk`/`#file` 声明）。

- ✅ `lp tangle <doc.typ>... [--out DIR] [--check]`
- ~~解析：`typst-syntax` 递归遍历 CST；接受两种 label 写法~~ → **D13 取代**：chunk 由 `lit/lp.typ` 的 `#chunk`/`#file` 声明给出，工具只读 `typst eval 'query(<lp-decl>)'`
- ✅ 严格报错（`miette` 渲染，指向 `.typ` 源 span）：悬空引用、引用环、空 chunk、不安全输出路径
- ✅ 同名 label 多块按文档顺序拼接；缩进按引用点传递（`tests/flow.rs` 覆盖）
- ✅ `lp map`（当时 `[生成行, .typ 行]`；D14 后改为 chunk 区间，见下）+ `lp list`
- ✅ `lp explain` 的**通用后端**（`file:line:col:` → `.typ` 源片段）；未引用 chunk 告警
- ⏳ 当时留到下一轮：`lp watch`（`notify`）✅ 已完成、`lp explain` 的 cargo JSON 后端（`cargo_metadata`）⏳ 仍未做、~~诊断列位置精确到 span~~（D14 已删掉 span 报错，出处只在 chunk 级）、“同一 chunk 被多个根复用”与多文档合并的边界测试

**下一步起点**：`src/` 是普通 Rust 工程（`cargo test` 全绿）；演示与回归入口是 `examples/demo/run.sh`（tangle → 构建运行 → weave → `--check` → map → explain 回译 → 复原）。

### M2 — 多文件工程 + watch + explain（进行中）

- ✅ 多根 chunk → 目录结构（`src/`、`tests/`）；输出路径相对 `--out`。
- ✅ `lp watch <doc.typ>`：`notify` + `notify-debouncer-full`；只写字节变化的输出、语法错误不 tangle、出错只打印不退出。**行为契约见 ADR D9**，实测见 `research/2026-09-11-lazy-tangle.md`。
- ✅ `lp explain` 的通用后端（`regex` 表处理 `file:line:col:`），纯查表 + 通用解析，**不含目标语言算法**。
- ✅ `lp map` 双向（`--file` / `--typ`）。
- ✅ **D13 已落地**：chunk 由**声明**给出（`lit/lp.typ` 的 `#chunk`/`#file`），工具只读 `query(<lp-decl>)`；`typst-syntax` 已删除。
- ✅ **D14 已落地**：**行号映射删除**（`locate.rs`/`source.rs` 删除，schema v5 改为 chunk 区间）。Typst 脚本层拿不到源位置，要行号就得脏做，按规矩不做。
- ⏳ 多章文档（超出现计划）：跨文档 ChunkSet → 映射 schema v3（per-line 源文件）→ 跟随 `#include`，见 `research/2026-09-11-typst-structure-and-include.md` 的缺口表。
- ⏳ 剩下：`lp explain` 的 cargo JSON 后端（`cargo_metadata` 解析 `--message-format=json`，自举时天天用）、`ci.sh`（typst compile + cargo test + `tangle --check`）。~~诊断列位置精确到 span~~ → D14 已删掉 span 报错，出处只在 chunk 级。
- ✅ 删除语义（超出原计划）：删根 chunk 不再留孤儿——`.lpignore` 目录声明 + `ignore` crate 的 gitignore 语义 + `--check` 干跑，见 ADR D10，回归在 `tests/owned.rs`。
- ✅ **引用转义（D17，2026-09-11）**：`@<<name>>` 让文档能原样展示 `<<name>>` 独占一行；skill 自己进了文档，所以需要它。
- ❌ **结构强制（D16）已被 D18 推翻**：顺序自由、`lang` 不检查。工具只管机制（引用可解析/无环/非空/`--check`/所有权），语义自洽靠 skill（写作者）。

### M3 — 自举（bootstrap → self-host）

**Stage 1 — 逐字节固定点（已完成，2026-09-11，ADR D15）**

- ✅ 原型冻结为 `seed/`（可编译可跑，tracked，**永不重新生成**）。
- ✅ 工具自身源码改写为 `lp.typ`（本次是忠实转写：一个文件一个根 chunk，不共享、不加散文）。
- ✅ **达成标准**：`seed/target/debug/lp tangle lp.typ --out . --check` 绿 = 产物与冻结前的手写源码逐字节相同。
- ✅ **永久不变量**（`tests/self.rs`）：自己构出来的二进制跑 `lp tangle lp.typ --out . --check` 必须绿——“文档复现了我正在运行的那份源码”，不依赖 `seed/` 仍然相等。
- ✅ 翻转完成：根的 `Cargo.toml`/`src/`/`tests/` 出 git、进 `.gitignore`；根 `.lpignore` 列出全部手写资产（`--out` 就是仓库根）。

**Stage 2 — literate 化（未做，需要时再说）**

- 把重复片段抽成 `#chunk` 共享、加散文、按章节用 `#include` 拆。
- 这时产物**不再**等于 `seed/`；合法状态由永久不变量守（`--check` 绿 + `cargo test` 绿），达成标准那一栏变成历史。
- 自举是可用性测试：如果天天退回手写源码，说明 chunk 语义或错误定位不可用。

## CLI 表面

```
lp tangle <doc.typ>... [--out DIR] [--check]
lp map    --file <generated> --line N | --typ <chunk> [--out DIR]
lp explain [--out DIR]                         # 读 stdin，逐行回显并注解
lp watch  <doc.typ>... [--out DIR] [--debounce MS] [--check-cmd CMD]
lp list   <doc.typ>            # 调试/agent 检索：chunk 名、根、引用图
lp metadata <doc.typ>...       # 让 Typst 求值并打印有序声明流（调试用）
lp unaccounted <doc.typ>... [--out DIR] [--delete]
```

- 退出码：0 成功；1 语义错误（悬空引用/环/漂移）；2 用法或环境错误。
- `typst` 二进制：**tangle 的硬依赖**（D13 起靠 `typst eval` 读声明）+ weave + `cargo test`；定位顺序 `LP_TYPST` > `PATH`。

## 依赖（D7：成熟库优先）

见 ADR D7 的表格。首版新增依赖前必须在表里补一行"为什么是它"。当前：`clap`、`serde`/`serde_json`、`thiserror`+`miette`、`notify`+`notify-debouncer-full`、`ignore`、`regex`、（dev）`tempfile`。已移除：`typst-syntax`（D13）。尚未引入：`cargo_metadata`。

## 测试策略（ponytail：能失败的最小检查）

- `cargo test`：tangle 语义 fixture（拼接/缩进/嵌套块/悬空/环/重复 label）、oracle 一致性、固定点（M3）。
- 端到端沿用 `experiments/2026-09-11-chunk-spike/run.sh` 的模式：tangle → 跑生成物 → 比对期望输出 → `--check`。
- CI：**暂不做**（2026-09-11 用户：自举稳住之前 CI 没意义）。将来要跑的就是 README "自举"那三步 + `lp tangle lp.typ --check` + `examples/demo/run.sh`。

## 明确不做（YAGNI）

双向同步（Entangled 路线）、IR/provenance 数据库、多 markup 适配器（Ravel 路线）、代码块执行（Calepin 路线）、编辑器插件、`codly` 深度集成。
