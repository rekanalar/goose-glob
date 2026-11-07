// Tests for the glob package. Run with: goose run test/run.goose
//
// Every assert here is one acceptance scenario from the spec. A failed
// assert names its line, so the failure is the report.

import std;
import glob from "..";

fn test_star() {
    assert(glob::matches("main.goose", "*.goose"));
    assert(!glob::matches("main.g", "*.goose"));
    assert(!glob::matches("dir/main.goose", "*.goose"));
    assert(glob::matches("", "*"));
    assert(glob::matches("a", "*"));
}

fn test_question_mark() {
    assert(glob::matches("data1.csv", "data?.csv"));
    assert(!glob::matches("data12.csv", "data?.csv"));
    assert(!glob::matches("data.csv", "data?.csv"));
    // '?' never matches a separator.
    assert(!glob::matches("a/b", "a?b"));
}

fn test_class() {
    assert(glob::matches("b3.md", "[a-c][0-9].md"));
    assert(!glob::matches("d3.md", "[a-c][0-9].md"));
    assert(glob::matches("a3.md", "[a-c][0-9].md"));
    // A negated class.
    assert(!glob::matches("a.md", "[!a-c].md"));
    assert(glob::matches("d.md", "[!a-c].md"));
    // A range.
    assert(glob::matches("q.txt", "[p-r].txt"));
    assert(!glob::matches("s.txt", "[p-r].txt"));
    // A literal star inside a class.
    assert(glob::matches("*.txt", "[*].txt"));
    // A class never matches a separator.
    assert(!glob::matches("a/b", "[a/b]"));
}

fn test_double_star() {
    assert(glob::matches("src/a/b/c.goose", "src/**/*.goose"));
    // "**" matches zero segments too.
    assert(glob::matches("src/c.goose", "src/**/*.goose"));
    assert(glob::matches("c.goose", "**/*.goose"));
    assert(glob::matches("a/b", "**"));
    assert(glob::matches("a/b/c", "a/**"));
    // "*" matches any bytes, but never a separator.
    assert(glob::matches("a/b", "a/*"));
    assert(!glob::matches("a/b/c", "a/*"));
    // "**" crosses a separator where "*" does not.
    assert(glob::matches("a/b/c", "a/**"));
}

fn test_braces() {
    assert(glob::matches("ax/main.goose", "{a,b}?/*.goose"));
    assert(glob::matches("bb/x.goose", "{a,b}?/*.goose"));
    assert(!glob::matches("cx/x.goose", "{a,b}?/*.goose"));
    // A group with one alternative.
    assert(glob::matches("main.goose", "{main}.goose"));
    // Nested groups.
    assert(glob::matches("b.goose", "{a,{b,c}}.goose"));
    assert(glob::matches("c.goose", "{a,{b,c}}.goose"));
    assert(!glob::matches("d.goose", "{a,{b,c}}.goose"));
}

fn test_edges() {
    // An empty pattern matches only the empty path.
    assert(glob::matches("", ""));
    assert(!glob::matches("a", ""));
    // A pattern with a trailing separator never matches.
    assert(!glob::matches("a/b", "a/"));
    // An unterminated class is a literal. A class holds a '-' at its end
    // as a member, as bash does.
    assert(glob::matches("[abc", "[abc"));
    assert(glob::matches("a", "[a-]"));
    assert(glob::matches("-", "[a-]"));
    assert(!glob::matches("[a-]", "[a-]"));
    // An unclosed group is a literal.
    assert(glob::matches("{a,b", "{a,b"));
}

fn test_join() {
    var out: u8[>..] = [];
    glob::join2(out, "src", "main.goose");
    assert(out == "src/main.goose");

    var out2: u8[>..] = [];
    glob::join3(out2, "a", "b", "c.goose");
    assert(out2 == "a/b/c.goose");

    // An empty part is skipped.
    var out3: u8[>..] = [];
    glob::join2(out3, "src", "");
    assert(out3 == "src");
}

fn test_split() {
    let parts = glob::split("a//b/");
    assert(parts.len == 2);
    assert(parts[0] == "a");
    assert(parts[1] == "b");

    let one = glob::split("file");
    assert(one.len == 1);
    assert(one[0] == "file");

    let none = glob::split("");
    assert(none.len == 0);
}

