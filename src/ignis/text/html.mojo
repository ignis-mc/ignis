"""The part of `golang.org/x/net/html`'s tokenizer (v0.50.0, `token.go` and
`escape.go`) that gophertunnel's `text.Colourf` runs its input through.

Ported: text (newline conversion and character references, with the full
entity table in `entity.mojo`), start, end and self-closing tags (lower-cased
names; attributes are read past but not kept, since `Colourf` drops them),
comments, doctypes, bogus comments, raw text after `iframe`, `noembed`,
`noframes`, `noscript`, `plaintext`, `style`, `xmp` and `script`, and RCDATA
after `textarea` and `title`. Not ported: the script-data escape states of
`readScript` (`<!--` inside a script); a script's raw text ends at the first
`</script`, as other raw text does.
"""

from .entity import entity_lookup

comptime TOKEN_ERROR = 0
comptime TOKEN_TEXT = 1
comptime TOKEN_START_TAG = 2
comptime TOKEN_END_TAG = 3
comptime TOKEN_SELF_CLOSING_TAG = 4
comptime TOKEN_COMMENT = 5
comptime TOKEN_DOCTYPE = 6


@fieldwise_init
struct Token(Copyable):
    """A token: its type and its data (the unescaped text, or the
    lower-cased tag name)."""

    var type: Int
    var data: String


def _is_space(c: UInt8) -> Bool:
    return (
        c == UInt8(ord(" "))
        or c == UInt8(ord("\n"))
        or c == UInt8(ord("\r"))
        or c == UInt8(ord("\t"))
        or c == 0x0C
    )


def _is_alpha(c: UInt8) -> Bool:
    return (c >= UInt8(ord("a")) and c <= UInt8(ord("z"))) or (
        c >= UInt8(ord("A")) and c <= UInt8(ord("Z"))
    )


