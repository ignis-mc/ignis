"""A TOML subset, enough for Dragonfly's `config.toml` (which Go reads with
`github.com/pelletier/go-toml`).

Supported: `[table]` and `[dotted.table]` headers, `key = value` pairs with
bare or quoted keys, basic strings (`"..."` with `\\"`, `\\\\`, `\\n`,
`\\t`, `\\r` escapes), literal strings (`'...'`), integers (with `_`
separators and a sign), floats, booleans, one-line arrays of those, and
`#` comments. Not supported (rejected with an error): multi-line strings
and arrays, inline tables, arrays of tables and dates.
"""

from std.collections import Dict

comptime TOML_STRING = 0
"""A string value."""
comptime TOML_INT = 1
"""An integer value."""
comptime TOML_FLOAT = 2
"""A float value."""
comptime TOML_BOOL = 3
"""A boolean value."""
comptime TOML_ARRAY = 4
"""An array value."""


struct TomlValue(Copyable):
    """One value: its kind and its text (decoded for strings)."""

    var kind: Int
    """One of the `TOML_*` kinds."""
    var text: String
    """The string contents, or the literal as written for other scalars."""
    var items: List[String]
    """The elements of an array, decoded like scalars."""
    var item_kinds: List[Int]
    """The kind of each element of `items`."""

    def __init__(out self, kind: Int, var text: String):
        """Creates a scalar.

        Args:
            kind: The kind.
            text: The decoded string or the literal.
        """
        self.kind = kind
        self.text = text^
        self.items = List[String]()
        self.item_kinds = List[Int]()


struct TomlDocument(Copyable, Defaultable):
    """A parsed document: every value under its full dotted key, such as
    `Network.Address`."""

    var values: Dict[String, TomlValue]
    """The values by full key."""

    def __init__(out self):
        """Creates an empty document."""
        self.values = Dict[String, TomlValue]()

    def has(self, key: String) -> Bool:
        """Reports whether a key is set.

        Args:
            key: The full dotted key.

        Returns:
            True if the document sets the key.
        """
        return key in self.values

    def get_string(self, key: String, default: String) raises -> String:
        """Reads a string.

        Args:
            key: The full dotted key.
            default: The value if the key is missing.

        Returns:
            The string.

        Raises:
            If the value is not a string.
        """
        if case .Some(v) = self.values.get(key):
            if v.kind != TOML_STRING:
                raise Error(t"toml: {key} is not a string")
            return v.text.copy()
        return default.copy()

    def get_int(self, key: String, default: Int) raises -> Int:
        """Reads an integer.

        Args:
            key: The full dotted key.
            default: The value if the key is missing.

        Returns:
            The integer.

        Raises:
            If the value is not an integer.
        """
        if case .Some(v) = self.values.get(key):
            if v.kind != TOML_INT:
                raise Error(t"toml: {key} is not an integer")
            return Int(v.text)
        return default

    def get_bool(self, key: String, default: Bool) raises -> Bool:
        """Reads a boolean.

        Args:
            key: The full dotted key.
            default: The value if the key is missing.

        Returns:
            The boolean.

        Raises:
            If the value is not a boolean.
        """
        if case .Some(v) = self.values.get(key):
            if v.kind != TOML_BOOL:
                raise Error(t"toml: {key} is not a boolean")
            return v.text == "true"
        return default

    def get_string_list(
        self, key: String, var default: List[String]
    ) raises -> List[String]:
        """Reads an array of strings.

        Args:
            key: The full dotted key.
            default: The value if the key is missing.

        Returns:
            The strings.

        Raises:
            If the value is not an array of strings.
        """
        if case .Some(v) = self.values.get(key):
            if v.kind != TOML_ARRAY:
                raise Error(t"toml: {key} is not an array")
            var out = List[String]()
            for i in range(len(v.items)):
                if v.item_kinds[i] != TOML_STRING:
                    raise Error(t"toml: {key} holds a non-string")
                out.append(v.items[i].copy())
            return out^
        return default^


