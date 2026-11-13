from std.memory import bitcast
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from ignis.cmd.argument import (
    Line,
    parse_bool,
    parse_float,
    parse_int,
    parse_uint,
    split_args,
)


def _split(s: String) raises -> List[String]:
    var r = split_args(s)
    assert_true(r)
    return r.take()


def test_split_args_like_encoding_csv() raises:
    # Expected values from Go's csv.Reader{Comma: ' ', LazyQuotes: true}.
    assert_equal(_split("a b"), ["a", "b"])
    assert_equal(_split(" a  b "), ["", "a", "", "b", ""])
    assert_equal(_split('"a b" c'), ["a b", "c"])
    assert_equal(_split('"a ""q"" b"'), ['a "q" b'])
    assert_equal(_split('x"y z'), ['x"y', "z"])
    assert_equal(_split('"a"b c'), ['a"b c'])
    assert_equal(_split('"a" "b"'), ["a", "b"])
    assert_equal(_split('"" x'), ["", "x"])
    assert_equal(_split('"a"\nb'), ["a"])
    assert_equal(_split('"open'), ["open"])
    assert_equal(_split("one\ntwo"), ["one"])
    assert_equal(_split('"one\ntwo" x'), ["one\ntwo", "x"])
    assert_equal(_split("\n\nlater"), ["later"])
    assert_equal(_split("crlf\r\n"), ["crlf"])
    assert_equal(_split("cr\r"), ["cr"])
    assert_equal(_split("é ü"), ["é", "ü"])
    assert_false(split_args("\n"))
    assert_false(split_args("\n\n"))


def test_line() raises:
    var l = Line(["a", "b", "c"], ["/x"], "/x")
    assert_equal(l.next().value(), "a")
    assert_equal(l.next_n(2).value(), ["a", "b"])
    assert_false(l.next_n(4))
    l.remove_next()
    assert_equal(l.len(), 2)
    assert_equal(l.syntax_error().params, ["/x a ", "b", " c"])
    l.remove_n(5)
    assert_equal(l.len(), 0)
    assert_equal(l.syntax_error().params, ["/x a", "", ""])
    assert_equal(l.usage_error().params, ["/x"])


def test_parse_int() raises:
    assert_equal(parse_int("-128", 8).value(), -128)
    assert_false(parse_int("128", 8))
    assert_equal(parse_int("+5", 64).value(), 5)
    assert_equal(parse_int("007", 16).value(), 7)
    assert_equal(parse_int("-9223372036854775808", 64).value(), Int64.MIN)
    assert_false(parse_int("9223372036854775808", 64))
    assert_false(parse_int("1_0", 64))
    assert_false(parse_int("", 64))
    assert_false(parse_int("-", 64))
    assert_false(parse_int("0x10", 64))
    assert_false(parse_int(" 1", 64))


def test_parse_uint() raises:
    assert_equal(parse_uint("255", 8).value(), 255)
    assert_false(parse_uint("256", 8))
    assert_equal(parse_uint("18446744073709551615", 64).value(), UInt64.MAX)
    assert_false(parse_uint("18446744073709551616", 64))
    assert_false(parse_uint("99999999999999999999", 64))
    assert_false(parse_uint("+1", 64))
    assert_false(parse_uint("-0", 64))


def _bits(s: String, bits: Int = 64) raises -> UInt64:
    var f = parse_float(s, bits)
    assert_true(f, s)
    return UInt64(bitcast[DType.uint64](f.value()))


def test_parse_float_grammar() raises:
    # Bits from Go's strconv.ParseFloat.
    assert_equal(_bits("0.1"), 0x3FB999999999999A)
    assert_equal(_bits(".25"), 0x3FD0000000000000)
    assert_equal(_bits("5."), 0x4014000000000000)
    assert_equal(_bits("-2e3"), 0xC09F400000000000)
    assert_equal(_bits("1_000.5"), 0x408F440000000000)
    assert_equal(_bits("0x1p4"), 0x4030000000000000)
    assert_equal(_bits("0x1.8p1"), 0x4008000000000000)
    assert_equal(_bits("-0x_1p-2"), 0xBFD0000000000000)
    assert_equal(_bits("inf"), 0x7FF0000000000000)
    assert_equal(_bits("-Infinity"), 0xFFF0000000000000)
    assert_equal(_bits("NaN"), 0x7FF8000000000001)
    assert_equal(_bits("1e-400"), 0)
    assert_equal(_bits("-0"), 0x8000000000000000)
    assert_equal(_bits("2.2250738585072011e-308"), 0x000FFFFFFFFFFFFF)
    assert_equal(_bits("4.9406564584124654e-324"), 1)
    assert_false(parse_float("1e400", 64))
    assert_false(parse_float("1.7976931348623159e308", 64))
    assert_false(parse_float("0x1p1024", 64))
    assert_false(parse_float("1e", 64))
    assert_false(parse_float("1_", 64))
    assert_false(parse_float("_1", 64))
    assert_false(parse_float("1__0", 64))
    assert_false(parse_float("0x1", 64))
    assert_false(parse_float("+nan", 64))
    assert_false(parse_float("infx", 64))
    assert_false(parse_float("infin", 64))
    assert_false(parse_float(".", 64))
    assert_false(parse_float("", 64))


def test_parse_float32() raises:
    var max32 = parse_float("3.4028235e38", 32).value()
    assert_equal(Float32(max32), Float32.MAX_FINITE)
    assert_false(parse_float("3.5e38", 32))
    assert_equal(parse_float("1e-50", 32).value(), 0)
    assert_equal(
        Float32(parse_float("0x1p-149", 32).value()),
        Float32(bitcast[DType.float32](UInt32(1))),
    )
    assert_false(parse_float("0x1p128", 32))


def test_parse_bool() raises:
    for s in ["1", "t", "T", "TRUE", "true", "True"]:
        assert_true(parse_bool(s).value())
    for s in ["0", "f", "F", "FALSE", "false", "False"]:
        assert_false(parse_bool(s).value())
    for s in ["yes", "tRUE", "", "2"]:
        assert_false(parse_bool(s))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
