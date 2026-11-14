"""JSON encoding with the output of Go's `encoding/json.Marshal`.

Dragonfly builds form and dialogue JSON with `json.Marshal` on
`map[string]any`, so the bytes the client receives have Go's details: object
keys sorted, `<`, `>` and `&` escaped as `\\u003c`, `\\u003e`, `\\u0026`,
U+2028 and U+2029 escaped, invalid UTF-8 replaced by `\\ufffd`, and floats
in Go's shortest form (`1` rather than `1.0`, exponents from `1e21` and
below `1e-6`).
"""

comptime _HEX = "0123456789abcdef"


def _needs_escape(c: UInt8) -> Bool:
    # Printable ASCII Go escapes: the quote, the backslash and, with
    # HTML escaping on, <, > and &.
    return (
        c == UInt8(ord('"'))
        or c == UInt8(ord("\\"))
        or c == UInt8(ord("<"))
        or c == UInt8(ord(">"))
        or c == UInt8(ord("&"))
    )


def _decode_rune(b: Span[UInt8, _], i: Int) -> Tuple[Int, Int]:
    # Go utf8.DecodeRune: the code point and its length, or (-1, 1) for
    # invalid input (Go's RuneError with size 1).
    var n = len(b)
    var c = Int(b[i])
    if c < 0x80:
        return (c, 1)
    if c < 0xC2 or c > 0xF4:
        return (-1, 1)
    if c < 0xE0:
        if i + 1 >= n or (Int(b[i + 1]) & 0xC0) != 0x80:
            return (-1, 1)
        return (((c & 0x1F) << 6) | (Int(b[i + 1]) & 0x3F), 2)
    if c < 0xF0:
        if i + 2 >= n:
            return (-1, 1)
        var c1 = Int(b[i + 1])
        var c2 = Int(b[i + 2])
        var lo = 0xA0 if c == 0xE0 else 0x80
        var hi = 0x9F if c == 0xED else 0xBF
        if c1 < lo or c1 > hi or (c2 & 0xC0) != 0x80:
            return (-1, 1)
        return (((c & 0x0F) << 12) | ((c1 & 0x3F) << 6) | (c2 & 0x3F), 3)
    if i + 3 >= n:
        return (-1, 1)
    var c1 = Int(b[i + 1])
    var c2 = Int(b[i + 2])
    var c3 = Int(b[i + 3])
    var lo = 0x90 if c == 0xF0 else 0x80
    var hi = 0x8F if c == 0xF4 else 0xBF
    if c1 < lo or c1 > hi or (c2 & 0xC0) != 0x80 or (c3 & 0xC0) != 0x80:
        return (-1, 1)
    return (
        ((c & 0x07) << 18)
        | ((c1 & 0x3F) << 12)
        | ((c2 & 0x3F) << 6)
        | (c3 & 0x3F),
        4,
    )


def valid_utf8(b: Span[UInt8, _]) -> Bool:
    """Reports whether the bytes are valid UTF-8 (Go `utf8.Valid`)."""
    var i = 0
    while i < len(b):
        var r = _decode_rune(b, i)
        if r[0] < 0:
            return False
        i += r[1]
    return True


def write_string(mut out: String, s: StringSlice):
    """Appends a JSON string as Go's `encoding/json` writes it."""
    out += quote_bytes(s.as_bytes())


def quote_bytes(b: Span[UInt8, _]) -> String:
    """Returns bytes as a JSON string as Go's `encoding/json` writes a Go
    string holding them (invalid UTF-8 becomes `\ufffd`)."""
    var raw = List[UInt8](capacity=len(b) + 2)
    raw.append(UInt8(ord('"')))
    var i = 0
    while i < len(b):
        var c = b[i]
        if c < 0x80:
            if c >= 0x20 and not _needs_escape(c):
                raw.append(c)
            elif c == UInt8(ord('"')) or c == UInt8(ord("\\")):
                raw.append(UInt8(ord("\\")))
                raw.append(c)
            elif c == 0x08:
                raw.extend("\\b".as_bytes())
            elif c == 0x0C:
                raw.extend("\\f".as_bytes())
            elif c == UInt8(ord("\n")):
                raw.extend("\\n".as_bytes())
            elif c == UInt8(ord("\r")):
                raw.extend("\\r".as_bytes())
            elif c == UInt8(ord("\t")):
                raw.extend("\\t".as_bytes())
            else:
                raw.extend("\\u00".as_bytes())
                raw.append(_HEX.as_bytes()[Int(c >> 4)])
                raw.append(_HEX.as_bytes()[Int(c & 0xF)])
            i += 1
            continue
        var r = _decode_rune(b, i)
        if r[0] < 0:
            raw.extend("\\ufffd".as_bytes())
        elif r[0] == 0x2028:
            raw.extend("\\u2028".as_bytes())
        elif r[0] == 0x2029:
            raw.extend("\\u2029".as_bytes())
        else:
            for j in range(r[1]):
                raw.append(b[i + j])
        i += r[1]
    raw.append(UInt8(ord('"')))
    return String(unsafe_from_utf8=raw)


