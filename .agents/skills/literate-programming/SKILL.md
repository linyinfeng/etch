---
name: literate-programming
description: Write and maintain a program as a literate document - one Typst source that explains the program in prose and, from that same text, tangles into real source files and weaves into a PDF. Covers the discipline (reader first, narrative order, chunk granularity, prose that explains why, when it is worth it) and the lp tool's mechanics (declarations, references, indentation, watch, --check, map/explain, output ownership, self-hosting). Use when writing or editing a literate program, adding or reorganising chunks, working on self.typ, or running lp.
---

# Literate programming

A literate program is a document that explains a program and, from that same text, produces it. The reader comes first: the code lives inside the explanation, not the other way round.

One source, two products: **tangle** (the machine's copy — compilable source files) and **weave** (the human's copy — a typeset document). Neither is the original.

Two things make this worth the effort in an agent workflow: the document is the complete context for the code (nothing is implemented that the text does not explain), and the checks below are what stop the two from drifting apart. Prose that nobody verifies is worse than no prose.

## Decide first whether this is a literate program

Worth it: teaching and tutorials; algorithms and protocols that need more than a diff to explain; tooling and bootstrapping you will come back to; configuration and decision records, where the *why* is the expensive part; single-author projects.

Not worth it: throwaway scripts; code refactored far more often than it is read; a large team whose review flow is pull-request diffs and who will not read the document.

If it is worth it, then **the document is the only truth**: never edit a tangled file. It will be overwritten by the next tangle, and `lp tangle --check` will report it as drift.

## The discipline (this is what makes it literate rather than commented)

1. **Write in the order a reader should meet the ideas**, not the order the machine runs them. Defer detail behind a name and explain it later.
2. **One chunk is one thing a paragraph can explain.** Default to one root chunk per file and split down only when a step earns a name in the prose. Do not chunk at function granularity — a chunk name competing with a function name is the classic smell. A five-line chunk with a real sentence is fine; a 200-line chunk is a dumped file.
3. **Prose says why and what for**, never what the code already says. Trivial chunks get one line of prose; boilerplate narrative is a real cost, so spend words where the reader is lost.
4. **Name chunks as phrases the prose can use**: "Now we <<check the header>>…". The name is the interface the reader meets before the body.
5. **Keep the document evaluable at every save.** A document Typst cannot evaluate tangles nothing at all (lp deliberately keeps the last good output instead of writing half of one).

## What an lp document looks like

````
#import "lit/lp.typ": chunk, file, rule
#show: rule

= The program

Prose: what this program is for, and why it is built the way it is.

#file("src/main.py", ```python
<<imports>>
print(greet("world"))
```)

#chunk("imports", ```python
from greet import greet
```)

#file("src/greet.py", ```python
def greet(name):
    return f"hello, {name}"
```)
````

- `#file(path, code)` — a **root chunk**. Its name is the path it tangles to. Every produced file needs one, and nothing else produces files.
- `#chunk(name, code)` — a **fragment**, which exists only where something references it.
- `<<name>>` **alone on a line** is a reference; anywhere else (`a << b`, `assert_eq!(x, "<<y>>")`) it stays literal text. The indentation of the reference line indents the whole expansion, so nested blocks keep their layout.
- Repeating a name **concatenates in document order** — one file can be written in several places, each explained where it belongs.
- The language tag on the fence is the tangled file's language. Nothing in `lp` parses it; it is data.
- Block content is taken verbatim and flush left. **Use four backticks as the fence** whenever the code contains three (Typst fixtures, Markdown fences, shell here-docs).

## Working loop

