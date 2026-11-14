"""A JSON (RFC 8259) document parsed into an arena of nodes.

Dragonfly reads JSON resources (`df-mc/worldupgrader` schemas) with Go's
`encoding/json` into structs. Mojo has no reflection and a struct cannot
hold `List[Self]`, so a `JsonDoc` keeps every value in one list and refers
to values by index, like the NBT `Tree` of the protocol submodule. Object
members keep their order.
"""

comptime JSON_NULL: UInt8 = 0
"""The kind of `null`."""
comptime JSON_BOOL: UInt8 = 1
"""The kind of `true` and `false`."""
comptime JSON_NUMBER: UInt8 = 2
"""The kind of a number."""
comptime JSON_STRING: UInt8 = 3
"""The kind of a string."""
comptime JSON_ARRAY: UInt8 = 4
"""The kind of an array."""
comptime JSON_OBJECT: UInt8 = 5
"""The kind of an object."""

comptime _MAX_DEPTH = 128


@fieldwise_init
struct _Node(Copyable, Movable):
    var kind: UInt8
    var key: String
    var text: String
    var first: Int
    var next: Int
    var count: Int


struct JsonDoc(Movable):
    """A parsed JSON document."""

    var _nodes: List[_Node]

    def __init__(out self, text: Span[mut=False, UInt8, _]) raises:
        """Parses a document."""
        self._nodes = List[_Node]()
        var pos = _skip(text, 0)
        _ = self._value(text, pos, 0)
        pos = _skip(text, pos)
        if pos != len(text):
            raise Error(t"json: trailing data at offset {pos}")

    def root(self) -> Int:
        """Returns the top-level value."""
        return 0

    def kind(self, i: Int) -> UInt8:
        """Returns the kind of a value."""
        return self._nodes[i].kind

    def key(self, i: Int) -> String:
        """Returns the member name of an object member."""
        return self._nodes[i].key

    def children(self, i: Int) -> List[Int]:
        """Returns the elements of an array or the members of an object."""
        var out = List[Int](capacity=self._nodes[i].count)
        var c = self._nodes[i].first
        while c >= 0:
            out.append(c)
            c = self._nodes[c].next
        return out^

    def get(self, i: Int, key: StringSlice) -> Optional[Int]:
        """Looks up an object member."""
        if self._nodes[i].kind != JSON_OBJECT:
            return None
        var c = self._nodes[i].first
        while c >= 0:
            if self._nodes[c].key == key:
                return c
            c = self._nodes[c].next
        return None

    def as_string(self, i: Int) raises -> String:
        """Returns a string value."""
        if self._nodes[i].kind != JSON_STRING:
            raise Error("json: value is not a string")
        return self._nodes[i].text

    def as_int(self, i: Int) raises -> Int:
        """Returns an integer value."""
        if self._nodes[i].kind != JSON_NUMBER:
            raise Error("json: value is not a number")
        return Int(self._nodes[i].text)

    def as_float(self, i: Int) raises -> Float64:
        """Returns a number as a float; raises if the value is not a number."""
        if self._nodes[i].kind != JSON_NUMBER:
            raise Error("json: value is not a number")
        return atof(self._nodes[i].text)

    def as_bool(self, i: Int) raises -> Bool:
        """Returns a boolean value."""
        if self._nodes[i].kind != JSON_BOOL:
            raise Error("json: value is not a boolean")
        return self._nodes[i].text == "true"

    def _push(mut self, kind: UInt8, var text: String) -> Int:
        self._nodes.append(_Node(kind, String(), text^, -1, -1, 0))
        return len(self._nodes) - 1

    def _value(
        mut self, src: Span[mut=False, UInt8, _], mut pos: Int, depth: Int
    ) raises -> Int:
        if depth > _MAX_DEPTH:
            raise Error("json: nesting too deep")
        if pos >= len(src):
            raise Error("json: unexpected end of input")
        var c = src[pos]
        if c == UInt8(ord("{")):
            var node = self._push(JSON_OBJECT, String())
            pos = _skip(src, pos + 1)
            var last = -1
            if pos < len(src) and src[pos] == UInt8(ord("}")):
                pos += 1
                return node
            while True:
                pos = _skip(src, pos)
                var key = _string(src, pos)
                pos = _skip(src, pos)
                _expect(src, pos, ":")
                pos = _skip(src, pos)
                var child = self._value(src, pos, depth + 1)
                self._nodes[child].key = key^
                if last < 0:
                    self._nodes[node].first = child
                else:
                    self._nodes[last].next = child
                last = child
                self._nodes[node].count += 1
                pos = _skip(src, pos)
                if pos < len(src) and src[pos] == UInt8(ord(",")):
                    pos += 1
                    continue
                _expect(src, pos, "}")
                return node
        if c == UInt8(ord("[")):
            var node = self._push(JSON_ARRAY, String())
            pos = _skip(src, pos + 1)
            var last = -1
            if pos < len(src) and src[pos] == UInt8(ord("]")):
                pos += 1
                return node
            while True:
                pos = _skip(src, pos)
                var child = self._value(src, pos, depth + 1)
                if last < 0:
                    self._nodes[node].first = child
                else:
                    self._nodes[last].next = child
                last = child
                self._nodes[node].count += 1
                pos = _skip(src, pos)
                if pos < len(src) and src[pos] == UInt8(ord(",")):
                    pos += 1
                    continue
                _expect(src, pos, "]")
                return node
        if c == UInt8(ord('"')):
            return self._push(JSON_STRING, _string(src, pos))
        if _word(src, pos, "true"):
            return self._push(JSON_BOOL, "true")
        if _word(src, pos, "false"):
            return self._push(JSON_BOOL, "false")
        if _word(src, pos, "null"):
            return self._push(JSON_NULL, String())
        var start = pos
        if pos < len(src) and src[pos] == UInt8(ord("-")):
            pos += 1
        var digits = 0
        while pos < len(src) and (
            (src[pos] >= UInt8(ord("0")) and src[pos] <= UInt8(ord("9")))
            or src[pos] == UInt8(ord("."))
            or src[pos] == UInt8(ord("e"))
            or src[pos] == UInt8(ord("E"))
            or src[pos] == UInt8(ord("+"))
            or (src[pos] == UInt8(ord("-")) and pos > start)
        ):
            pos += 1
            digits += 1
        if digits == 0:
            raise Error(t"json: unexpected character at offset {start}")
        return self._push(JSON_NUMBER, String(from_utf8=src[start:pos]))


