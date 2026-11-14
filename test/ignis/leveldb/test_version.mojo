from ignis.internal.fs import join, write_file
from ignis.leveldb.compress import NO_COMPRESSION
from ignis.leveldb.key import KEY_TYPE_VAL, internal_key
from ignis.leveldb.session_record import AddedTable, SessionRecord
from ignis.leveldb.table import TableWriter
from ignis.leveldb.version import Version
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.tempdir import remove_all, temp_dir


def _write(dir: String, num: Int, lo: String, hi: String) raises -> AddedTable:
    var w = TableWriter(4096, 16, NO_COMPRESSION, 0)
    w.append(internal_key(lo.as_bytes(), 1, KEY_TYPE_VAL), "x".as_bytes())
    w.append(internal_key(hi.as_bytes(), 1, KEY_TYPE_VAL), "y".as_bytes())
    var imin = w.first_key()
    var imax = w.last_key()
    var data = w.finish()
    write_file(join(dir, String("00000", num, ".ldb")), data, sync=False)
    return AddedTable(0, num, len(data), imin^, imax^)


def test_apply_order_overlap_and_base_level() raises:
    var dir = temp_dir("version")
    var rec = SessionRecord()
    var a = _write(dir, 1, "a", "c")
    var b = _write(dir, 2, "b", "d")
    var c = _write(dir, 3, "m", "p")
    var d = _write(dir, 4, "e", "g")
    rec.added.append(a^)
    rec.added.append(b^)
    c.level = 1
    d.level = 1
    rec.added.append(c^)
    rec.added.append(d^)
    var v = Version()
    v.apply(rec, dir)
    # Level 0 is newest first, other levels sorted by key.
    assert_equal(v.levels[0][0].num, 2)
    assert_equal(v.levels[1][0].num, 4)
    assert_equal(v.table_count(), 4)
    assert_equal(len(v.overlapping(0, "c".as_bytes(), "c".as_bytes())), 2)
    assert_equal(len(v.overlapping(1, "h".as_bytes(), "l".as_bytes())), 0)
    assert_equal(v.overlapping(1, "a".as_bytes(), "n".as_bytes()), [0, 1])
    assert_false(v.base_level_for_key(0, "n".as_bytes()))
    assert_true(v.base_level_for_key(1, "n".as_bytes()))
    assert_true(v.base_level_for_key(0, "z".as_bytes()))
    var del_rec = SessionRecord()
    del_rec.deleted.append((1, 4))
    v.apply(del_rec, dir)
    assert_false(v.has_table(4))
    assert_true(v.level_size(1) > 0)
    remove_all(dir)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
