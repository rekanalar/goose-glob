// Pattern lists and case folding for the glob package. Pure Goose.
//
// A list holds one pattern per line. The lines are separated by '\n'.

namespace glob;

import std;
import matcher;

// lower_ascii writes s into out with A-Z changed to a-z.
fn lower_ascii(out: u8[>..]&, s: u8[:]) {
    var i = 0;
    while i < s.len {
        let c = s[i];
        if c >= 'A' && c <= 'Z' { out.push(c + 32); } else { out.push(c); }
        i += 1;
    }
}

// matches_fold is matches with no difference between the cases of the
// ASCII letters. A class such as [A-Z] still works, because the pattern
// folds in the same way.
fn matches_fold(path: u8[:], pattern: u8[:]) -> bool {
    var p: u8[>..] = [];
    var q: u8[>..] = [];
    lower_ascii(p, path);
    lower_ascii(q, pattern);
    return matches(p[0..p.len], q[0..q.len]);
}

// matches_any returns true when one pattern of the list matches the path.
// A line that starts with '!' counts as a plain pattern here. Use
// matches_set for the negation.
fn matches_any(path: u8[:], patterns: u8[:]) -> bool {
    var start = 0;
    var i = 0;
    while i <= patterns.len {
        if i == patterns.len || patterns[i] == '\n' {
            if i > start && matches(path, patterns[start..i]) { return true; }
            start = i + 1;
        }
        i += 1;
    }
    return false;
}

// matches_set tests the path against a list in which a line that starts
// with '!' removes the paths that it matches. The last line that matches
// decides, as in a .gitignore file. A list whose first line is a negation
// starts with every path in. This is the rule of the Node micromatch
// package for a negated pattern.
fn matches_set(path: u8[:], patterns: u8[:]) -> bool {
    var result = patterns.len > 0 && patterns[0] == '!';
    var start = 0;
    var i = 0;
    while i <= patterns.len {
        if i == patterns.len || patterns[i] == '\n' {
            if i > start {
                if patterns[start] == '!' {
                    if matches(path, patterns[start + 1..i]) { result = false; }
                } else if matches(path, patterns[start..i]) {
                    result = true;
                }
            }
            start = i + 1;
        }
        i += 1;
    }
    return result;
}
