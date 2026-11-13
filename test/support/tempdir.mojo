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
    """Copies the regular files of a directory (not recursive) into a new
    directory."""
    from ignis.internal.fs import read_file, write_file

    make_dir_all(dst)
    for name in list_dir(src):
        write_file(
            join(dst, name), Span(read_file(join(src, name))), sync=False
        )
