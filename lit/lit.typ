// Chunk rendering for literate Typst documents.
//
// Apply it with `#show: lit`. A fenced code block gets chunk treatment as soon
// as it carries a label (`<name>`); unlabelled blocks render normally.
//
// Known limit (ponytail): every `<<ref>>` line triggers a document-wide query,
// so weaving cost grows with chunks x references. Replace with a single
// precomputed index if a book-sized document ever gets slow to compile.

#let ref-re = regex("^\\s*<<([^<>]+)>>\\s*$")
#let chunk-label(it) = it.at("label", default: none)

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
            raw(line.text.slice(0, m.start)) + ref-link(m.captures.at(0))
          }
          linebreak()
        }
      ]
    }
  }
  body
}