struct Tokenizer(Movable):
    """Go `html.Tokenizer` over an in-memory string."""

    var _buf: List[UInt8]
    var _end: Int
    var _raw_start: Int
    var _data_start: Int
    var _data_end: Int
    var _err: Bool
    var _tt: Int
    var _raw_tag: String
    var _text_is_raw: Bool
    var _convert_nul: Bool
    var _last_attr_end: Int
    var _n_attrs: Int

    def __init__(out self, s: StringSlice):
        """Creates a tokenizer reading a string (Go `NewTokenizer`)."""
        self._buf = List[UInt8](s.as_bytes())
        self._end = 0
        self._raw_start = 0
        self._data_start = 0
        self._data_end = 0
        self._err = False
        self._tt = TOKEN_ERROR
        self._raw_tag = String()
        self._text_is_raw = False
        self._convert_nul = False
        self._last_attr_end = 0
        self._n_attrs = 0

    def _read_byte(mut self) -> UInt8:
        if self._end >= len(self._buf):
            self._err = True
            return 0
        var c = self._buf[self._end]
        self._end += 1
        return c

    def _skip_white_space(mut self):
        if self._err:
            return
        while True:
            var c = self._read_byte()
            if self._err:
                return
            if not _is_space(c):
                self._end -= 1
                return

    def next(mut self) -> Int:
        """Scans the next token and returns its type (Go `Next`)."""
        self._raw_start = self._end
        self._data_start = self._end
        self._data_end = self._end
        if self._err:
            self._tt = TOKEN_ERROR
            return self._tt
        if self._raw_tag.byte_length() > 0:
            if self._raw_tag == "plaintext":
                while not self._err:
                    _ = self._read_byte()
                self._data_end = self._end
                self._text_is_raw = True
            else:
                self._read_raw_or_rcdata()
            if self._data_end > self._data_start:
                self._tt = TOKEN_TEXT
                self._convert_nul = True
                return self._tt
        self._text_is_raw = False
        self._convert_nul = False
        while True:
            var c = self._read_byte()
            if self._err:
                break
            if c != UInt8(ord("<")):
                continue
            c = self._read_byte()
            if self._err:
                break
            var token_type: Int
            if _is_alpha(c):
                token_type = TOKEN_START_TAG
            elif c == UInt8(ord("/")):
                token_type = TOKEN_END_TAG
            elif c == UInt8(ord("!")) or c == UInt8(ord("?")):
                token_type = TOKEN_COMMENT
            else:
                self._end -= 1
                continue
            var x = self._end - 2
            if self._raw_start < x:
                self._end = x
                self._data_end = x
                self._tt = TOKEN_TEXT
                return self._tt
            if token_type == TOKEN_START_TAG:
                self._tt = self._read_start_tag()
                return self._tt
            if token_type == TOKEN_END_TAG:
                c = self._read_byte()
                if self._err:
                    break
                if c == UInt8(ord(">")):
                    self._tt = TOKEN_COMMENT
                    return self._tt
                if _is_alpha(c):
                    self._read_tag()
                    self._tt = TOKEN_ERROR if self._err else TOKEN_END_TAG
                    return self._tt
                self._end -= 1
                self._read_until_close_angle()
                self._tt = TOKEN_COMMENT
                return self._tt
            if c == UInt8(ord("!")):
                self._tt = self._read_markup_declaration()
                return self._tt
            self._end -= 1
            self._read_until_close_angle()
            self._tt = TOKEN_COMMENT
            return self._tt
        if self._raw_start < self._end:
            self._data_end = self._end
            self._tt = TOKEN_TEXT
            return self._tt
        self._tt = TOKEN_ERROR
        return self._tt

    def _read_raw_or_rcdata(mut self):
        while True:
            var c = self._read_byte()
            if self._err:
                break
            if c != UInt8(ord("<")):
                continue
            c = self._read_byte()
            if self._err:
                break
            if c != UInt8(ord("/")):
                self._end -= 1
                continue
            if self._read_raw_end_tag() or self._err:
                break
        self._data_end = self._end
        self._text_is_raw = (
            self._raw_tag != "textarea" and self._raw_tag != "title"
        )
        self._raw_tag = String()

    def _read_raw_end_tag(mut self) -> Bool:
        var tag = List[UInt8](self._raw_tag.as_bytes())
        for i in range(len(tag)):
            var c = self._read_byte()
            if self._err:
                return False
            if c != tag[i] and c != tag[i] - (
                UInt8(ord("a")) - UInt8(ord("A"))
            ):
                self._end -= 1
                return False
        var c = self._read_byte()
        if self._err:
            return False
        if _is_space(c) or c == UInt8(ord("/")) or c == UInt8(ord(">")):
            self._end -= 3 + len(tag)
            return True
        self._end -= 1
        return False

    def _read_comment(mut self):
        self._data_start = self._end
        var dash_count = 0
        var beginning = True
        while True:
            var c = self._read_byte()
            if self._err:
                self._data_end = self._end
                return
            if c == UInt8(ord("-")):
                dash_count += 1
                continue
            if c == UInt8(ord(">")):
                if dash_count >= 2 or beginning:
                    self._data_end = max(self._end - 3, self._data_start)
                    return
            elif c == UInt8(ord("!")):
                if dash_count >= 2:
                    c = self._read_byte()
                    if self._err:
                        self._data_end = self._end
                        return
                    elif c == UInt8(ord(">")):
                        self._data_end = max(self._end - 4, self._data_start)
                        return
                    elif c == UInt8(ord("-")):
                        dash_count = 1
                        beginning = False
                        continue
            dash_count = 0
            beginning = False

    def _read_until_close_angle(mut self):
        self._data_start = self._end
        while True:
            var c = self._read_byte()
            if self._err:
                self._data_end = self._end
                return
            if c == UInt8(ord(">")):
                self._data_end = self._end - 1
                return

    def _read_markup_declaration(mut self) -> Int:
        self._data_start = self._end
        var c0 = self._read_byte()
        if self._err:
            self._data_end = self._end
            return TOKEN_COMMENT
        var c1 = self._read_byte()
        if self._err:
            self._data_end = self._end
            return TOKEN_COMMENT
        if c0 == UInt8(ord("-")) and c1 == UInt8(ord("-")):
            self._read_comment()
            return TOKEN_COMMENT
        self._end -= 2
        if self._read_doctype():
            return TOKEN_DOCTYPE
        self._read_until_close_angle()
        return TOKEN_COMMENT

    def _read_doctype(mut self) -> Bool:
        var s = "DOCTYPE".as_bytes()
        for i in range(len(s)):
            var c = self._read_byte()
            if self._err:
                self._data_end = self._end
                return False
            if c != s[i] and c != s[i] + (UInt8(ord("a")) - UInt8(ord("A"))):
                self._end = self._data_start
                return False
        self._skip_white_space()
        if self._err:
            self._data_start = self._end
            self._data_end = self._end
            return True
        self._read_until_close_angle()
        return True

    def _start_tag_is(self, s: StringSlice) -> Bool:
        var b = s.as_bytes()
        if self._data_end - self._data_start != len(b):
            return False
        for i in range(len(b)):
            var c = self._buf[self._data_start + i]
            if c >= UInt8(ord("A")) and c <= UInt8(ord("Z")):
                c += UInt8(ord("a")) - UInt8(ord("A"))
            if c != b[i]:
                return False
        return True

    def _read_start_tag(mut self) -> Int:
        self._read_tag()
        if self._err:
            return TOKEN_ERROR
        for name in [
            "iframe",
            "noembed",
            "noframes",
            "noscript",
            "plaintext",
            "script",
            "style",
            "textarea",
            "title",
            "xmp",
        ]:
            if self._start_tag_is(name):
                self._raw_tag = String(name)
                break
        if self._buf[self._end - 2] == UInt8(ord("/")) and (
            self._n_attrs == 0 or self._end - 2 != self._last_attr_end - 1
        ):
            return TOKEN_SELF_CLOSING_TAG
        return TOKEN_START_TAG

    def _read_tag(mut self):
        self._n_attrs = 0
        self._read_tag_name()
        self._skip_white_space()
        if self._err:
            return
        while True:
            var c = self._read_byte()
            if self._err or c == UInt8(ord(">")):
                break
            self._end -= 1
            var key = self._read_tag_attr_key()
            var val_end = self._read_tag_attr_val()
            if key[0] != key[1]:
                self._n_attrs += 1
                self._last_attr_end = val_end
            self._skip_white_space()
            if self._err:
                break

    def _read_tag_name(mut self):
        self._data_start = self._end - 1
        while True:
            var c = self._read_byte()
            if self._err:
                self._data_end = self._end
                return
            if _is_space(c):
                self._data_end = self._end - 1
                return
            if c == UInt8(ord("/")) or c == UInt8(ord(">")):
                self._end -= 1
                self._data_end = self._end
                return

    def _read_tag_attr_key(mut self) -> Tuple[Int, Int]:
        var start = self._end
        while True:
            var c = self._read_byte()
            if self._err:
                return (start, self._end)
            if c == UInt8(ord("=")) and start + 1 == self._end:
                continue
            if (
                c == UInt8(ord("="))
                or _is_space(c)
                or c == UInt8(ord("/"))
                or c == UInt8(ord(">"))
            ):
                self._end -= 1
                return (start, self._end)

    def _read_tag_attr_val(mut self) -> Int:
        # Returns the end of the value (Go pendingAttr[1].end).
        var end = self._end
        self._skip_white_space()
        if self._err:
            return end
        var c = self._read_byte()
        if self._err:
            return end
        if c == UInt8(ord("/")):
            return end
        if c != UInt8(ord("=")):
            self._end -= 1
            return end
        self._skip_white_space()
        if self._err:
            return end
        var quote = self._read_byte()
        if self._err:
            return end
        if quote == UInt8(ord(">")):
            self._end -= 1
            return end
        if quote == UInt8(ord("'")) or quote == UInt8(ord('"')):
            while True:
                c = self._read_byte()
                if self._err:
                    return self._end
                if c == quote:
                    return self._end - 1
        while True:
            c = self._read_byte()
            if self._err:
                return self._end
            if _is_space(c):
                return self._end - 1
            if c == UInt8(ord(">")):
                self._end -= 1
                return self._end

    def token(mut self) -> Token:
        """Returns the current token (Go `Token`): text unescaped, tag names
        lower-cased."""
        if (
            self._tt == TOKEN_TEXT
            or self._tt == TOKEN_COMMENT
            or self._tt == TOKEN_DOCTYPE
        ):
            var s = List[UInt8](
                Span(self._buf)[self._data_start : self._data_end]
            )
            s = _convert_newlines(s)
            if self._convert_nul or self._tt == TOKEN_COMMENT:
                s = _replace_nul(s)
            if not self._text_is_raw:
                s = unescape(s)
            return Token(self._tt, String(from_utf8_lossy=s))
        if (
            self._tt == TOKEN_START_TAG
            or self._tt == TOKEN_END_TAG
            or self._tt == TOKEN_SELF_CLOSING_TAG
        ):
            var s = List[UInt8](
                Span(self._buf)[self._data_start : self._data_end]
            )
            for ref c in s:
                if c >= UInt8(ord("A")) and c <= UInt8(ord("Z")):
                    c += UInt8(ord("a")) - UInt8(ord("A"))
            return Token(self._tt, String(from_utf8_lossy=s))
        return Token(self._tt, String())


