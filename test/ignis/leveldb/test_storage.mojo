from ignis.internal.fs import join, read_file, write_file
from ignis.leveldb.storage import (
    TYPE_JOURNAL,
    TYPE_MANIFEST,
    TYPE_TABLE,
    TYPE_TEMP,
    FileDesc,
    file_name,
    get_meta,
    parse_file_name,
    set_meta,
    table_path,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.tempdir import remove_all, temp_dir


def test_names() raises:
    assert_equal(file_name(FileDesc(TYPE_MANIFEST, 3)), "MANIFEST-000003")
    assert_equal(file_name(FileDesc(TYPE_JOURNAL, 12)), "000012.log")
    assert_equal(file_name(FileDesc(TYPE_TABLE, 1234567)), "1234567.ldb")
    assert_equal(file_name(FileDesc(TYPE_TEMP, 0)), "000000.tmp")
    assert_true(
        parse_file_name("000005.sst").value() == FileDesc(TYPE_TABLE, 5)
    )
    assert_true(
        parse_file_name("MANIFEST-000009").value() == FileDesc(TYPE_MANIFEST, 9)
    )
    assert_true(parse_file_name("42.log").value() == FileDesc(TYPE_JOURNAL, 42))
    assert_false(Bool(parse_file_name("CURRENT")))
    assert_false(Bool(parse_file_name("LOCK")))
    assert_false(Bool(parse_file_name("000001.txt")))


def test_current_pointer() raises:
    var dir = temp_dir("storage")
    assert_false(Bool(get_meta(dir)))
    write_file(join(dir, "MANIFEST-000002"), List[UInt8](), sync=False)
    set_meta(dir, FileDesc(TYPE_MANIFEST, 2))
    assert_equal(
        String(from_utf8=read_file(join(dir, "CURRENT"))), "MANIFEST-000002\n"
    )
    assert_equal(get_meta(dir).value().num, 2)
    write_file(join(dir, "MANIFEST-000007"), List[UInt8](), sync=False)
    set_meta(dir, FileDesc(TYPE_MANIFEST, 7))
    assert_equal(
        String(from_utf8=read_file(join(dir, "CURRENT.bak"))),
        "MANIFEST-000002\n",
    )
    assert_equal(get_meta(dir).value().num, 7)
    # A corrupt CURRENT falls back to CURRENT.bak (goleveldb GetMeta).
    write_file(join(dir, "CURRENT"), "MANIFEST-0000".as_bytes(), sync=False)
    assert_equal(get_meta(dir).value().num, 2)
    # A pending CURRENT.<n> wins.
    write_file(
        join(dir, "CURRENT.7"), "MANIFEST-000007\n".as_bytes(), sync=False
    )
    assert_equal(get_meta(dir).value().num, 7)
    # Old .sst names are found.
    write_file(join(dir, "000009.sst"), List[UInt8](), sync=False)
    assert_true(table_path(dir, 9).endswith("000009.sst"))
    assert_true(table_path(dir, 10).endswith("000010.ldb"))
    remove_all(dir)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
