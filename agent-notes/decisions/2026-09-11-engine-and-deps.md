# 引擎与依赖策略（2026-09-11，修正 D3 的两处过度简化）

用户在 D1–D5 之后追加了一条修正：「用成熟库，不要逃避问题」。这条推翻了我原先 plan 里的两处"手写"倾向（手写参数解析、mtime 轮询 watch、不用 anyhow），也顺带把 backlog 里悬着的"能否用 `typst-syntax` 替代 `typst eval`"变成决定。

---

## D6 — 解析引擎：`typst-syntax` 为主，`typst eval` 降为一致性参照

- **决定**：
  - tangle 的解析**链接官方 `typst-syntax` crate**，直接遍历 CST 取 chunk（lang / label / body）**和精确字节区间**。
  - `typst eval`（CLI）不再是 tangle 的运行时依赖，转为**测试 oracle**（同一批 fixture 两条路取出的 chunk 必须完全一致），以及在用户 typst 版本与 crate 版本不匹配时的降级后端。
  - weave 仍然只是 `typst compile`（用用户自己的 typst，版本不受我们限制）。
- **落选**：
  - 只用 `typst eval` CLI + 用 label 唯一性反查行号（Python spike 的做法）——那是"能用但回避了问题"：拿不到精确 span，`first_code_line()` 靠向上找 fence，遇到嵌套块就错（probe 已证明列表里的 chunk 是**嵌套节点**，不是顶层节点）。
  - 链接完整的 `typst` / `typst-library` 编译器 crate（能做 in-process introspection）——依赖面大得多，而我们只需要语法层。
- **理由（实测，见 `experiments/2026-09-11-typst-syntax-probe/`）**：
  - `Source::detached` + `LinkedNode` 给出每个 raw 块的**字节区间**，`src.lines().byte_to_line()` 直接得行号；label 是 raw 的 sibling 节点（同行的 `` ``` <x> `` 和独立一行的 `<x>` 两种写法都识别）。
  - `raw.lines()` 取出的文本与 `typst eval` 的 `text` **逐字节相同**，包括列表内缩进块（Typst 的公共缩进裁剪由 parser 的 `RawTrimmed` 节点完成，我们不需要复刻裁剪算法）。
  - 重复 label 两块都能拿到；未标 label 的块自然被过滤。
  - 因此 tangle **不需要 typst 二进制**（更快、无子进程、无 PATH 依赖），只有 weave 需要。
- **代价（接受并管理）**：`typst-syntax` 版本要跟着 Typst 语言演进（0.15.x 对齐）；升级策略是"改 Cargo.toml 版本 + 跑 oracle 一致性测试"。

---

## D7 — 依赖策略：用成熟库，不手写已被解决的问题

- **决定**：能在成熟 crate 里解决的事一律不手写。首版依赖清单：

| crate | 用途 | 为什么是它（而不是手写） |
| --- | --- | --- |
| `typst-syntax` | 解析 `.typ`、拿 span | 官方 parser；见 D6 |
| `clap`（derive） | CLI 解析 | 子命令/帮助/补全/错误信息的工业标准；手写会在 20 个 flag 后崩掉 |
| `serde` + `serde_json` | `.lpmap.json`、`typst eval` oracle 对比 | 事实标准 |
| `thiserror` + `miette` | 错误类型与**面向 `.typ` 源码的报错渲染** | miette 专门做"把诊断指向源文件 span"，正是本项目核心差异化的展示面；手拼 `file:line:` 字符串是退步 |
| `notify` + `notify-debouncer-full` | `lp watch` | 跨平台文件监听 + 事件合并 + 编辑器原子写（rename）处理；轮询 mtime 会漏编辑器保存语义 |
| `regex` | `lp explain` 的通用 `file:line:col` 诊断提取 | 正则表是数据，不需要手写 parser |
| `cargo_metadata` | `lp explain` 的 rustc/cargo JSON 后端 | cargo 官方维护的消息格式类型；自己反序列化会随格式漂移 |
| `tempfile`（dev） | 测试里的临时工作目录 | |

- **落选**：原 plan 的"手写参数解析 + mtime 轮询 + 不用 anyhow"的依赖预算。那份预算是**错误的**：它把"自举后依赖也要在文档里维护"当成理由，但依赖住在 `Cargo.toml`/`Cargo.lock`，不在 literate 文档里；而参数解析、watch 语义、诊断渲染恰好是**已经被彻底解决好**的问题，手写等于把有限精力从"tangle 语义 + 错误定位精度"上挪走。
- **理由**：项目的难点在 chunk 语义、行号映射、报错精度、自举，不在 CLI 与文件监听。D7 与 D3 不冲突：自举只要求**我们自己的源码**以 `.typ` 为真相，不要求依赖也如此。
- **约束（避免走向另一个极端）**：每新增一个依赖，必须在 `plan.md` 的依赖表里写一行"为什么是它"；能用现有依赖解决的不加新依赖；不为"将来可能需要"预埋依赖。
