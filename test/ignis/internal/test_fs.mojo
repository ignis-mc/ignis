from ignis.internal.fs import (
    is_dir,
    create,
    exists,
    join,
    list_dir,
    make_dir_all,
    open_append,
    open_read,
    read_file,
    remove,
    rename,
    sync_dir,
    write_file,
)
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)
from support.tempdir import remove_all, temp_dir


def test_write_read_rename_remove() raises:
    var dir = temp_dir("fs")
    var a = join(dir, "a.bin")
    write_file(a, Span([UInt8(1), 2, 3]), sync=True)
    var f = open_append(a)
    f.write_all(Span([UInt8(4), 5]))
    f.sync()
    _ = f^
    assert_equal(read_file(a), [UInt8(1), 2, 3, 4, 5])
    var r = open_read(a)
    assert_equal(r.size(), 5)
    var buf = List[UInt8]()
    assert_equal(r.read_at(buf, 3, 10), 2)
    assert_equal(buf, [UInt8(4), 5])
    var b = join(dir, "b.bin")
    rename(a, b)
    sync_dir(dir)
    assert_false(exists(a))
    assert_true(exists(b))
    assert_equal(list_dir(dir), [String("b.bin")])
    remove(b)
    assert_equal(len(list_dir(dir)), 0)
    with assert_raises(contains="errno 2"):
        _ = open_read(b)
    remove_all(dir)


def test_make_dir_all_and_many_entries() raises:
    var dir = temp_dir("fs")
    var deep = join(dir, "x/y/z")
    make_dir_all(deep)
    make_dir_all(deep)
    assert_true(exists(deep))
    for i in range(300):
        _ = create(join(deep, String("file-", i, ".txt")))
    assert_equal(len(list_dir(deep)), 300)
    remove_all(dir)
    assert_false(exists(dir))


def test_reading_a_directory_raises() raises:
    # Regression: read_file trusted lseek(SEEK_END), which reports a huge
    # size for directories, and aborted allocating it.
    var dir = temp_dir("fs")
    assert_true(is_dir(dir))
    assert_false(is_dir(join(dir, "missing")))
    with assert_raises(contains="errno 21"):
        _ = read_file(dir)
    var big = List[UInt8](length=200000, fill=7)
    write_file(join(dir, "big"), big, sync=False)
    assert_false(is_dir(join(dir, "big")))
    assert_true(read_file(join(dir, "big")) == big)
    remove_all(dir)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