def _convert_newlines(s: List[UInt8]) -> List[UInt8]:
    var out = List[UInt8](capacity=len(s))
    var i = 0
    while i < len(s):
        if s[i] == UInt8(ord("\r")):
            out.append(UInt8(ord("\n")))
            if i + 1 < len(s) and s[i + 1] == UInt8(ord("\n")):
                i += 1
        else:
            out.append(s[i])
        i += 1
    return out^


def _replace_nul(s: List[UInt8]) -> List[UInt8]:
    var out = List[UInt8](capacity=len(s))
    for c in s:
        if c == 0:
            out.extend("�".as_bytes())
        else:
            out.append(c)
    return out^


def _put_rune(mut out: List[UInt8], r: Int):
    if r < 0x80:
        out.append(UInt8(r))
    elif r < 0x800:
        out.append(UInt8(0xC0 | (r >> 6)))
        out.append(UInt8(0x80 | (r & 0x3F)))
    elif r < 0x10000:
        out.append(UInt8(0xE0 | (r >> 12)))
        out.append(UInt8(0x80 | ((r >> 6) & 0x3F)))
        out.append(UInt8(0x80 | (r & 0x3F)))
    else:
        out.append(UInt8(0xF0 | (r >> 18)))
        out.append(UInt8(0x80 | ((r >> 12) & 0x3F)))
        out.append(UInt8(0x80 | ((r >> 6) & 0x3F)))
        out.append(UInt8(0x80 | (r & 0x3F)))


