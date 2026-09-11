# 用 Typst 自己当解析器：实测事实清单

- 日期：2026-09-11
- 环境：`typst 0.15.1 (9dfd3a08)`，来自 nixpkgs（本机 store 路径 `/nix/store/n1fhw9lc9zxmz1w11d1zykmsqwi5bxcd-typst-0.15.1/bin/typst`；`nix shell nixpkgs#typst -c typst --version` 可复现）。
- 方法：所有结论都在本机跑过；下面每条都给出可复制命令。没跑过的标 **未验证**。
- 一句话结论：**Typst 前端 + label 足以承担 tangle 的解析工作，不需要自写 Typst 解析器**；但 Typst 不暴露源码 span，所以"行号映射"必须由 tangle 工具自己按 label 定位。

---

## 1. chunk 的定义：带 label 的 fenced raw block

````
```py
code
``` <chunk-name>
````

```sh
$ typst compile doc.typ out.pdf        # 验证：这是合法 Typst，能正常排版
$ typst eval 'query(raw.where(block: true)).map(e => (label: str(e.at("label", default: none)), lang: e.lang, text: e.text))' --in doc.typ
[{"label":"main.c","lang":"c","text":"#include <stdio.h>\n\nint main(void) {\n  <<body>>\n  return 0;\n}"},
 {"label":"body","lang":"c","text":"  printf(\"hi\\n\");"}]
```

- label 可以写在 **closing fence 同一行**（```` ``` <main.c> ````），也可以单独占一行。两种都被 `query` 正确识别（实测）。
- `str(label)` **不带尖括号**（`label("body")` → `str` = `"body"`，`repr` = `"<body>"`）。写比较逻辑时注意。
- query 返回的字段：`func/text/block/lang/align/syntaxes/theme/tab-size/lines/label`。`lines` 里每行带行号和已经过语法高亮的 `body`（体积大，tangle 不需要）。
- **没有 span / 源文件行列信息**（实测输出里没有，Typst 也不提供该字段）。→ 想给出"`.typ` 第 N 行"只有两条路：(a) 工具自己扫源文件；(b) 用 label 在源文件里唯一出现这一性质反查（spike 用 (b)，能拿到 chunk 首行）。`element.location()` 只是**排版**位置（页/坐标），不是源位置。

## 2. CLI 接口（0.15 起）

| 命令 | 状态 | 备注 |
| --- | --- | --- |
| `typst eval '<expr>' --in doc.typ [--format json\|yaml]` | 0.15 新增，推荐 | expr 是任意 Typst 代码，可 `.filter/.map` 投影，输出小；文档有错则退出码 1 |
| `typst query <input> <selector> [--field X] [--one]` | 0.15 起 deprecated，仍可用 | 位置参数，不是 `--in`；selector 如 `'raw.where(block: true)'`。向后兼容 0.14 及以前就用它 |
| `typst compile doc.typ out.pdf` | weave 本体 | 支持 `--format png/pdf/svg`（png 多页需 `page-{p}.png` 模板），`--ignore-system-fonts` 适合 hermetic CI |
| `typst eval ... --target html` / `--features html` | HTML 导出仍是开发中特性 | 0.15.1 里不带 `--features html` 会直接报错 |

`typst eval` 在**文档任意位置有错误时也会失败**（`#undefined-fn(1)` → exit 1）。影响：tangle 依赖整篇文档能完整求值，prose 里的一个 typo 会阻断抽取。缓解：CI 里先跑 `typst compile`（报错信息本来就要看），或让 tangle 报错时把 typst 的诊断原样透出。

实测：主文件名/扩展名任意，`doc.lit` 一样能被 `compile` / `eval --in` 处理（typst 不看扩展名）。
`read()` 在 eval 环境里可用（相对 cwd），所以 **tangle 逻辑本身也可以写在 Typst 里**（见 design-space 的方案 A′）。

## 3. 坑：不要往 fence info string 里塞元数据

实测（0.15.1）：

| 源码 | `lang` | `text` |
| --- | --- | --- |
| ```` ```c main.c ```` | `c` | `main.c\nint a;` ← 元数据变成代码第一行！ |
| ```` ```C++ ```` | `C` | `++\nint a;` + 警告 *no whitespace between language tag and raw text* |

官方文档明说这条规则**下一版会改**（改成"到第一个空白或反引号为止都算 lang tag"）<https://typst.app/docs/reference/text/raw/#language-tag-changes>，dev 分支已有 PR #8257 反复 revert/恢复。
→ **结论：chunk 名只能靠 label，语言只能靠 lang，两者都不许混进 info string。**

## 4. 重复 label：可以做 noweb 追加语义，但别信它

实测：两个 block 都标 `<body>`，`typst compile` **退出码 0、不警告**，`query` 返回两条。

- 利用它：同一 chunk 名多块 → 按文档顺序拼接（noweb / org-babel `:noweb-ref` 的语义）。
- 风险：(a) 官方文档要求 label 唯一，当前宽容是未文档化行为；(b) `@body` / `link` 指向哪个是不确定的；(c) 未来版本可能改成报错。
- → 要么在 CI 里跑一条"多块拼接仍然工作"的回归测试，要么改成显式追加语法（`<<name>>+=`）。

## 5. show rule / label / link 的语义边界（写 weave 库时踩过的坑）

| 现象 | 事实 | 对策 |
| --- | --- | --- |
| `it.label` 报 `raw does not have field "label"` | **无 label 的元素上没有这个字段** | `it.at("label", default: none)` |
| `#import` 进来的模块里写的 show rule 不生效 | Typst 的作用域规则：import 只带定义，不带 show rule | 库导出模板函数，用 `#show: lit` 挂载 |
| show rule 里 `link(label("body"))` 报 `label <body> occurs multiple times` | 用字符串构造的 Label 值在内容流里会被当成"附着 label" | 用 `link(target.location())`（实测可用），或字面量 `link(<body>)`（实测也可用） |
| show rule 里 `⟪#lbl⟫` 什么都不显示 | Label 值渲染出来是空（它本来不可见） | 显示用 `#str(lbl)` |
| 想给 chunk 编号/页码 | `#context counter(page).at(<label>).first()` 可用（实测 exit 0） | weave 里可做"定义在第 X 页"的交叉引用 |

## 6. Typst 的能力边界（决定了架构）

- **plugin（WASM）不能读写文件、不能打印**，只能"输入 bytes → 输出 bytes"（官方文档明说 runs in isolation）。→ **tangle 不可能在 `typst compile` 里完成**，必须有外部进程写文件。
- `typst compile` 只能输出 pdf/png/svg（HTML 需 `--features html` 且未完成）。没有"输出任意文件"的口子。
- 因此架构必然是：**Typst 负责解析 + 渲染，外部小 CLI 负责 `typst eval` + 写文件 + 报错映射**。

## 7. spike 里已经被验证的完整链路

见 `experiments/2026-09-11-chunk-spike/`：

- 普通 `.typ`（`#show: lit` + label 化的 fenced block）→ `typst compile` 得到带 chunk 标题、灰底代码块、绿色可点击引用的 PDF（截图 `weave.png`）。
- 同一文件 → `typst eval` 取 chunk → 现在式展开 `<<ref>>`（含缩进）+ 同名多块拼接 → 写出可运行的 `out/hello.py`（实跑输出与 `expected.txt` 一致）。
- `--check` 能检测生成物被手改（实测：追加一行 → `STALE` + exit 1；重新 tangle → `ok` + exit 0）。
- 每个输出行都带 `.typ` 源行号，落在 `out/.lpmap.json`（例：`hello.py:1 ← hello.typ:16`）。
