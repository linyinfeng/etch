# Spike: label 化作 fence block 当 chunk（2026-09-11）

目的：验证"**纯 `.typ` 既是文档又是 literate 源**"这条主线能不能跑通，以及 tangle 需要的数据能不能只靠 Typst CLI 拿到。**这是验证用的丢弃型代码，不是产品原型。**

## 怎么跑

```sh
nix shell nixpkgs#typst nixpkgs#python3 -c ./run.sh
# 或： TYPST=/path/to/typst ./run.sh
```

`run.sh` 做四件事：`typst compile hello.typ`（weave 出 PDF）、导出 PNG、`tangle.py hello.typ --out out`（tangle 出 `out/hello.py`）、跑生成的程序并与 `expected.txt` 比对、最后 `--check` 确认没有漂移。

## 文件

| 文件 | 说明 |
| --- | --- |
| `hello.typ` | 主文档。合法 Typst（`typst compile` 直接出 PDF），同时是 `out/hello.py` 的唯一真相 |
| `lit.typ` | 约 30 行的 Typst 库：把带 label 的 raw block 渲染成"chunk 标题 + 灰底代码块 + 绿色可点击的 `<<引用>>`" |
| `tangle.py` | tangle：调 `typst eval` 取 chunk → 展开 `<<ref>>`（含缩进）→ 写文件；`--check` 检测漂移；同时产出 `out/.lpmap.json` 行号映射 |
| `weave.png` | weave 结果截图（`typst compile --format png`） |
| `expected.txt` | 生成程序的标准输出，`run.sh` 用它当断言 |

## 验证到的结论

1. `typst eval 'query(raw.where(block: true)).map(...)'` 能一次拿到 `{label, lang, text}` 列表，**不需要自写 Typst 解析器**。
2. 同一文件 `typst compile` 出的 PDF 里，chunk 有标题、有灰底、`<<body>>` 是绿色可点击链接 → weave 不需要预处理器。
3. noweb 式组合可用：`<<name>>` 整行引用 + 缩进传递；**同名 label 多块按文档顺序拼接**（`<body>` 定义两次，生成的两行都在）。
4. 生成物可运行（`python3 out/hello.py` 输出与 `expected.txt` 一致）→ 端到端闭环成立。
5. `--check` 能发现生成物被手改（追加一行 → `STALE` + exit 1）。
6. 行号映射可做：`out/.lpmap.json` 里 `hello.py:1 ← hello.typ:16`（按 label 在源文件中唯一出现的位置反查，绕开 Typst 不暴露 span 的限制）。

## 已知限制（故意没做）

- 没做错误定位的**消费端**（`lp explain` 之类）；只产出映射数据。
- 根 chunk 判定是"label 长得像文件名"的启发式；`<<ref>>` 语法不可配置；没有 watch 模式。
- `first_code_line()` 在源文件里向上找最近的 fence 来定位 chunk 首行，够用但不严谨（遇到嵌套/异常缩进会错位）。
- 没有重复 chunk 冲突策略、没有跨文件/多根依赖管理、没有和 codly 共存（`lit.typ` 自己包了 raw 的渲染）。
- `typst` 路径在本机是硬编码 store 路径兜底，产品里不该这样。
