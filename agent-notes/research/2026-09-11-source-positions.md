# Typst 能不能给出"这行代码在源文件哪一行"（2026-09-11 调研）

- 问题（用户提出）：`typst 内部能否查询到自己的代码位置`；并给出条件——如果不能，就不要做 lpmap，"我们不实现脏活才能做出来的功能"。
- 结论（先给答案）：**分层看，只有一层能，而且不是我们能用的那层。**
  1. **Typst 脚本层（包、`context`、show rule、`query`）：不能。** 元素不带源位置。
  2. **WASM 插件层：不能。** 协议只传参数字节。
  3. **编译器层（Rust，`typst-syntax`）：能**——`Span` → 字节区间 → 行号，这正是诊断信息里 `file:line:col` 的来源；但它只通过**诊断**对外暴露，没有可查询的索引，CLI 也没有 dump 语法树的子命令。
- 于是 lpmap 的定位只能靠：(a) 链接 Typst 自己的 parser crate 拿 span，或 (b) 在源码里搜索声明 token（现方案），或 (c) 作者手写行号，或 (d) 不做行号。
- **测量结果：现方案 (b) 已经在自己的 demo 上出错**（见 §3），所以它确实属于"脏活"。

---

## 1. 脚本层：元素没有源位置

```sh
$ typst eval 'query(raw).first().fields().keys()' --in f.typ
["text","block","lang","align","syntaxes","theme","tab-size","lines","label"]

$ typst eval '```py print(1)```.spans()'      # → error: element raw has no method `spans`
$ typst eval '```py print(1)```.span()'       # → error: element raw has no method `span`
$ typst eval '```py print(1)```.location()'   # → null（且 location 是排版位置）
```

- `fields()` 是元素**全部**字段，里面没有 span；`.span()` / `.spans()` 根本不存在。
- 官方文档对 `location` 的定义是 "Identifies an element in the document and lets you access its **absolute position on the pages**"，API 只有 `page()` / `position()`（page + x/y）/ `page-numbering()`——**排版坐标，不是源位置**。`raw` 确实 locatable，但拿到的仍是页坐标。
- introspection 类目的函数**全部**就这七个：`counter`、`here`、`locate`、`location`、`metadata`、`query`、`state`。没有任何一个涉及源位置。
- 附带一个可用的替代信号：`location().page()` 是**编织出来的 PDF 的页码**——对读 PDF 的人是真实指针，对"该改哪一行"不是。

## 2. 插件层：协议里没有位置

官方 plugin 文档：插件函数接收 `n` 个 32 位长度参数（参数以字节缓冲传入），返回一个缓冲；"plugins run in isolation from your system... printing, reading files, or similar things are not supported"。**参数里没有位置信息**，插件也无权读宿主。

## 3. 编译器层：能，但只经诊断暴露

- `typst-syntax` 的 `Source` / `SyntaxNode` / `Span` 就是编译器自己的语法层：`Span` → 字节区间（`Source::find`），`lines().byte_to_line()` 给行号。本项目早前的 `parse.rs` 与 probe 都验证过（列表里的嵌套块、同行 label 等都能拿到精确 span）。
- 对外的唯一出口是**诊断**：`typst compile` 报错时打印 `file:line:col`（我们每次都看到）。CLI 子命令只有 compile / watch / init / eval / fonts / completions / info / help——**没有 dump 语法树或 span 的命令**；`typst eval` 只序列化值，不含位置。

## 4. 现方案（搜索声明 token）的实测错位

demo 文档里，散文在**第 60 行**提到 `` `#chunk("math-items", …)` ``（讲机制时引用了它），真正的声明在 **64 / 72 行**：

```sh
$ lp map --file src/lib.rs --line 4 --out examples/demo/build
examples/demo/literate.typ:61
    blocks. Tangling concatenates declarations sharing a name, in document order, the
```

