// glob - glob pattern matching and path tools for Goose.
//
// The repository is goose-glob. The package name is what a program imports it
// by, so it is "glob". docs/packages.md, section 4: a package is a directory
// with an entry file named after the package. The entry file is glob.goose.
//
// Every file in this package declares "namespace glob;". A user calls
// glob::matches, glob::join, and so on.
namespace glob;

import std;
import paths;
import matcher;
import walk;
