"""Formatting helpers, ported from gophertunnel `minecraft/text/colour.go`."""

from .html import (
    TOKEN_END_TAG,
    TOKEN_ERROR,
    TOKEN_START_TAG,
    TOKEN_TEXT,
    Tokenizer,
)
from .map import RESET, ansi_code, tag_format


def clean(s: StringSlice) -> String:
    """Removes every formatting code (`§` and one of 0-9, a-v) from a string
    (Go `Clean`)."""
    var b = s.as_bytes()
    var out = List[UInt8](capacity=len(b))
    var i = 0
    while i < len(b):
        if (
            i + 2 < len(b)
            and b[i] == 0xC2
            and b[i + 1] == 0xA7
            and (
                (b[i + 2] >= UInt8(ord("0")) and b[i + 2] <= UInt8(ord("9")))
                or (b[i + 2] >= UInt8(ord("a")) and b[i + 2] <= UInt8(ord("v")))
            )
        ):
            i += 3
            continue
        out.append(b[i])
        i += 1
    return String(unsafe_from_utf8=out)


def ansi(s: StringSlice) -> String:
    """Replaces Minecraft formatting codes with ANSI escapes for a terminal
    (Go `ANSI`)."""
    var b = s.as_bytes()
    var out = List[UInt8](capacity=len(b))
    var i = 0
    while i < len(b):
        if i + 2 < len(b) and b[i] == 0xC2 and b[i + 1] == 0xA7:
            if case .Some(code) = ansi_code(b[i + 2]):
                out.extend(code.as_bytes())
                i += 3
                continue
        out.append(b[i])
        i += 1
    return String(unsafe_from_utf8=out)


def sprintf(format: StringSlice, args: List[String]) -> String:
    """Substitutes arguments, already converted to strings, into a format
    as Go's `fmt.Sprintf` does for `%v`, `%s`, `%d` and `%%`; other verbs
    and flags are not supported."""
    var b = format.as_bytes()
    var out = String()
    var start = 0
    var arg = 0
    var i = 0
    while i < len(b):
        if b[i] != UInt8(ord("%")):
            i += 1
            continue
        out += String(unsafe_from_utf8=b[start:i])
        if i + 1 >= len(b):
            out += "%!(NOVERB)"
            i += 1
            start = i
            break
        var verb = b[i + 1]
        i += 2
        start = i
        if verb == UInt8(ord("%")):
            out += "%"
            continue
        if arg >= len(args):
            out += "%!"
            out += chr(Int(verb))
            out += "(MISSING)"
            continue
        if (
            verb == UInt8(ord("v"))
            or verb == UInt8(ord("s"))
            or verb == UInt8(ord("d"))
        ):
            out += args[arg]
        else:
            out += "%!"
            out += chr(Int(verb))
            out += "(string="
            out += args[arg]
            out += ")"
        arg += 1
    if start < len(b):
        out += String(unsafe_from_utf8=b[start:])
    if arg < len(args):
        out += "%!(EXTRA "
        for j in range(arg, len(args)):
            if j > arg:
                out += ", "
            out += "string="
            out += args[j]
        out += ")"
    return out^


def colourf(format: StringSlice, args: List[String] = []) -> String:
    """Colours a format string using HTML-like tags such as `<red>` and
    `<bold>` after substituting the arguments (Go `Colourf`)."""
    var s = sprintf(format, args)
    var out = String()
    var stack = List[String]()
    var first = True
    var t = Tokenizer(s)
    while t.next() != TOKEN_ERROR:
        var tok = t.token()
        if first:
            out += RESET
            first = False
        if tok.type == TOKEN_TEXT:
            _write_text(out, stack, tok.data)
        elif tok.type == TOKEN_START_TAG:
            var f = tag_format(tok.data)
            if f.byte_length() > 0:
                stack.append(f^)
                continue
            _write_text(out, stack, String(t"<{tok.data}>"))
        elif tok.type == TOKEN_END_TAG:
            var removed = False
            var f = tag_format(tok.data)
            if f.byte_length() > 0:
                for i in range(len(stack)):
                    if stack[i] == f:
                        _ = stack.pop(i)
                        removed = True
                        break
            if not removed:
                _write_text(out, stack, String(t"</{tok.data}>"))
    return out^


def _write_text(mut out: String, stack: List[String], s: String):
    for f in stack:
        out += f
    out += s
    if len(stack) != 0:
        out += RESET
