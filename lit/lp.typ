// lp.typ — declare chunks for the `lp` tool.
//
// A chunk is written by calling `chunk` (a fragment, referenced as <<name>>) or
// `file` (a chunk whose name is the output path, i.e. a root). The code block is
// passed as the argument, so the declaration carries everything the tool needs —
// name, language, text — and the tool never has to read the source to find out
// what a chunk is.
//
//   #import "lp.typ": chunk, file
//
//   #chunk("imports", ```rust
//   use std::fmt;
//   ```)
//
//   #file("src/main.rs", ```rust
//   <<imports>>
//   ```)
//
// Rendering lives here too, so the document does not need show rules: a chunk
// shows up as a titled block with its references marked.

// A reference line is indentation + <<name>>. The indentation is part of what a
// reference *means*: it decides how the expanded chunk is laid out when tangled,
// so the woven page has to show it — otherwise the document lies about the code.
#let ref-re = regex("^(\\s*)<<([^<>]+)>>\\s*$")

/// The indentation a reference line contributes to the expanded chunk, or "" when
/// the line is not a reference. The renderer below uses it too, so this is the
/// implementation rather than a helper kept alive for a test.
#let ref-indent(line) = {
  let m = line.match(ref-re)
  if m == none { "" } else { m.captures.at(0) }
}

/// Ref marking is cosmetics, so a show rule is fine here — the *declarations*
/// below carry the semantics, and they do not depend on any show rule running.
#let rule(body) = {
  show raw.where(block: true): it => {
    let out = none
    for line in it.lines {
      let m = line.text.match(ref-re)
      let piece = if m == none {
        line.body
      } else {
        raw(ref-indent(line.text)) + text(fill: rgb("#0a6"))[⟪#m.captures.at(1)⟫]
      }
      out = if out == none { piece + linebreak() } else { out + piece + linebreak() }
    }
    out
  }
  body
}

#let tile(name, lang, code) = block(
  breakable: true,
  width: 100%,
  inset: 8pt,
  radius: 3pt,
  fill: luma(238),
)[
  #text(size: 0.85em, weight: "bold", fill: luma(60))[⟪#name⟫]
  #h(0.6em)
  #text(size: 0.7em, fill: luma(120))[#lang]
  #v(4pt)
  #code
]

/// A named fragment: referenced as `<<name>>`, written nowhere on its own.
#let chunk(name, code) = {
  [#metadata((lp: "chunk", name: name, lang: code.lang, text: code.text))<lp-decl>]
  tile(name, code.lang, code)
}

/// A root chunk: the name is the path it is tangled to.
#let file(path, code) = {
  [#metadata((lp: "file", name: path, lang: code.lang, text: code.text))<lp-decl>]
  tile(path, code.lang, code)
}
