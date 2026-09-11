---
name: literate-programming
description: Write a program as an exposition - one Typst document whose subject is the thinking (the problem, the alternatives, the choice and why), with the code quoted in as the evidence that makes it checkable and tangled out of it into real source files and a woven PDF. Use when writing or editing any program lp carries (including this repository's own lp.typ), adding or reorganising chunks, or asked to write a literate document. Reading front to back has to go from idea to detail; the tool checks only the mechanism, so the thinking is the writer's job.
---

# Literate programming

Literate means the document is **about the thinking**. A literate program is an exposition — what the problem is, what was tried, what was chosen and why — and the code is the evidence that makes those decisions run. The code is quoted *into* the argument; it is never the subject of it.

One source, two products: **tangle** (the machine's copy: real source files) and **weave** (the reader's copy: a typeset document). Neither is the original; the exposition is.

So the question is never "what code goes here" but "what am I saying here, and what does it need to show". Read front to back, the document has to be **progressive disclosure**: each section states its thought, and the ones that follow take it further. A reader who has to jump around, or who meets a detail before the idea that made it necessary, is reading a document that was not finished.

## The discipline: the thinking is the subject

`lp` can check the mechanism (table below). It cannot read. The part that matters is on you:

1. **Every section is a claim.** Be able to say it in one sentence before you write the section. If you cannot, it is not a thought yet — it is a place to put code.
2. **The code is evidence, never the subject.** It appears so the reader can check the claim, not so the file can exist. A chunk written because "the file needs it" means the idea that needs it has not been written down.
3. **Write the why: the constraint, the alternative, and the moment of choice.** A reader can reconstruct what the code does; they cannot reconstruct what you rejected, or why the obvious design was wrong. That part exists only if you write it.
4. **Prose the thinking; captions are not prose.** "An operator consumes the two numbers produced before it" is a thought. "We call `pop` twice" is a caption for code, and captions belong in code.
5. **Name ideas, not implementations.** `<<apply one token>>` is a step in an argument; `<<pop two operands>>` is an implementation detail. When a name could be a function name, the idea above it is missing.
6. **One idea per paragraph, one promise per chunk.** A body keeps exactly the promise its name made: not more, not less, and not something the prose described differently. One name per concept, in the prose and in the chunks alike.
7. **Say what is not true yet.** Limits, planned work, trade-offs taken, the case the code does not handle: put them where the reader meets them.
8. **Revise the thinking first, and read for it before saying done.** When the design changes the opening is what goes stale; and the last pass is reading the exposition front to back — can someone rebuild the design from the reasoning? — not reviewing the diff. Then run the checks.

The failure mode to avoid is prose that *sounds* explained. A confident paragraph that does not match its chunk is worse than no paragraph: it stops the next reader — human or agent — from looking at the code.

## What the tool enforces (it will refuse these)

| Invariant | Message |
| --- | --- |
| Every reference resolves; no cycles; no empty bodies | `chunk ⟪x⟫ is not defined` / `cycle in chunks:` / `chunk ⟪x⟫ is empty` |
| Every file under `--out` is produced by a chunk or declared | `nothing accounts for these files` |
| The generated files still equal the document | `--check` prints `STALE` |

That is the whole list, and it is deliberately about *mechanism*: the tool can tell that a reference points at something and that the output still matches the text. It cannot tell whether a section states a thought, whether the order suits a reader, or whether the prose is true — mechanism is all it knows (see below).

## The shape: a file is the list of thoughts the reader already has

When the ideas come first, the file's shape falls out of them. A root chunk (`#file`) is a skeleton — a few lines that name the parts; fragments (`#chunk`) are those parts, each explained in the section that belongs to it. Depth is whatever the explanation needs: a step can itself be a skeleton of steps.

The line between a skeleton and a dump is the line between ideas: if you cannot say what a fragment is *for* in the argument, it is too small, or not yet thought through.

````
#file("src/calc.py", ```python
"""An RPN calculator: `calc.py "2 3 + 4 *"` prints 20.0."""

<<imports>>

<<the operation table>>


def evaluate(tokens):
    <<the evaluation loop>>
<<the command line>>
```)
````

Everything above is a promise. Later sections keep them, one at a time:

````
#chunk("the evaluation loop", ```python
stack = []
for token in tokens:
    <<apply one token>>
return stack.pop()
```)
````

Two things this buys: a reader can stop at any level and still have a true account of the program, and every name in the text has exactly one place where it is filled in.

**The order of the declarations is free, and it is an editorial decision.** Two shapes both work, and the argument decides which one the reader wants:

- *Skeleton first* (what the example does): show the files, then fill them in section by section. The reader knows the shape from the first page.
- *Pieces first, assembly last*: explain the important idea and build its fragments as the text goes, then assemble them into files in a short final section. The reader meets each idea where it is worth explaining, and sees the whole only when they can appreciate it.

Neither is more literate than the other. What is *not* a matter of taste is that the prose must say which one it is doing: if files appear at the end, the opening has to promise that.

## Mechanics

- `#file(path, code)` — a root chunk. Its name is the path it tangles to; every produced file needs one, and nothing else produces files.
- `#chunk(name, code)` — a fragment, existing only where something refers to it.
- `<<name>>` **alone on its line** is a reference; anywhere else (`a << b`) it stays literal text.
- **Indentation comes from the reference line**, not the chunk's own text: write chunk bodies flush left and let the reference place them. Nested references compose, so a body pulled in at four spaces and pulled in again at four more lands at eight.
- A repeated name **concatenates in document order** — a file can be introduced where its interface belongs and finished where its behaviour belongs. Nothing is inherited between the pieces: blank lines at the top of a later piece are part of what it contributes.
- The fence's language tag is data (the tangled file's language, and the input to the language check). Nothing in `lp` parses it.
- **To quote the syntax itself, escape it**: a line `@<<name>>` tangles out as `<<name>>` — the `@` is dropped and the line is never expanded, never counted as a reference. That is how a document can show what a reference looks like (this file is carried by `lp.typ` and does exactly that).
- Block content is verbatim: keep it flush left, and **use four backticks as the fence** whenever the code contains three (Typst fixtures, Markdown fences, heredocs).
- Keep the document evaluable at every save; a document Typst cannot evaluate tangles nothing, and `lp watch` keeps the last good output instead of half of a new one.

