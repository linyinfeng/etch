= How the tests are written

The chapters above make claims about behaviour; this is where the claims are pinned. The suite
runs the real binary against throwaway documents in temporary directories, because every
failure worth catching is at a seam — a document that does not evaluate, a file nothing
accounts for, a diagnostic that has to find its way back — and a unit test with a mock in the
middle would test the mock.

The shape is the same in every file: copy the package next to the fixture, write a document,
run `etch` with `current_dir` set to the temporary project, and assert on what came out. There is
no test framework beyond `#[test]`, and the assertions read as sentences because the names of
the cases do.

== The five files

Each file is a skeleton of its cases: the fixtures and helpers first, then one fragment per
case. That makes the file's shape the suite's table of contents, and it means a reader who is
looking for "where is that pinned?" can read the list of names instead of the whole file.

The five chapters after this one are those files, in the order the suite is listed in.
