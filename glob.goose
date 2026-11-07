// glob - glob pattern matching and path tools for Goose.
//
// The repository is goose-glob. The package name is what a program imports
// it by, so the name is "glob".
//
// docs/packages.md, section 4: a package is a directory. It has an entry
// file named after the package. The entry file is glob.goose.
//
// Every file in this package declares "namespace glob;". A user calls
// glob::matches. A user calls glob::join.
namespace glob;

import std;
import paths;
import matcher;
import walk;
import sets;
