"""JSON numbers read the way Dragonfly reads form responses: Go's decoder
with `UseNumber`, then `json.Number.Int64` (`strconv.ParseInt`) or
`Float64` (`strconv.ParseFloat`)."""

from ...cmd.argument import parse_float, parse_int, parse_uint
from ...internal.json import JSON_BOOL, JSON_NULL, JSON_NUMBER, JsonDoc


def valid_number(s: StringSlice) -> Bool:
    """Reports whether a string is a JSON number literal (RFC 8259)."""
    var b = s.as_bytes()
    var i = 0
    var n = len(b)
    if i < n and b[i] == UInt8(ord("-")):
        i += 1
    if i >= n:
        return False
    if b[i] == UInt8(ord("0")):
        i += 1
    elif b[i] >= UInt8(ord("1")) and b[i] <= UInt8(ord("9")):
        while i < n and b[i] >= UInt8(ord("0")) and b[i] <= UInt8(ord("9")):
            i += 1
    else:
        return False
    if i < n and b[i] == UInt8(ord(".")):
        i += 1
        var start = i
        while i < n and b[i] >= UInt8(ord("0")) and b[i] <= UInt8(ord("9")):
            i += 1
        if i == start:
            return False
    if i < n and (b[i] == UInt8(ord("e")) or b[i] == UInt8(ord("E"))):
        i += 1
        if i < n and (b[i] == UInt8(ord("+")) or b[i] == UInt8(ord("-"))):
            i += 1
        var start = i
        while i < n and b[i] >= UInt8(ord("0")) and b[i] <= UInt8(ord("9")):
            i += 1
        if i == start:
            return False
    return i == n


def number_text(doc: JsonDoc, i: Int) raises -> String:
    """Returns the literal of a number value, raising if it is not a valid
    JSON number (Go's decoder rejects it)."""
    if doc.kind(i) != JSON_NUMBER:
        raise Error("json: value is not a number")
    var s = doc.number_text(i)
    if not valid_number(s):
        raise Error(t"json: invalid number literal {s}")
    return s^


def parse_number_int(doc: JsonDoc, i: Int) raises -> Optional[Int64]:
    """Go `json.Number.Int64`: None unless the literal is a plain integer
    that fits in 64 bits."""
    return parse_int(number_text(doc, i), 64)


def parse_number_float(doc: JsonDoc, i: Int) raises -> Optional[Float64]:
    """Go `json.Number.Float64`."""
    return parse_float(number_text(doc, i), 64)


def parse_uint_response(data: String) raises -> UInt64:
    """Go `json.Unmarshal(b, &index)` into a `uint`: a non-negative integer
    literal; `null` leaves the index at 0."""
    var doc = JsonDoc(data.as_bytes())
    var root = doc.root()
    if doc.kind(root) == JSON_NULL:
        return 0
    if doc.kind(root) != JSON_NUMBER:
        raise Error("cannot parse button index as int: json: cannot unmarshal")
    var s = number_text(doc, root)
    var v = parse_uint(s, 64)
    if not v:
        raise Error(
            t"cannot parse button index as int: json: cannot unmarshal number"
            t" {s} into Go value of type uint"
        )
    return v.value()


def parse_bool_response(data: String) raises -> Bool:
    """Go `json.Unmarshal(b, &value)` into a `bool`: `true` or `false`;
    `null` leaves the value false."""
    var doc = JsonDoc(data.as_bytes())
    var root = doc.root()
    if doc.kind(root) == JSON_NULL:
        return False
    if doc.kind(root) != JSON_BOOL:
        raise Error("error parsing JSON as bool: json: cannot unmarshal")
    return doc.as_bool(root)
