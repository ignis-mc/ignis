from ignis.leveldb.db import DB
from ignis.leveldb.options import Options
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.tempdir import remove_all, temp_dir


def _b(s: StringSlice) -> List[UInt8]:
    return List[UInt8](s.as_bytes())


def test_put_get_delete_reopen() raises:
    var dir = temp_dir("ldb")
    var db = DB(dir)
    db.put(Span(_b("a")), Span(_b("1")))
    db.put(Span(_b("b")), Span(_b("2")))
    db.put(Span(_b("a")), Span(_b("3")))
    db.delete(Span(_b("b")))
    assert_equal(db.get(Span(_b("a"))).value(), _b("3"))
    assert_false(Bool(db.get(Span(_b("b")))))
    _ = db^
    var db2 = DB(dir)
    assert_equal(db2.get(Span(_b("a"))).value(), _b("3"))
    assert_false(Bool(db2.get(Span(_b("b")))))
    var it = db2.new_iterator()
    var n = 0
    while it.next():
        n += 1
        assert_equal(List[UInt8](it.key()), _b("a"))
    assert_equal(n, 1)
    _ = db2^
    remove_all(dir)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
