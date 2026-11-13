"""Temporary directories for tests that touch the file system."""

from ignis.internal.fs import list_dir, make_dir_all, remove, remove_dir, join
from nethernet.os.random import random_u64


def temp_dir(prefix: StringSlice) raises -> String:
    """Creates a fresh directory under `/tmp`."""
    var path = String("/tmp/ignis-test-", prefix, "-", random_u64())
    make_dir_all(path)
    return path^


def remove_all(path: StringSlice) raises:
    """Removes a directory tree created by a test (files and subdirectories)."""
    for name in list_dir(path):
        var p = join(path, name)
        try:
            remove(p)
        except:
            remove_all(p)
    remove_dir(path)


def copy_dir(src: StringSlice, dst: StringSlice) raises:
    """Copies a directory tree into a new directory."""
    from ignis.internal.fs import is_dir, read_file, write_file

    make_dir_all(dst)
    for name in list_dir(src):
        var p = join(src, name)
        if is_dir(p):
            copy_dir(p, join(dst, name))
        else:
            write_file(join(dst, name), Span(read_file(p)), sync=False)
