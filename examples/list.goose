// An example for the glob package.
//
// It creates a small tree of files, walks it, and prints the paths that
// match a pattern.
//
// Run with: goose run examples/list.goose

import std;
import glob from "..";

// path writes the parts of a path into a new string, separated by '/'.
fn path(parts: const u8[:][:]) -> u8[] {
    var out: u8[>..] = [];
    glob::join(out, parts);
    return out[..];
}

fn main() {
    let root = "glob-example";
    make_dir(root);
    make_dir(path(["glob-example", "src"]));
    make_dir(path(["glob-example", "src", "deep"]));
    make_dir(path(["glob-example", ".hidden"]));
    write_file(path(["glob-example", "main.goose"]), "// main\n");
    write_file(path(["glob-example", "notes.txt"]), "notes\n");
    write_file(path(["glob-example", "src", "app.goose"]), "// app\n");
    write_file(path(["glob-example", "src", "deep", "inner.goose"]), "// inner\n");
    write_file(path(["glob-example", ".hidden", "secret.goose"]), "// secret\n");

    print("--- pattern: **/*.goose");
    var found: u8[>..] = [];
    glob::walk(found, root, "**/*.goose");
    print(found);

    print("--- pattern: *.txt");
    var text: u8[>..] = [];
    glob::walk(text, root, "*.txt");
    print(text);

    print("--- matching one path");
    print(glob::matches("src/deep/inner.goose", "**/*.goose"));
    print(glob::matches("src/deep/inner.goose", "src/*.goose"));

    print("--- path helpers");
    print(path(["src", "deep", "inner.goose"]));
    print(glob::basename("src/deep/inner.goose"));
    print(glob::dirname("src/deep/inner.goose"));
    print(glob::ext("src/deep/inner.goose"));
    return 0;
}