1. **Plan files and fragments**: files are `#file` roots, the narrative is the section structure. Need a new output file? Declare it — never create it by hand.
2. **Write prose, then code**, section by section.
3. **Check it tangles**: `lp tangle <doc.typ> --out <dir> --check` — dry run, exit 1 on drift, writes nothing.
4. **Stay in step while editing**: `lp watch <doc.typ> --out <dir> --check-cmd '<build>'`. Only changed bytes are rewritten (so build tools do not rebuild), a document that fails to evaluate is skipped, and diagnostics come back as chunk names.
5. **Read a diagnostic back**: `lp explain` (pipe `cargo build --message-format=short` or a Python traceback into it), or `lp map --file <generated> --line N`.
6. **Resolve strays** after deleting or renaming a root: `lp unaccounted <doc> --out <dir>`. Every file under `--out` must be produced by a chunk or declared in that directory's `.lpignore` (matching means *protect*), otherwise tangling fails. `lp` never deletes anything by itself; `lp unaccounted … --delete` is the explicit alternative.

## Find your way around (cheaper than grepping generated code)

| Question | Command |
| --- | --- |
| Which chunks exist, in what order, which are roots | `lp list <doc.typ>` |
| The declaration stream as Typst evaluated it | `lp metadata <doc.typ>` |
| Where line N of `src/main.rs` came from | `lp map --file src/main.rs --line N` |
| What generated lines chunk X produced | `lp map --typ X` |
| The declaration itself | `rg '#chunk\("X"'` |

Provenance is deliberately **chunk-level** — which declaration, and which line inside it — never a `.typ` line number (Typst does not expose source positions). To edit, go to the declaration the diagnostic names.

## Errors you will hit

| Message | Cause | Fix |
| --- | --- | --- |
| `chunk ⟪x⟫ is not defined` | a `<<x>>` line with no matching declaration | declare it, or fix the name |
| a reference cycle | chunks referencing each other | break the cycle: the narrative must be a DAG |
| `empty chunk` | a declaration with no lines | delete it or fill it |
| `no root chunks` | no `#file` in any document | add one |
| unaccounted / drift | files under `--out` nothing produces and no `.lpignore` covers | `lp unaccounted`, then declare or `--delete` |
| "the document did not evaluate" | a Typst error — unclosed fence, bad expression | fix the document; nothing was tangled |
| a literal `<<name>>` line in generated code turned into something else | that line was read as a reference | never let a line be *only* a reference unless you mean it; splice literals in the source instead |

## Anti-patterns

- Prose that restates the code ("this function adds two numbers"). It reads as literate and is not.
- Chunk-per-function, chunk-per-statement; a document that is really a tangle script with headings.
- Hand-editing tangled files, then being surprised by `--check`.
- Creating output files by hand instead of declaring them.
- Editing with `lp watch` running a build you then ignore: the diagnostics name chunks, and that is exactly the point.

## In this repository (`lp` itself is self-hosted)

`self.typ` is the source of this tool: it declares `Cargo.toml`, `src/*.rs` and `tests/*.rs`, and those files are generated (gitignored). To change the tool, change `self.typ`:

```sh
nix develop -c ./target/debug/lp tangle self.typ --out . --check   # the gate, always available
nix develop -c ./target/debug/lp watch self.typ --out . --check-cmd 'cargo build --message-format=short'
nix develop -c cargo test                                          # 48 tests, includes the self-reproduction test
```

A fresh clone has no `src/` at all: build the frozen seed in `bootstrap/`, then tangle (see `README.md` §自举). `tests/self.rs` fails if the sources on disk stop matching the document, so hand-editing `src/` cannot survive. Adding a new top-level directory to the repository means adding one line to the root `.lpignore` — otherwise the next `--check` refuses with "nothing accounts for these files" (`.pi`, `.agents`, `bootstrap`, `lit`, `examples`, `experiments` and friends are already declared there).

## References

- [`references/example.md`](references/example.md) — a complete two-file program, with the narrative decisions spelled out.
- [`references/thinking.md`](references/thinking.md) — when literate programming pays off, what it costs, and where the claims come from (Knuth, noweb, the critiques).
- Repository: `README.md` (full contract), `AGENTS.md` (project rules), `examples/demo/` (runnable end-to-end example), `agent-notes/decisions/` (why the tool works this way).
