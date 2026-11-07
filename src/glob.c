// The C part of the goose-glob package.
//
// The standard library has no call that tells a symbolic link from the
// thing it points to. The walk needs one, so that it follows no link.

#include "goose.h"

#include <stdint.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <sys/stat.h>
#endif

typedef struct { const uint8_t *data; int64_t len; } glob_slice;

// glob_is_symlink gives 1 when the path is a symbolic link. It gives 0
// for any other path, for a missing path and for a path that is too long.
int glob_is_symlink(glob_slice path) {
    char buf[4096];
    if (path.len <= 0 || path.len >= (int64_t)sizeof(buf)) return 0;
    memcpy(buf, path.data, (size_t)path.len);
    buf[path.len] = 0;
#ifdef _WIN32
    // The bytes of the path are UTF-8, as every path of Goose. The wide
    // calls of Windows take the path in UTF-16.
    wchar_t wide[4096];
    if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, buf, -1, wide, 4096) <= 0) return 0;
    WIN32_FIND_DATAW data;
    HANDLE h = FindFirstFileW(wide, &data);
    if (h == INVALID_HANDLE_VALUE) return 0;
    FindClose(h);
    if (!(data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT)) return 0;
    // Only a symbolic link is a link. A mount point and a cloud file
    // are reparse points of another kind.
    return data.dwReserved0 == IO_REPARSE_TAG_SYMLINK ? 1 : 0;
#else
    struct stat st;
    if (lstat(buf, &st) != 0) return 0;
    return S_ISLNK(st.st_mode) ? 1 : 0;
#endif
}