struct _Cursor:
    var b: List[UInt8]
    var i: Int
    var line: Int

    def __init__(out self, text: StringSlice):
        self.b = List[UInt8](text.as_bytes())
        self.i = 0
        self.line = 1

    def done(self) -> Bool:
        return self.i >= len(self.b)

    def peek(self) -> UInt8:
        return self.b[self.i] if self.i < len(self.b) else 0

    def skip_space(mut self):
        while not self.done() and (self.peek() == 32 or self.peek() == 9):
            self.i += 1

    def error(self, msg: String) -> Error:
        return Error(t"toml: line {self.line}: {msg}")

    def end_line(mut self) raises:
        """Allows only spaces and a comment until the end of the line."""
        self.skip_space()
        if self.peek() == UInt8(ord("#")):
            while not self.done() and self.peek() != 10:
                self.i += 1
        if self.peek() == 13:
            self.i += 1
        if self.done():
            return
        if self.peek() != 10:
            raise self.error("unexpected text after value")
        self.i += 1
        self.line += 1


def _is_bare(c: UInt8) -> Bool:
    return (
        (c >= UInt8(ord("a")) and c <= UInt8(ord("z")))
        or (c >= UInt8(ord("A")) and c <= UInt8(ord("Z")))
        or (c >= UInt8(ord("0")) and c <= UInt8(ord("9")))
        or c == UInt8(ord("_"))
        or c == UInt8(ord("-"))
    )


def _bytes_to_string(b: List[UInt8]) raises -> String:
    return String(from_utf8=Span(b))


def _parse_string(mut c: _Cursor) raises -> String:
    var quote = c.peek()
    c.i += 1
    if c.peek() == quote and c.i + 1 < len(c.b) and c.b[c.i + 1] == quote:
        raise c.error("multi-line strings are not supported")
    var out = List[UInt8]()
    while True:
        if c.done() or c.peek() == 10:
            raise c.error("unterminated string")
        var ch = c.peek()
        c.i += 1
        if ch == quote:
            break
        if ch == UInt8(ord("\\")) and quote == UInt8(ord('"')):
            var e = c.peek()
            c.i += 1
            if e == UInt8(ord("n")):
                out.append(10)
            elif e == UInt8(ord("t")):
                out.append(9)
            elif e == UInt8(ord("r")):
                out.append(13)
            elif e == UInt8(ord('"')) or e == UInt8(ord("\\")):
                out.append(e)
            else:
                raise c.error("unsupported escape")
            continue
        out.append(ch)
    return _bytes_to_string(out)


def _parse_key(mut c: _Cursor) raises -> String:
    var key = String()
    while True:
        c.skip_space()
        var part: String
        if c.peek() == UInt8(ord('"')) or c.peek() == UInt8(ord("'")):
            part = _parse_string(c)
        else:
            var start = c.i
            while not c.done() and _is_bare(c.peek()):
                c.i += 1
            if c.i == start:
                raise c.error("expected a key")
            part = _bytes_to_string(List[UInt8](Span(c.b)[start : c.i]))
        if key.byte_length() > 0:
            key += "."
        key += part
        c.skip_space()
        if c.peek() != UInt8(ord(".")):
            return key^
        c.i += 1


def _parse_scalar_word(mut c: _Cursor) raises -> TomlValue:
    var start = c.i
    while not c.done():
        var ch = c.peek()
        if (
            ch == UInt8(ord(","))
            or ch == UInt8(ord("]"))
            or ch == UInt8(ord("#"))
        ):
            break
        if ch == 32 or ch == 9 or ch == 10 or ch == 13:
            break
        c.i += 1
    var word = _bytes_to_string(List[UInt8](Span(c.b)[start : c.i]))
    if word == "true" or word == "false":
        return TomlValue(TOML_BOOL, word^)
    var digits = String()
    var is_float = False
    var n = 0
    for b in word.as_bytes():
        if b == UInt8(ord("_")):
            continue
        if b == UInt8(ord(".")) or b == UInt8(ord("e")) or b == UInt8(ord("E")):
            is_float = True
        elif not (
            (b >= UInt8(ord("0")) and b <= UInt8(ord("9")))
            or b == UInt8(ord("+"))
            or b == UInt8(ord("-"))
        ):
            raise c.error(String(t"invalid value {word}"))
        digits += chr(Int(b))
        n += 1
    if n == 0:
        raise c.error("expected a value")
    if is_float:
        _ = Float64(digits)
        return TomlValue(TOML_FLOAT, digits^)
    _ = Int(digits)
    return TomlValue(TOML_INT, digits^)