def quote(s: StringSlice) -> String:
    """Returns a JSON string as Go's `encoding/json` writes it."""
    var out = String()
    write_string(out, s)
    return out^


def format_float(f: Float64) -> String:
    """Formats a float64 as Go's `encoding/json` does (`strconv`'s shortest
    digits, `f` format from 1e-6 to below 1e21, `e` format outside)."""
    var s = String(f)
    if f == 0:
        return "-0" if s.startswith("-") else "0"
    # Mojo prints the shortest digits that round-trip, like Go's -1
    # precision; take them and the decimal exponent apart.
    var b = s.as_bytes()
    var neg = b[0] == UInt8(ord("-"))
    var i = 1 if neg else 0
    var digits = List[UInt8]()
    var int_len = 0
    var seen_point = False
    var exp10 = 0
    while i < len(b):
        var c = b[i]
        if c == UInt8(ord(".")):
            seen_point = True
        elif c == UInt8(ord("e")):
            var esign = 1
            var j = i + 1
            if b[j] == UInt8(ord("-")):
                esign = -1
                j += 1
            elif b[j] == UInt8(ord("+")):
                j += 1
            while j < len(b):
                exp10 = exp10 * 10 + Int(b[j]) - 48
                j += 1
            exp10 *= esign
            break
        else:
            digits.append(c)
            if not seen_point:
                int_len += 1
        i += 1
    # Leading zeros move the decimal point; trailing zeros go.
    var lead = 0
    while lead < len(digits) - 1 and digits[lead] == UInt8(ord("0")):
        lead += 1
    var dexp = int_len - lead + exp10  # value = 0.d1d2... * 10^dexp
    var end = len(digits)
    while end > lead + 1 and digits[end - 1] == UInt8(ord("0")):
        end -= 1
    var d = String(unsafe_from_utf8=Span(digits)[lead:end])
    var n = end - lead
    var out = String("-") if neg else String()
    var a = abs(f)
    if a < 1e-6 or a >= 1e21:
        out += d[byte=0:1]
        if n > 1:
            out += "."
            out += d[byte=1:]
        var x = dexp - 1
        out += "e-" if x < 0 else "e+"
        var ax = -x if x < 0 else x
        if ax < 10 and x >= 0:
            out += "0"
        out += String(ax)
        return out^
    if dexp <= 0:
        out += "0."
        for _ in range(-dexp):
            out += "0"
        out += d
    elif dexp >= n:
        out += d
        for _ in range(dexp - n):
            out += "0"
    else:
        out += d[byte=:dexp]
        out += "."
        out += d[byte=dexp:]
    return out^


struct JsonObject(Movable):
    """An object whose members are written sorted by key, as Go writes a
    `map[string]any`."""

    var _keys: List[String]
    var _values: List[String]

    def __init__(out self):
        """Creates an empty object."""
        self._keys = List[String]()
        self._values = List[String]()

    def raw(mut self, key: String, var value: String):
        """Adds a member whose value is already JSON."""
        self._keys.append(key)
        self._values.append(value^)

    def string(mut self, key: String, value: StringSlice):
        """Adds a string member."""
        self.raw(key, quote(value))

    def int(mut self, key: String, value: Int):
        """Adds an integer member."""
        self.raw(key, String(value))

    def float(mut self, key: String, value: Float64):
        """Adds a float64 member."""
        self.raw(key, format_float(value))

    def bool(mut self, key: String, value: Bool):
        """Adds a boolean member."""
        self.raw(key, "true" if value else "false")

    def encode(self) -> String:
        """Returns the object with its members sorted by key."""
        var order = List[Int]()
        for i in range(len(self._keys)):
            var j = len(order)
            while j > 0 and self._keys[order[j - 1]] > self._keys[i]:
                j -= 1
            order.insert(j, i)
        var out = String("{")
        for k in range(len(order)):
            if k > 0:
                out += ","
            out += quote(self._keys[order[k]])
            out += ":"
            out += self._values[order[k]]
        out += "}"
        return out^


def string_array(values: List[String]) -> String:
    """Returns a JSON array of strings (Go `[]string`; nil is `null`)."""
    var out = String("[")
    for i in range(len(values)):
        if i > 0:
            out += ","
        write_string(out, values[i])
    out += "]"
    return out^
