# literate

基于 [Typst](https://typst.app) 的 literate programming 工具：**同一个 `.typ` 文件既是可排版的文档，也是目标语言源码的唯一真相**，并且与目标语言正交——tangle 只做 chunk 组合与缩进，不解析目标语言。

```sh
nix develop                     # typst 0.15 + cargo 1.97
lp tangle doc.typ --out out     # 把文档展开成源码
typst compile --root . doc.typ  # 把文档排成 PDF
```

## 文档长什么样

普通的 Typst 文档；**带 label 的 fenced code block 就是 chunk**：

````
```python
<<imports>>
print(greet("world"))
``` <main.py>                       # label 像文件名 → 这是一个输出文件

```python
from greet import greet
``` <imports>                        # 普通 chunk，被 <<imports>> 引用

```python
def greet(name):
    return f"hello, {name}"
``` #label("src/greet.py")            # 需要目录时用 Typst 的 constructor 写法
````

- `<<name>>` 独占一行时是引用，展开时按引用点的缩进整体缩进；其他位置（`std::cout << x`）保持字面量。
- 同名 label 的多块按文档顺序拼接（noweb / org-babel `:noweb-ref` 语义）。
- 根 chunk（label 看起来像文件名的）按 `--out` 写成文件；其余 chunk 只出现在被引用的地方。
- Typst 的 `<...>` label 只允许 `[A-Za-z0-9_.:-]`，**不含 `/`**，所以带目录的名字要用 `#label("src/main.rs")`。两种写法都原生、都可以被 `query` 看到（`@name` / show rule 同样适用）。

## 命令

```
lp tangle <doc.typ>... [--out DIR] [--check]   # 展开；--check 不写文件，发现漂移则退出码 1
lp map    --file src/main.rs --line 42         # 生成文件的第 42 行来自哪一行 .typ
lp explain [--out DIR]                         # 把 file:line:col 诊断翻译回 .typ（读 stdin）
lp list   <doc.typ>                            # 列出 chunk：根/片段、语言、源行号、是否被引用
```

退出码：0 成功，1 语义错误（悬空引用 / 引用环 / 空 chunk / 漂移），2 用法错误。

## 流程（可运行）

`nix develop -c examples/demo/run.sh` 会跑完整条链路：tangle 一个多文件 Rust crate → `cargo run` 并与文档里写死的输出比对 → weave 出 PDF → `--check` 无漂移 → `lp map` 定位一行 → 故意写错一行让 rustc 报错、再用 `lp explain` 把错误翻译回 `.typ` → 复原。

关键输出（诊断回译）：

```
src/main.rs:6:38: error[E0425]: cannot find function `ad` in module `math`
  ↳ examples/demo/literate.typ:92 (chunk <<print-results>>)
    ╭─[examples/demo/literate.typ:92:1]
 92 │ println!("add(2, 3) = {}", math::add(2, 3));
    ·                       ╰── generated from examples/demo/literate.typ:92
```

## 行号映射

`lp tangle` 在每个 `--out` 目录里写一份 `.lpmap.json`：

```json
{
  "version": 1,
  "docs": ["examples/demo/literate.typ"],
  "files": {
    "src/main.rs": {
      "typ": "examples/demo/literate.typ",
      "lang": "rust",
      "lines": [[1, 82], [7, 92]],
      "chunks": [{ "name": "print-results", "typ_line": 91, "end_line": 93 }]
    }
  }
}
```

`lines` 是 `[生成文件行, .typ 行]`，指向**定义处**而不是引用处；`lp map` / `lp explain` 只读它、不改它。生成物不入库：CI 跑 `lp tangle --check`，漂移即失败。

## 状态

原型可用（M1 + `lp explain` 的通用后端）；详见 [`agent-notes/`](agent-notes/README.md)：

- [`agent-notes/plan.md`](agent-notes/plan.md) — M0–M3 计划与已完成范围
- [`agent-notes/decisions/`](agent-notes/decisions/) — 已拍板的 ADR（架构、引擎、依赖、chunk 命名）
- [`agent-notes/research/`](agent-notes/research/) — 现有工具盘点、Typst 实测事实、设计空间
- [`experiments/`](experiments/) — 两个丢弃型验证（Python 端到端 spike、`typst-syntax` span probe）

下一步：`lp watch`（notify）、`lp explain --format cargo`（cargo JSON）、列位置精确到诊断坐标、以及自举（工具自身源码改写成 literate `.typ`）。