def _skip(src: Span[mut=False, UInt8, _], pos: Int) -> Int:
    var p = pos
    while p < len(src) and (
        src[p] == 0x20 or src[p] == 0x0A or src[p] == 0x0D or src[p] == 0x09
    ):
        p += 1
    return p


def _expect(
    src: Span[mut=False, UInt8, _], mut pos: Int, c: StringSlice
) raises:
    if pos >= len(src) or src[pos] != c.as_bytes()[0]:
        raise Error(t"json: expected '{c}' at offset {pos}")
    pos += 1


def _word(src: Span[mut=False, UInt8, _], mut pos: Int, w: StringSlice) -> Bool:
    var b = w.as_bytes()
    if pos + len(b) > len(src):
        return False
    for i in range(len(b)):
        if src[pos + i] != b[i]:
            return False
    pos += len(b)
    return True


def _hex4(src: Span[mut=False, UInt8, _], pos: Int) raises -> UInt32:
    if pos + 4 > len(src):
        raise Error("json: truncated \\u escape")
    var v = UInt32(0)
    for i in range(4):
        var c = src[pos + i]
        v <<= 4
        if c >= UInt8(ord("0")) and c <= UInt8(ord("9")):
            v |= UInt32(c - UInt8(ord("0")))
        elif c >= UInt8(ord("a")) and c <= UInt8(ord("f")):
            v |= UInt32(c - UInt8(ord("a")) + 10)
        elif c >= UInt8(ord("A")) and c <= UInt8(ord("F")):
            v |= UInt32(c - UInt8(ord("A")) + 10)
        else:
            raise Error("json: invalid \\u escape")
    return v


def _put_utf8(mut out: List[UInt8], cp: UInt32):
    if cp < 0x80:
        out.append(UInt8(cp))
    elif cp < 0x800:
        out.append(UInt8(0xC0 | (cp >> 6)))
        out.append(UInt8(0x80 | (cp & 0x3F)))
    elif cp < 0x10000:
        out.append(UInt8(0xE0 | (cp >> 12)))
        out.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
        out.append(UInt8(0x80 | (cp & 0x3F)))
    else:
        out.append(UInt8(0xF0 | (cp >> 18)))
        out.append(UInt8(0x80 | ((cp >> 12) & 0x3F)))
        out.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
        out.append(UInt8(0x80 | (cp & 0x3F)))


def _string(src: Span[mut=False, UInt8, _], mut pos: Int) raises -> String:
    _expect(src, pos, '"')
    var out = List[UInt8]()
    while True:
        if pos >= len(src):
            raise Error("json: unterminated string")
        var c = src[pos]
        pos += 1
        if c == UInt8(ord('"')):
            break
        if c < 0x20:
            raise Error("json: control character in string")
        if c != UInt8(ord("\\")):
            out.append(c)
            continue
        if pos >= len(src):
            raise Error("json: unterminated escape")
        var e = src[pos]
        pos += 1
        if e == UInt8(ord("n")):
            out.append(0x0A)
        elif e == UInt8(ord("t")):
            out.append(0x09)
        elif e == UInt8(ord("r")):
            out.append(0x0D)
        elif e == UInt8(ord("b")):
            out.append(0x08)
        elif e == UInt8(ord("f")):
            out.append(0x0C)
        elif e == UInt8(ord("u")):
            var cp = _hex4(src, pos)
            pos += 4
            if (
                cp >= 0xD800
                and cp < 0xDC00
                and pos + 6 <= len(src)
                and src[pos] == UInt8(ord("\\"))
                and src[pos + 1] == UInt8(ord("u"))
            ):
                var lo = _hex4(src, pos + 2)
                if lo >= 0xDC00 and lo < 0xE000:
                    pos += 6
                    cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00)
            if cp >= 0xD800 and cp < 0xE000:
                cp = 0xFFFD
            _put_utf8(out, cp)
        elif (
            e == UInt8(ord('"'))
            or e == UInt8(ord("\\"))
            or e == UInt8(ord("/"))
        ):
            out.append(e)
        else:
            raise Error("json: invalid escape")
    return String(from_utf8=Span(out))