def _replacement(i: Int) -> Int:
    # Go replacementTable: Windows-1252 for references 0x80 to 0x9F.
    var table: List[Int] = [
        0x20AC,
        0x0081,
        0x201A,
        0x0192,
        0x201E,
        0x2026,
        0x2020,
        0x2021,
        0x02C6,
        0x2030,
        0x0160,
        0x2039,
        0x0152,
        0x008D,
        0x017D,
        0x008F,
        0x0090,
        0x2018,
        0x2019,
        0x201C,
        0x201D,
        0x2022,
        0x2013,
        0x2014,
        0x02DC,
        0x2122,
        0x0161,
        0x203A,
        0x0153,
        0x009D,
        0x017E,
        0x0178,
    ]
    return table[i]


comptime _LONGEST_ENTITY_WITHOUT_SEMICOLON = 6


def _is_alnum(c: UInt8) -> Bool:
    return _is_alpha(c) or (c >= UInt8(ord("0")) and c <= UInt8(ord("9")))


def _unescape_entity(s: List[UInt8], src: Int, mut out: List[UInt8]) -> Int:
    # Go unescapeEntity for text (attribute false): appends the decoded
    # reference starting at s[src] == '&' and returns the new source index.
    var n = len(s) - src
    if n <= 1:
        out.append(s[src])
        return src + 1
    var i = 1
    if s[src + 1] == UInt8(ord("#")):
        if n <= 3:
            out.append(s[src])
            return src + 1
        i += 1
        var c = s[src + i]
        var hex = False
        if c == UInt8(ord("x")) or c == UInt8(ord("X")):
            hex = True
            i += 1
        var x = Int32(0)  # Go's rune arithmetic wraps
        while i < n:
            c = s[src + i]
            i += 1
            if hex:
                if c >= UInt8(ord("0")) and c <= UInt8(ord("9")):
                    x = 16 * x + Int32(c) - Int32(ord("0"))
                    continue
                elif c >= UInt8(ord("a")) and c <= UInt8(ord("f")):
                    x = 16 * x + Int32(c) - Int32(ord("a")) + 10
                    continue
                elif c >= UInt8(ord("A")) and c <= UInt8(ord("F")):
                    x = 16 * x + Int32(c) - Int32(ord("A")) + 10
                    continue
            elif c >= UInt8(ord("0")) and c <= UInt8(ord("9")):
                x = 10 * x + Int32(c) - Int32(ord("0"))
                continue
            if c != UInt8(ord(";")):
                i -= 1
            break
        if i <= 3:
            out.append(s[src])
            return src + 1
        var r = Int(x)
        if r >= 0x80 and r <= 0x9F:
            r = _replacement(r - 0x80)
        elif r <= 0 or (r >= 0xD800 and r <= 0xDFFF) or r > 0x10FFFF:
            # Zero and invalid runes (negative after wrapping too, as Go's
            # EncodeRune writes them) become U+FFFD.
            r = 0xFFFD
        _put_rune(out, r)
        return src + i
    while i < n:
        var c = s[src + i]
        i += 1
        if _is_alnum(c):
            continue
        if c != UInt8(ord(";")):
            i -= 1
        break
    var name = String(from_utf8_lossy=Span(s)[src + 1 : src + i])
    if name.byte_length() > 0:
        if case .Some(runes) = entity_lookup(name):
            for r in runes:
                _put_rune(out, r)
            return src + i
        var max_len = min(
            name.byte_length() - 1, _LONGEST_ENTITY_WITHOUT_SEMICOLON
        )
        var j = max_len
        while j > 1:
            if case .Some(runes) = entity_lookup(String(name[byte=:j])):
                if len(runes) == 1:
                    _put_rune(out, runes[0])
                    return src + j + 1
            j -= 1
    for k in range(i):
        out.append(s[src + k])
    return src + i


def unescape(s: List[UInt8]) -> List[UInt8]:
    """Decodes the character references in text (Go `unescape(b, false)`)."""
    var out = List[UInt8](capacity=len(s))
    var i = 0
    while i < len(s):
        if s[i] == UInt8(ord("&")):
            i = _unescape_entity(s, i, out)
        else:
            out.append(s[i])
            i += 1
    return out^
