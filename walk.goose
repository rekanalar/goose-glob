// The directory walk for the glob package. Pure Goose. No C.
//
// The walk uses the standard library "os" module. It reads a directory,
// takes the names it finds, and keeps the ones that match the pattern.
//
// The walk is recursive. Goose does not allow a growable value to be live
// across a recursive call (docs/reference.md, section 19). The walk keeps
// its two buffers outside the recursive function and passes them in. The
// buffers are grow-only, so a slice into one stays valid when it grows.

namespace glob;

import std;
import os;
import matcher;

// walk writes the paths under dir that match pattern into out. The paths
// are relative to the current directory. They use '/' as the separator.
//
// The walk descends depth first. The names of a directory come sorted, so
// the files of a directory come out in name order.
//
// The walk skips directories with a dot prefix.
fn walk(out: u8[>..]&, dir: u8[:], pattern: u8[:]) {
    var names: u8[>..] = [];
    var path: u8[>..] = [];
    path.append(dir);
    // The paths in the result are relative to dir. They start after the
    // directory name and its separator.
    var skip = dir.len;
    if skip > 0 { skip += 1; }
    walk_dir(out, names, path, pattern, skip);
}

// walk_dir is the recursive part of the walk.
//
// The names buffer holds the directory listings. The path buffer holds the
// path of the directory that is being read. A child appends its name to
// the path buffer and removes it again when it returns.
recursive fn walk_dir(out: u8[>..]&, names: u8[>..]&, path: u8[>..]&, pattern: u8[:], skip: i64) {
    let first = names.len;
    list_dir(path, names);
    let last = names.len;

    var i = first;
    while i < last {
        var j = i;
        while j < last && names[j] != '\n' { j += 1; }
        if j > i {
            let name = names[i..j];
            if name[0] != '.' {
                let mark = path.len;
                if mark > 0 { path.push('/'); }
                path.append(name);
                let is_directory = {
                    let p = path[0..path.len];
                    is_dir(p)
                };
                if is_directory {
                    walk_dir(out, names, path, pattern, skip);
                } else {
                    let rel = path[skip..path.len];
                    if matches(rel, pattern) {
                        if out.len > 0 { out.push('\n'); }
                        out.append(rel);
                    }
                }
                path.pop_n(path.len - mark);
            }
        }
        i = j + 1;
    }
}