工具把输出行定位到了**散文**（60+1=61），而不是声明（64）。原因就是字符串搜索取第一个出现位置——token 出现在代码里之前，先出现在讲它的散文里。**这不是理论风险，是我们自己的文档触发的**：任何"在正文里引用自己写法"的文档都会中招。

## 5. 四条路，代价摆开

| | 机制 | 依赖 | 精确性 | 是否脏活 |
| --- | --- | --- | --- | --- |
| **A 不做行号** | 出处 = (chunk 名, chunk 内第几行)，附带声明里的正文片段 | 无 | 精确到**声明**，不到行 | 不脏，但放弃 `.typ:行` |
| **B parser 当 span 查询器** | 用 `typst-syntax` 解析源码，直接拿到 `#chunk("x"` **调用节点**的行（散文/raw 块里的同名文本不会被误认） | 重新引入 `typst-syntax`，版本需与 `typst` 二进制对齐 | 精确到行 | 不是"分析 Typst 语义"，但**又要在工具里解析 Typst** |
| **C 作者写行号** | 声明显式带行号 | 无 | 精确 | 不可维护 |
| **D 继续字符串搜索** | 现状 | 无 | **已被证明会错**（§4） | 是 |

## 6. 推荐：A（删掉 lpmap，保留 chunk 级出处）

理由：
1. 用户已定的原则是"不实现脏活才能做出来的功能"，而**唯一不脏的行号来源（B）意味着把 Typst parser 放回工具里**——这正是我们刚花力气删掉的东西（"工具对 Typst 的全部理解就是 Typst 自己"）。要不要为行号破这条，是判断题，不是技术判断。
2. A 并不等于"没有出处"。展开时我们**天然知道**每一段输出行来自哪个声明、在该声明的第几行（不需要搜索、不需要解析），所以可以给出：
   - `lp explain`：`src/main.rs:6:38: error[E0425] …` → `↳ chunk ⟪print-results⟫ line 1 of 2` + **该行原文**（声明里带着），agent 直接 `rg '#chunk\("print-results"'` 一跳就到；
   - 漂移报告：`STALE src/main.rs (line 2, in chunk ⟪print-results⟫)`；
   - `.lpmap.json` 从"每行一个 `.typ` 行号"变成"每个输出文件一串 **chunk 区间**"（`[起, 止, chunk 名, 该 chunk 内偏移]`）——更小、更稳、无位置。
3. A 让工具显著变小：`locate.rs`（整个 token 搜索）删除，`map.rs` 的行对变成区间，`explain` 少一套文件读取与行号翻译，`tests` 少一批".typ:行"断言。
4. B 不死：如果以后确实需要 `.typ:行`，把 `locate.rs` 换成"parser 取调用节点 span"即可，接口不变（`Placed`/`line_for` 保留）。**先不做。**

## 7. 落地清单（若采用 A）

- `src/locate.rs`：删除（连同 6 个单元测试）；`Placed` 概念消失。
- `src/tangle.rs`：`Tangled.lines` 改为**chunk 区间**：`(output_line_range, chunk_name, offset_in_chunk)`；`expand_chunk` 里记录（本就已经在逐块、逐行地展开）。
- `src/map.rs`：schema v5 —— `FileMap { sources?（不再需要）, lang, runs: [{chunk, first, last, offset}] }`；`lp map` 打印 `chunk ⟪X⟫ + 该行在 chunk 内的偏移与原文`。
- `src/explain.rs`：去掉"读源文件 + 行号翻译"，改成 chunk 级 + 片段；（`lp explain --format cargo` 仍未做。）
- `src/metadata.rs`：不变（声明流）。`sources()`（include 扫描）**也可以删**——不再需要知道源码文件集合。→ 工具里对 Typst 的全部"理解"就只剩：跑一次 `typst eval` 读声明。这是最干净的状态。
- 文档：README/ADR D13 更新；ADR D11（映射作用域）与 v4 schema 记入历史。
