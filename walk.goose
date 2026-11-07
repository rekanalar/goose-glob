// The directory walk for the glob package. Pure Goose. No C.
//
// The walk uses the standard library "os" module. It reads a directory.
// It keeps the names that match the pattern.
//
// The walk is recursive. Goose does not allow a growable value to be live
// across a recursive call (docs/reference.md, section 19). The walk keeps
// its two buffers outside the recursive function. It passes them in.
//
// The buffers are grow-only. A slice into one stays valid when it grows.

namespace glob;

import std;
import os;
import matcher;

extern fn glob_is_symlink(path: const u8[:]) -> bool;

// walk writes the paths under dir that match pattern into out. The paths
// are relative to the current directory. They use '/' as the separator.
//
// The walk descends depth first. The names of a directory come sorted, so
// the files of a directory come out in name order.
//
// The walk skips directories with a dot prefix. It follows no symbolic
// link to a directory, as Go's WalkDir and Python's Path.walk do not.
// It still reports a link to a file as a file.
fn walk(out: u8[>..]&, dir: u8[:], pattern: u8[:]) {
    var names: u8[>..] = [];
    var path: u8[>..] = [];
    path.append(dir);
    // The paths in the result are relative to dir. They start after the
    // directory name and its separator.
    var skip = dir.len;
    if skip > 0 { skip += 1; }
    walk_dir(out, names, path, pattern, skip, 0);
}

// OPT_HIDDEN makes the walk enter and report names with a dot prefix.
// OPT_KINDS puts a kind and a tab before each path: d for a directory,
// l for a link to a directory and f for any other file. It also reports
// the directories that match.
const OPT_HIDDEN = 1;
const OPT_KINDS = 2;

// walk_with is walk with the options OPT_HIDDEN and OPT_KINDS, joined
// with |. It gives the kind of each path, as Go's WalkDir does.
fn walk_with(out: u8[>..]&, dir: u8[:], pattern: u8[:], opts: i64) {
    var names: u8[>..] = [];
    var path: u8[>..] = [];
    path.append(dir);
    var skip = dir.len;
    if skip > 0 { skip += 1; }
    walk_dir(out, names, path, pattern, skip, opts);
}

// emit writes one result line.
fn emit(out: u8[>..]&, kind: u8, rel: u8[:], opts: i64) {
    if out.len > 0 { out.push('\n'); }
    if opts & OPT_KINDS != 0 { out.push(kind); out.push('\t'); }
    out.append(rel);
}

// walk_dir is the recursive part of the walk.
//
// The names buffer holds the directory listings. The path buffer holds the
// path of the directory that the walk reads. A child appends its name to
// the path buffer. It removes the name when it returns.
recursive fn walk_dir(out: u8[>..]&, names: u8[>..]&, path: u8[>..]&, pattern: u8[:], skip: i64, opts: i64) {
    let first = names.len;
    list_dir(path, names);
    let last = names.len;

    var i = first;
    while i < last {
        var j = i;
        while j < last && names[j] != '\n' { j += 1; }
        if j > i {
            let name = names[i..j];
            if name[0] != '.' || opts & OPT_HIDDEN != 0 {
                let mark = path.len;
                if mark > 0 { path.push('/'); }
                path.append(name);
                let is_directory = {
                    let p = path[0..path.len];
                    is_dir(p)
                };
                let link = glob_is_symlink(path[0..path.len]);
                let rel = path[skip..path.len];
                if is_directory && !link {
                    if opts & OPT_KINDS != 0 && matches(rel, pattern) { emit(out, 'd', rel, opts); }
                    walk_dir(out, names, path, pattern, skip, opts);
                } else if matches(rel, pattern) {
                    emit(out, if is_directory { 'l' } else { 'f' }, rel, opts);
                }
                path.pop_n(path.len - mark);
            }
        }
        i = j + 1;
    }
}
