use typst_syntax::{ast, LinkedNode, Source, SyntaxKind};

fn walk(n: &LinkedNode, src: &Source) {
    if let Some(raw) = n.get().cast::<ast::Raw>() {
        let label = n
            .next_sibling()
            .filter(|s| s.get().kind() == SyntaxKind::Label)
            .map(|s| s.get().leaf_text().trim().to_string());
        if raw.block() && label.is_some() {
            let r = n.range();
            let body: Vec<String> = raw.lines().map(|t| t.get().to_string()).collect();
            println!(
                "line {:>3} byte {:>4?} lang={:<6?} label={:<14}",
                src.lines().byte_to_line(r.start).unwrap() + 1,
                r,
                raw.lang().map(|l| l.get().to_string()),
                label.unwrap(),
            );
            println!("     {:?}", body.join("\n"));
        }
    }
    for c in n.children() {
        walk(&c, src);
    }
}

fn main() {
    let path = std::env::args().nth(1).unwrap();
    let text = std::fs::read_to_string(&path).unwrap();
    let src = Source::detached(text);
    walk(&LinkedNode::new(src.root()), &src);
}
