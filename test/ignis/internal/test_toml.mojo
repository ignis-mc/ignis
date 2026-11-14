from ignis.internal.toml import (
    TOML_ARRAY,
    TOML_BOOL,
    TOML_FLOAT,
    TOML_INT,
    TOML_STRING,
    parse_toml,
    toml_quote,
)
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def test_tables_and_values() raises:
    var doc = parse_toml(
        """# comment
top = 1
[Network]
Address = ":19132" # trailing
Transport = ["raknet", 'nethernet']
[Server]
Name = "A \\"quoted\\" name"
AuthEnabled = false
"Odd Key" = 1_000
ratio = -2.5e1
[a.b]
c = true
"""
    )
    assert_equal(doc.get_int("top", 0), 1)
    assert_equal(doc.get_string("Network.Address", ""), ":19132")
    var t = doc.get_string_list("Network.Transport", [])
    assert_equal(len(t), 2)
    assert_equal(t[1], "nethernet")
    assert_equal(doc.get_string("Server.Name", ""), 'A "quoted" name')
    assert_false(doc.get_bool("Server.AuthEnabled", True))
    assert_equal(doc.get_int("Server.Odd Key", 0), 1000)
    assert_equal(doc.values["Server.ratio"].kind, TOML_FLOAT)
    assert_true(doc.get_bool("a.b.c", False))
    assert_equal(doc.get_int("Missing.Key", 7), 7)


def test_type_errors() raises:
    var doc = parse_toml('a = "x"\nb = 3\n')
    with assert_raises(contains="not an integer"):
        _ = doc.get_int("a", 0)
    with assert_raises(contains="not a string"):
        _ = doc.get_string("b", "")


def test_rejects_unsupported() raises:
    with assert_raises(contains="inline tables"):
        _ = parse_toml("a = {b = 1}\n")
    with assert_raises(contains="arrays of tables"):
        _ = parse_toml("[[a]]\n")
    with assert_raises(contains="set twice"):
        _ = parse_toml("a = 1\na = 2\n")
    with assert_raises(contains="unterminated"):
        _ = parse_toml('a = "x\n')
    with assert_raises(contains="after value"):
        _ = parse_toml("a = 1 2\n")


def test_quote_round_trip() raises:
    var s = String('tab\there "q" back\\slash é')
    var doc = parse_toml(String(t"k = {toml_quote(s)}\n"))
    assert_equal(doc.get_string("k", ""), s)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