fn test_basename_dirname() {
    assert(glob::basename("a/b/c.goose") == "c.goose");
    assert(glob::basename("a/b/") == "b");
    assert(glob::basename("file") == "file");
    assert(glob::dirname("a/b") == "a");
    assert(glob::dirname("file") == "");
    assert(glob::dirname("a/b/c.goose") == "a/b");
}

fn test_ext() {
    assert(glob::ext("a.tar.gz") == ".gz");
    assert(glob::ext("noext") == "");
    assert(glob::ext("dir/file.goose") == ".goose");
    // A leading dot is a name, not an extension.
    assert(glob::ext(".hidden") == "");
}

fn test_normalize() {
    var out: u8[>..] = [];
    glob::normalize(out, "a/./b/../c");
    assert(out == "a/c");

    var out2: u8[>..] = [];
    glob::normalize(out2, "a/b/c");
    assert(out2 == "a/b/c");

    var out3: u8[>..] = [];
    glob::normalize(out3, "./a");
    assert(out3 == "a");
}

// test_walk checks the walk against a tree that the test makes.
fn test_walk() {
    let root = "glob-test-tree";
    make_dir(root);
    var sub: u8[>..] = [];
    glob::join2(sub, root, "sub");
    make_dir(sub);
    var a: u8[>..] = [];
    glob::join2(a, root, "a.goose");
    write_file(a, "");
    var b: u8[>..] = [];
    glob::join2(b, root, "b.txt");
    write_file(b, "");
    var c: u8[>..] = [];
    glob::join2(c, sub, "c.goose");
    write_file(c, "");

    var found: u8[>..] = [];
    glob::walk(found, root, "**/*.goose");
    // The paths are relative to the root, in name order.
    assert(found == "a.goose\nsub/c.goose");

    var none: u8[>..] = [];
    glob::walk(none, root, "*.md");
    assert(none.len == 0);

    var kinds: u8[>..] = [];
    glob::walk_with(kinds, root, "**", 2);
    assert(kinds == "f\ta.goose\nf\tb.txt\nd\tsub\nf\tsub/c.goose");

    var dot: u8[>..] = [];
    glob::join2(dot, root, ".hid");
    write_file(dot, "");
    var plain: u8[>..] = [];
    glob::walk(plain, root, "*");
    assert(plain == "a.goose\nb.txt");
    var shown: u8[>..] = [];
    glob::walk_with(shown, root, ".*", 1);
    assert(shown == ".hid");

    // test/tree holds a link to its own directory. The walk must not loop.
    var looped: u8[>..] = [];
    glob::walk(looped, "test/tree", "**/*.txt");
    assert(looped == "one.txt");
}

// test_sets checks the lists and the case fold.
fn test_sets() {
    assert(glob::matches_fold("README.MD", "*.md"));
    assert(glob::matches_fold("Src/A.go", "src/[A-Z].GO"));
    assert(!glob::matches("README.MD", "*.md"));
    assert(glob::matches_any("a.go", "*.md\n*.go"));
    assert(!glob::matches_any("a.rs", "*.md\n*.go"));
    assert(glob::matches_set("a.md", "!*.js"));
    assert(!glob::matches_set("a.js", "!*.js"));
    assert(glob::matches_set("a.js", "*.js\n!b.js") == true);
    assert(!glob::matches_set("b.js", "*.js\n!b.js"));
    assert(!glob::matches_set("a.js", ""));
}

// test_limits checks the limits against a hostile pattern.
fn test_limits() {
    // A pattern with many groups does not expand. It stays one pattern.
    var pat: u8[>..] = [];
    for i in 0..30 { pat.append("{a,b}"); }
    assert(!glob::matches("x", pat));
    assert(!glob::matches("a", pat));

    // A pattern with many stars does not take a long time.
    var stars: u8[>..] = [];
    for i in 0..20 { stars.append("*a"); }
    stars.append("b");
    var path: u8[>..] = [];
    for i in 0..20 { path.append("a"); }
    assert(!glob::matches(path, stars));
}

fn main() {
    test_star();
    test_question_mark();
    test_class();
    test_double_star();
    test_braces();
    test_edges();
    test_join();
    test_split();
    test_basename_dirname();
    test_ext();
    test_normalize();
    test_walk();
    test_sets();
    test_limits();
    print("all tests passed");
    return 0;
}
