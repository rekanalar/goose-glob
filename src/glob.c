// The C part of the goose-glob package.
//
// The standard library has no call that tells a symbolic link from the
// thing it points to. The walk needs one, so that it follows no link.

#include "goose.h"

#include <stdint.h>
#include <string.h>
#include <sys/stat.h>

typedef struct { const uint8_t *data; int64_t len; } glob_slice;

// glob_is_symlink gives 1 when the path is a symbolic link. It gives 0
// for any other path, for a missing path and for a path that is too long.
int glob_is_symlink(glob_slice path) {
    char buf[4096];
    if (path.len <= 0 || path.len >= (int64_t)sizeof(buf)) return 0;
    memcpy(buf, path.data, (size_t)path.len);
    buf[path.len] = 0;
    struct stat st;
    if (lstat(buf, &st) != 0) return 0;
    return S_ISLNK(st.st_mode) ? 1 : 0;
}
