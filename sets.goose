// Pattern lists and case folding for the glob package. Pure Goose.
//
// A list holds one pattern per line. The lines are separated by '\n'.

namespace glob;

import std;
import matcher;
import fold_data;

// fold_cp gives the simple case fold of a code point, found by binary search.
fn fold_cp(cp: i64) -> i64 {
    var lo: i64 = 0;
    var hi: i64 = FOLD_COUNT;
    while lo < hi {
        let mid = (lo + hi) / 2;
        if FOLD_FROM[mid] < cp { lo = mid + 1; } else { hi = mid; }
    }
    if lo < FOLD_COUNT && FOLD_FROM[lo] == cp { return FOLD_TO[lo]; }
    return cp;
}

// put_cp writes the code point as UTF-8.
fn put_cp(out: u8[>..]&, cp: i64) {
    if cp < 0x80 { out.push(cp as u8); }
    else if cp < 0x800 { out.push((0xC0 | (cp >> 6)) as u8); out.push((0x80 | (cp & 63)) as u8); }
    else if cp < 0x10000 {
        out.push((0xE0 | (cp >> 12)) as u8);
        out.push((0x80 | ((cp >> 6) & 63)) as u8);
        out.push((0x80 | (cp & 63)) as u8);
    } else {
        out.push((0xF0 | (cp >> 18)) as u8);
        out.push((0x80 | ((cp >> 12) & 63)) as u8);
        out.push((0x80 | ((cp >> 6) & 63)) as u8);
        out.push((0x80 | (cp & 63)) as u8);
    }
}

// fold_text writes s into out with each code point folded. A byte that is
// not part of a valid UTF-8 sequence stays as it is.
fn fold_text(out: u8[>..]&, s: u8[:]) {
    var i = 0;
    while i < s.len {
        let c = s[i] as i64;
        var n = 0;
        var cp = c;
        if c >= 0xF0 && c < 0xF5 { n = 3; cp = c & 7; }
        else if c >= 0xE0 && c < 0xF0 { n = 2; cp = c & 15; }
        else if c >= 0xC2 && c < 0xE0 { n = 1; cp = c & 31; }
        var ok = (n > 0 && i + n < s.len) || c < 0x80;
        var k = 1;
        while ok && k <= n {
            let b = s[i + k] as i64;
            if (b & 0xC0) != 0x80 { ok = false; } else { cp = (cp << 6) | (b & 63); }
            k += 1;
        }
        if !ok {
            out.push(s[i]);
            i += 1;
        } else {
            put_cp(out, fold_cp(cp));
            i += n + 1;
        }
    }
}

// matches_fold is matches with no difference between the cases. Both texts
// fold by the simple case fold of Unicode, so a class such as [A-Z] still
// works, because the pattern folds in the same way.
fn matches_fold(path: u8[:], pattern: u8[:]) -> bool {
    var p: u8[>..] = [];
    var q: u8[>..] = [];
    fold_text(p, path);
    fold_text(q, pattern);
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
