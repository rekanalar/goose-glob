// The name match of the glob package. Pure Goose.
//
// The name match tests one name against one pattern. The rule is the rule
// of Python fnmatch: the whole name is one piece and a separator is an
// ordinary byte.
//
// The matcher never fails. A malformed pattern is a literal.

namespace glob;

import std;
import matcher;

// match_name returns true when the name matches the pattern.
//
// The whole name is one piece. A separator is an ordinary byte, so a star
// matches it and a question mark matches it.
//
// A group of alternatives matches either alternative. A backslash gives the
// next byte as a literal. A malformed pattern is a literal.
//
// It has no case folding. Use matches_fold for that.
fn match_name(name: u8[:], pattern: u8[:]) -> bool {
    // A pattern without a group has one alternative. It is itself.
    if find_group(pattern) < 0 { return match_segment(name, pattern); }
    let variants = expand(pattern);
    var start = 0;
    var i = 0;
    while i < variants.len {
        if variants[i] == 0 {
            let v = variants[start..i];
            if match_segment(name, v) { return true; }
            start = i + 1;
        }
        i += 1;
    }
    return false;
}
