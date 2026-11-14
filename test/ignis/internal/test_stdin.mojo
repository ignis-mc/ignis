from ignis.internal.stdin import LineReader, close_fd, pipe, write_fd
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_lines_across_reads() raises:
    var p = pipe()
    var r = LineReader(p[0])
    write_fd(p[1], "/say hi\r\n/li".as_bytes())
    var lines = r.read_lines()
    assert_equal(len(lines), 1)
    assert_equal(lines[0], "/say hi")
    write_fd(p[1], "st\n\ntail".as_bytes())
    lines = r.read_lines()
    assert_equal(len(lines), 2)
    assert_equal(lines[0], "/list")
    assert_equal(lines[1], "")
    assert_false(r.eof())
    close_fd(p[1])
    lines = r.read_lines()
    assert_equal(len(lines), 1)
    assert_equal(lines[0], "tail")
    assert_true(r.eof())
    assert_equal(len(r.read_lines()), 0)
    close_fd(p[0])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
