// An example for the glob package.
//
// It matches one name against a pattern, and it gives the parts of a
// match.
//
// Run with: goose run examples/name.goose

import std;
import glob from "..";

// show prints the parts of the match of the text against the pattern.
fn show(text: u8[:], pattern: u8[:]) {
    var out: u8[>..] = [];
    let count = glob::capture(out, text, pattern);
    print("count: ");
    print(count);
    print("part: ");
    print(out);
}

fn main() {
    print("--- match one name");
    print(glob::match_name("notes.txt", "*.txt"));
    print(glob::match_name("notes.md", "*.txt"));
    print(glob::match_name("report.txt", "re[po]*.txt"));

    print("--- parts of a match");
    show("src/app.goose", "src/*.goose");

    print("--- parts of a match with a class and a group");
    show("axb", "a[bx]b");
    show("app.md", "{a,b}*.md");

    print("--- a text that does not match");
    show("src/app.goose", "src/*.md");
    return 0;
}