def _parse_value(mut c: _Cursor) raises -> TomlValue:
    c.skip_space()
    var ch = c.peek()
    if ch == UInt8(ord('"')) or ch == UInt8(ord("'")):
        return TomlValue(TOML_STRING, _parse_string(c))
    if ch == UInt8(ord("{")):
        raise c.error("inline tables are not supported")
    if ch == UInt8(ord("[")):
        c.i += 1
        var arr = TomlValue(TOML_ARRAY, String())
        while True:
            c.skip_space()
            if c.done() or c.peek() == 10:
                raise c.error("multi-line arrays are not supported")
            if c.peek() == UInt8(ord("]")):
                c.i += 1
                return arr^
            if c.peek() == UInt8(ord("[")):
                raise c.error("nested arrays are not supported")
            var item = _parse_value(c)
            arr.items.append(item.text.copy())
            arr.item_kinds.append(item.kind)
            c.skip_space()
            if c.peek() == UInt8(ord(",")):
                c.i += 1
            elif c.peek() != UInt8(ord("]")):
                raise c.error("expected , or ] in array")
    return _parse_scalar_word(c)


def parse_toml(text: StringSlice) raises -> TomlDocument:
    """Parses a document in the supported subset.

    Args:
        text: The document.

    Returns:
        Every value under its full dotted key.

    Raises:
        On syntax outside the subset, or a key set twice.
    """
    var doc = TomlDocument()
    var c = _Cursor(text)
    var table = String()
    while not c.done():
        c.skip_space()
        var ch = c.peek()
        if ch == 10 or ch == 13 or ch == UInt8(ord("#")):
            c.end_line()
            continue
        if ch == UInt8(ord("[")):
            c.i += 1
            if c.peek() == UInt8(ord("[")):
                raise c.error("arrays of tables are not supported")
            table = _parse_key(c)
            if c.peek() != UInt8(ord("]")):
                raise c.error("expected ] after table name")
            c.i += 1
            c.end_line()
            continue
        var key = _parse_key(c)
        if c.peek() != UInt8(ord("=")):
            raise c.error(String(t"expected = after {key}"))
        c.i += 1
        var value = _parse_value(c)
        c.end_line()
        var full = key.copy()
        if table.byte_length() > 0:
            full = table + "." + key
        if full in doc.values:
            raise c.error(String(t"{full} is set twice"))
        doc.values[full] = value^
    return doc^


def toml_quote(s: String) -> String:
    """Writes a string as a TOML basic string.

    Args:
        s: The string.

    Returns:
        The quoted string, with `"`, `\\` and control characters escaped.
    """
    var out = List[UInt8]()
    out.append(UInt8(ord('"')))
    for b in s.as_bytes():
        var esc = UInt8(0)
        if b == UInt8(ord('"')) or b == UInt8(ord("\\")):
            esc = b
        elif b == 10:
            esc = UInt8(ord("n"))
        elif b == 9:
            esc = UInt8(ord("t"))
        elif b == 13:
            esc = UInt8(ord("r"))
        if esc != 0:
            out.append(UInt8(ord("\\")))
            out.append(esc)
        else:
            out.append(b)
    out.append(UInt8(ord('"')))
    # The input was valid UTF-8 and only ASCII bytes were added.
    return String(unsafe_from_utf8=Span(out))