## Working loop

1. **Outline the argument first**: sections in reading order, each one a step from idea to detail.
2. **Write the skeleton** (the root chunks), naming parts the reader will meet later.
3. **Keep the promises** in the sections that follow — prose, then the chunk.
4. `lp tangle <doc.typ> --out <dir> --check` — dry run, exit 1 on drift.
5. `lp watch <doc.typ> --out <dir> --check-cmd '<build>'` — only changed bytes are rewritten, and diagnostics come back as chunk names.
6. `lp explain` (pipe `cargo build --message-format=short` into it) or `lp map --file <generated> --line N` to find the chunk a diagnostic came from. `--out` has to be repeated on `map`, `explain` and `unaccounted`; they default to `out`.
7. **Resolve strays** after deleting or renaming a root: `lp unaccounted <doc> --out <dir>`. Declare what is not the document's in that directory's `.lpignore` (matching means *protect*, and it includes anything the program writes next to its own output, like a byte-compiler cache); `lp unaccounted … --delete` is the explicit alternative. `lp` never deletes by itself.

## Find your way around

| Question | Command |
| --- | --- |
| Which chunks exist, in what order, which are roots | `lp list <doc.typ>` |
| The declaration stream as Typst evaluated it (also the reading order) | `lp metadata <doc.typ>` |
| Where line N of `src/main.rs` came from | `lp map --file src/main.rs --line N` |
| What generated lines a chunk produced | `lp map --typ X` |
| The declaration itself | `rg '#chunk\("X"'` |

Provenance is chunk-level on purpose — which declaration, and which line inside it — never a `.typ` line number (Typst does not expose source positions). To edit, go to the declaration the diagnostic names.

## Errors you will hit

| Message | Cause | Fix |
| --- | --- | --- |
| `chunk ⟪x⟫ is not defined` | a reference to nothing | declare it, or fix the typo |
| `cycle in chunks:` | fragments referencing each other | break the cycle; an article is a DAG |
| `chunk ⟪x⟫ is empty` | a declaration with no body | delete it or fill it |
| `nothing accounts for these files` | files under `--out` that no chunk produces and no `.lpignore` declares | declare them, or `--delete` |
| "the document did not evaluate" | a Typst error — unclosed fence, bad expression | fix the document; nothing was tangled |
| a literal `<<name>>` line came out as something else | that line was read as a reference | write `@<<name>>` where the text itself is wanted |

## Anti-patterns

- Prose that restates the code ("this function adds two numbers"). It looks literate and is not.
- Details before names — the tool rejects it, and it is the same mistake the rule is there to prevent.
- A chunk per statement; five-line chunks with no narrative; a document that is a tangle script with headings.
- Hand-editing tangled files, or creating an output file by hand instead of declaring it.
- A first section that describes the design you had an hour ago.

## In this repository (`lp` is self-hosted)

`lp.typ` is the source of the tool: it declares `Cargo.toml`, `src/*.rs`, `tests/*.rs` and this skill, all of which are generated (gitignored). Change the tool by changing `lp.typ`:

```sh
nix develop -c ./target/debug/lp tangle lp.typ --out . --check   # the gate
nix develop -c ./target/debug/lp watch lp.typ --out . --check-cmd 'cargo build --message-format=short'
nix develop -c cargo test                                          # 49 tests, includes self-reproduction
```

A fresh clone has no `src/`: build the frozen seed in `seed/`, then tangle (see `README.md` §自举). `tests/self.rs` fails if the files on disk stop matching the document, so hand-editing `src/` cannot survive. Adding a top-level directory means adding one line to the root `.lpignore`.

## References

- [`references/example.md`](references/example.md) — a complete two-file program in the skeleton shape, with a real transcript.
- [`references/thinking.md`](references/thinking.md) — where this stance comes from (Knuth's argument, noweb's simplifications), and the strongest objections to it, honestly stated.
- Repository: `README.md` (full contract), `AGENTS.md` (project rules), `examples/demo/` (runnable example), `agent-notes/decisions/2026-09-11-document-invariants.md` (the enforced invariants).
