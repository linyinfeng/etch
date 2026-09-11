// Chunk rendering for literate Typst documents.
//
// Apply it with `#show: lit`. A fenced code block gets chunk treatment as soon
// as it carries a label (`<name>`); unlabelled blocks render normally.
//
// Known limit (ponytail): every `<<ref>>` line triggers a document-wide query,
// so weaving cost grows with chunks x references. Replace with a single
// precomputed index if a book-sized document ever gets slow to compile.

// A reference line is indentation + `<<name>>` (+ trailing space). That leading
// indentation is what the tangler copies onto every expanded line, so the weaver
// must show it: otherwise the document lies about the code it produces.
#let ref-re = regex("^(\\s*)<<([^<>]+)>>\\s*$")
#let chunk-label(it) = it.at("label", default: none)

/// The indentation a reference line contributes to the expanded chunk, or "" when
/// the line is not a reference. Exposed for the check in examples/demo/run.sh.
#let ref-indent(line) = {
  let m = line.match(ref-re)
  if m == none { "" } else { m.captures.at(0) }
}

#let ref-link(name) = context {
  let target = query(raw.where(block: true)).find(block => {
    let label = chunk-label(block)
    label != none and str(label) == name
  })
  if target == none {
    text(fill: red)[⟪#name⟫]
  } else {
    text(fill: rgb("#0a6"))[#link(target.location())[⟪#name⟫]]
  }
}

#let lit(body) = {
  show raw.where(block: true): it => {
    let label = chunk-label(it)
    if label == none { it } else {
      block(breakable: true, width: 100%, inset: 8pt, radius: 3pt, fill: luma(238))[
        #text(size: 0.85em, weight: "bold", fill: luma(60))[⟪#str(label)⟫]
        #h(0.6em)
        #text(size: 0.7em, fill: luma(120))[#it.lang]
        #v(4pt)
        #for line in it.lines {
          let m = line.text.match(ref-re)
          if m == none { line.body } else {
            raw(m.captures.at(0)) + ref-link(m.captures.at(1))
          }
          linebreak()
        }
      ]
    }
  }
  body
}
