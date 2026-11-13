"""The command line and argument parsing (Dragonfly `server/cmd/argument.go`).

Go's `parser.parseArgument` switches on the dynamic type of a struct field;
`_parse_argument` does the same switch on the field's static type at
compile time. Numbers follow Go's `strconv` grammar exactly (underscores
between digits and hexadecimal mantissas in floats, no sign on unsigned
integers, range checks for the field's bit size), and arguments are split
by a port of `encoding/csv` with `Comma = ' '` and `LazyQuotes`, so quoting
and repeated spaces behave as in Dragonfly.

Differences from Dragonfly, all deliberate:

- `@p` picks the player nearest to the source. Dragonfly sorts the players
  while comparing distances by their old indices, so it can pick any
  player.
- `@r` draws from `getrandom`, not Go's `math/rand`.
- Names are compared case-insensitively with ASCII folding, plus Mojo's
  `lower()` for non-ASCII text (Go uses Unicode simple folding).
- A decimal `Float32` is rounded through `Float64`; Go rounds directly to
  32 bits. The results differ only for decimals within a rounding error of
  a halfway point between two `Float32` values.
"""

from std.builtin.rebind import downcast
from std.memory import bitcast

from nethernet.os.random import random_u64

from ..mgl64 import Vec3
from .output import (
    MESSAGE_BOOLEAN_INVALID,
    MESSAGE_NO_TARGETS,
    MESSAGE_NUMBER_INVALID,
    MESSAGE_PARAMETER_INVALID,
    MESSAGE_PLAYER_NOT_FOUND,
    MESSAGE_SYNTAX,
    MESSAGE_USAGE,
    Message,
)
from .parameter import Enum, Parameter, SubCommand, Varargs
from .source import Source
from .target import Target, TargetProvider


struct Line(Copyable, Defaultable):
    """The arguments of a command being parsed (Go `cmd.Line`)."""

    var _args: List[String]
    var _seen: List[String]
    var _usage: String

    def __init__(out self):
        """Creates an empty line."""
        self._args = List[String]()
        self._seen = List[String]()
        self._usage = String()

    def __init__(
        out self,
        var args: List[String],
        var seen: List[String],
        var usage: String,
    ):
        """Creates a line.

        Args:
            args: The arguments still to parse.
            seen: The words already parsed, starting with `/name`.
            usage: The command usage, for `usage_error`.
        """
        self._args = args^
        self._seen = seen^
        self._usage = usage^

    def syntax_error(self) -> Message:
        """Builds the syntax error pointing at the next argument (Go
        `SyntaxError`).

        Returns:
            The translated error.
        """
        if len(self._args) == 0:
            return MESSAGE_SYNTAX.f(_join(self._seen, 0), "", "")
        var next = _join(self._args, 1)
        if next.byte_length() > 0:
            next = " " + next
        return MESSAGE_SYNTAX.f(_join(self._seen, 0) + " ", self._args[0], next)

    def usage_error(self) -> Message:
        """Builds the usage error (Go `UsageError`).

        Returns:
            The translated error.
        """
        return MESSAGE_USAGE.f(self._usage)

    def next(self) -> Optional[String]:
        """Gets the next argument without consuming it (Go `Next`).

        Returns:
            The argument, or `None` if there are none left.
        """
        if len(self._args) == 0:
            return None
        return self._args[0]

    def next_n(self, n: Int) -> Optional[List[String]]:
        """Gets the next `n` arguments without consuming them (Go `NextN`).

        Args:
            n: How many arguments.

        Returns:
            The arguments, or `None` if fewer than `n` are left.
        """
        if len(self._args) < n:
            return None
        return List[String](Span(self._args)[:n])

    def remove_next(mut self):
        """Consumes the next argument (Go `RemoveNext`)."""
        self.remove_n(1)

    def remove_n(mut self, n: Int):
        """Consumes the next `n` arguments (Go `RemoveN`). If fewer are
        left, all of them are dropped without being marked as seen.

        Args:
            n: How many arguments.
        """
        if len(self._args) < n:
            self._args = List[String]()
            return
        for i in range(n):
            self._seen.append(self._args[i])
        self._args = List[String](Span(self._args)[n:])

    def leftover(mut self) -> List[String]:
        """Takes every remaining argument (Go `Leftover`).

        Returns:
            The arguments; the line is empty afterwards.
        """
        var v = self._args^
        self._args = List[String]()
        return v^

    def len(self) -> Int:
        """Counts the remaining arguments (Go `Len`).

        Returns:
            The count.
        """
        return len(self._args)


def _join(parts: List[String], start: Int) -> String:
    """Joins `parts[start:]` with spaces (Go `strings.Join(_, " ")`).

    Args:
        parts: The strings.
        start: The first index to include.

    Returns:
        The joined string.
    """
    var out = String()
    for i in range(start, len(parts)):
        if i > start:
            out += " "
        out += parts[i]
    return out^


# --- Splitting the command line (encoding/csv) -------------------------------


struct _LineReader:
    """Reads `\\n`-terminated lines like `encoding/csv`'s `readLine`."""

    var data: List[UInt8]
    var pos: Int

    def __init__(out self, data: Span[UInt8, _]):
        self.data = List[UInt8](data)
        self.pos = 0

    def read_line(mut self, mut line: List[UInt8]) -> Bool:
        """Reads the next line into `line`.

        Returns:
            True at end of input with nothing read (Go `io.EOF`).
        """
        line = List[UInt8]()
        var start = self.pos
        var end = start
        while end < len(self.data) and self.data[end] != UInt8(ord("\n")):
            end += 1
        var eof = end == len(self.data)
        if not eof:
            end += 1
        self.pos = end
        line = List[UInt8](Span(self.data)[start:end])
        if eof:
            if len(line) == 0:
                return True
            if line[len(line) - 1] == UInt8(ord("\r")):
                _ = line.pop()
        var n = len(line)
        if (
            n >= 2
            and line[n - 2] == UInt8(ord("\r"))
            and line[n - 1] == UInt8(ord("\n"))
        ):
            line[n - 2] = UInt8(ord("\n"))
            _ = line.pop()
        return False


def _length_nl(b: List[UInt8], start: Int) -> Int:
    """Go `lengthNL` on `b[start:]`: 1 if it ends in a newline."""
    if len(b) > start and b[len(b) - 1] == UInt8(ord("\n")):
        return 1
    return 0


def _index_of(b: List[UInt8], start: Int, c: UInt8) -> Int:
    """Finds `c` in `b[start:]`, returning its index in `b` or -1."""
    for i in range(start, len(b)):
        if b[i] == c:
            return i
    return -1


def split_args(args: String) -> Optional[List[String]]:
    """Splits a command line into arguments the way Dragonfly does: one
    record read by `encoding/csv` with `Comma = ' '` and `LazyQuotes`.

    Every space separates two arguments (so repeated spaces give empty
    arguments), `"..."` quotes an argument that may contain spaces and
    newlines, `""` inside quotes is a quote, and only the first line of
    unquoted text is read.

    Args:
        args: The arguments after the command name.

    Returns:
        The arguments, or `None` if there is no record (only newlines),
        which Go reports as an error.
    """
    comptime QUOTE = UInt8(ord('"'))
    comptime COMMA = UInt8(ord(" "))
    var r = _LineReader(args.as_bytes())
    var line = List[UInt8]()
    var eof: Bool
    while True:
        eof = r.read_line(line)
        if not eof and len(line) == _length_nl(line, 0):
            continue
        break
    if eof:
        return None

    var record = List[UInt8]()
    var ends = List[Int]()
    var at = 0
    while True:
        if at >= len(line) or line[at] != QUOTE:
            # Unquoted field.
            var i = _index_of(line, at, COMMA)
            var end = i if i >= 0 else len(line) - _length_nl(line, at)
            record.extend(Span(line)[at:end])
            ends.append(len(record))
            if i >= 0:
                at = i + 1
                continue
            break
        # Quoted field.
        at += 1
        var done = False
        while True:
            var i = _index_of(line, at, QUOTE)
            if i >= 0:
                record.extend(Span(line)[at:i])
                at = i + 1
                if at < len(line) and line[at] == QUOTE:
                    record.append(QUOTE)
                    at += 1
                elif at < len(line) and line[at] == COMMA:
                    at += 1
                    ends.append(len(record))
                    break
                elif _length_nl(line, at) == len(line) - at:
                    ends.append(len(record))
                    done = True
                    break
                else:
                    record.append(QUOTE)
            elif at < len(line):
                record.extend(Span(line)[at:])
                _ = r.read_line(line)
                at = 0
            else:
                ends.append(len(record))
                done = True
                break
        if done:
            break

    var out = List[String](capacity=len(ends))
    var prev = 0
    for e in ends:
        out.append(String(from_utf8_lossy=Span(record)[prev:e]))
        prev = e
    return out^


# --- Go strconv ---------------------------------------------------------------


def _lower(c: UInt8) -> UInt8:
    """Go `lower`: ASCII letters to lower case (other bytes are garbled,
    as in Go, but only compared against letters)."""
    return c | 0x20


def parse_uint(s: String, bits: Int) -> Optional[UInt64]:
    """Parses a decimal unsigned integer like Go's
    `strconv.ParseUint(s, 10, bits)`: digits only, no sign, no underscores.

    Args:
        s: The text.
        bits: The bit size, 8 to 64.

    Returns:
        The value, or `None` on a syntax or range error.
    """
    var b = s.as_bytes()
    if len(b) == 0:
        return None
    var max_val = UInt64.MAX if bits == 64 else (UInt64(1) << UInt64(bits)) - 1
    comptime CUTOFF = UInt64.MAX // 10 + 1
    var n = UInt64(0)
    for i in range(len(b)):
        var c = b[i]
        if c < UInt8(ord("0")) or c > UInt8(ord("9")):
            return None
        if n >= CUTOFF:
            return None
        n *= 10
        var n1 = n + UInt64(c - UInt8(ord("0")))
        if n1 < n or n1 > max_val:
            return None
        n = n1
    return n


def parse_int(s: String, bits: Int) -> Optional[Int64]:
    """Parses a decimal signed integer like Go's
    `strconv.ParseInt(s, 10, bits)`: an optional `+` or `-`, then digits.

    Args:
        s: The text.
        bits: The bit size, 8 to 64.

    Returns:
        The value, or `None` on a syntax or range error.
    """
    var b = s.as_bytes()
    if len(b) == 0:
        return None
    var neg = False
    var digits = s.copy()
    if b[0] == UInt8(ord("+")):
        digits = String(s[byte=1:])
    elif b[0] == UInt8(ord("-")):
        neg = True
        digits = String(s[byte=1:])
    var un = parse_uint(digits, bits)
    if not un:
        return None
    var u = un.value()
    var cutoff = UInt64(1) << UInt64(bits - 1)
    if not neg and u >= cutoff:
        return None
    if neg and u > cutoff:
        return None
    if neg:
        return Int64(0) - Int64(u)
    return Int64(u)


def parse_bool(s: String) -> Optional[Bool]:
    """Parses a boolean like Go's `strconv.ParseBool`.

    Args:
        s: The text: `1 t T TRUE true True` or `0 f F FALSE false False`.

    Returns:
        The value, or `None`.
    """
    if (
        s == "1"
        or s == "t"
        or s == "T"
        or s == "TRUE"
        or s == "true"
        or s == "True"
    ):
        return True
    if (
        s == "0"
        or s == "f"
        or s == "F"
        or s == "FALSE"
        or s == "false"
        or s == "False"
    ):
        return False
    return None


def _common_prefix_len_ignore_case(
    s: Span[UInt8, _], prefix: StaticString
) -> Int:
    var p = prefix.as_bytes()
    var n = min(len(p), len(s))
    for i in range(n):
        var c = s[i]
        if c >= UInt8(ord("A")) and c <= UInt8(ord("Z")):
            c += 32
        if c != p[i]:
            return i
    return n


comptime _GO_NAN_BITS: UInt64 = 0x7FF8000000000001
"""The bits of Go's `math.NaN()`."""


def parse_float(s: String, bits: Int) -> Optional[Float64]:
    """Parses a float like Go's `strconv.ParseFloat(s, bits)`.

    Accepts decimal and hexadecimal (`0x1p-2`) forms with underscores
    between digits, `inf`, `infinity` and `nan` in any case. A value that
    overflows the bit size is an error, as in Go; underflow gives zero.

    Args:
        s: The text.
        bits: 32 or 64.

    Returns:
        The value (already rounded to `Float32` when `bits` is 32), or
        `None` on a syntax or range error.
    """
    var b = s.as_bytes()
    if len(b) == 0:
        return None
    # Go `special`.
    var at = 0
    var sign = Float64(1)
    var c0 = b[0]
    if (
        c0 == UInt8(ord("+"))
        or c0 == UInt8(ord("-"))
        or _lower(c0) == UInt8(ord("i"))
    ):
        if c0 == UInt8(ord("-")):
            sign = -1
        if c0 == UInt8(ord("+")) or c0 == UInt8(ord("-")):
            at = 1
        var n = _common_prefix_len_ignore_case(b[at:], "infinity")
        if 3 < n and n < 8:
            n = 3
        if n == 3 or n == 8:
            if at + n != len(b):
                return None
            return sign * Float64.MAX_FINITE * 10
    elif _lower(c0) == UInt8(ord("n")):
        if _common_prefix_len_ignore_case(b, "nan") == 3:
            if len(b) != 3:
                return None
            var nan = bitcast[DType.float64](_GO_NAN_BITS)
            if bits == 32:
                return Float64(Float32(nan))
            return nan

    var rf = _read_float(b)
    if not rf.ok or rf.n != len(b):
        return None
    if rf.hex:
        return _atof_hex(rf.mantissa, rf.exp, rf.neg, rf.trunc, bits)
    if len(rf.digits) == 0:
        return -0.0 if rf.neg else 0.0
    # The decimal point sits `rf.dp` digits into `rf.digits`.
    if rf.dp > 310:
        return None
    var f: Float64
    if rf.dp < -330:
        f = 0
    else:
        var text = String(from_utf8_lossy=rf.digits)
        text += "e"
        text += String(rf.dp - len(rf.digits))
        try:
            f = atof(text)
        except:
            return None
    if rf.neg:
        f = -f
    if bits == 32:
        var f32 = Float32(f)
        if f32 == Float32.MAX_FINITE * 2 or f32 == -Float32.MAX_FINITE * 2:
            return None
        return Float64(f32)
    if f == Float64.MAX_FINITE * 2 or f == -Float64.MAX_FINITE * 2:
        return None
    return f


struct _ReadFloat(Movable):
    """The result of Go's `readFloat`, plus the significant decimal digits
    (Go's `decimal.set` keeps them for the slow path)."""

    var mantissa: UInt64
    var exp: Int
    var neg: Bool
    var trunc: Bool
    var hex: Bool
    var n: Int
    var ok: Bool
    var digits: List[UInt8]
    var dp: Int

    def __init__(out self):
        self.mantissa = 0
        self.exp = 0
        self.neg = False
        self.trunc = False
        self.hex = False
        self.n = 0
        self.ok = False
        self.digits = List[UInt8]()
        self.dp = 0


def _read_float(s: Span[UInt8, _]) -> _ReadFloat:
    """Go's `readFloat`: scans a decimal or hexadecimal float literal."""
    var r = _ReadFloat()
    var underscores = False
    var i = 0
    if i >= len(s):
        return r^
    if s[i] == UInt8(ord("+")):
        i += 1
    elif s[i] == UInt8(ord("-")):
        i += 1
        r.neg = True

    var base = UInt64(10)
    var max_mant_digits = 19
    var exp_char = UInt8(ord("e"))
    if (
        i + 2 < len(s)
        and s[i] == UInt8(ord("0"))
        and _lower(s[i + 1]) == UInt8(ord("x"))
    ):
        base = 16
        max_mant_digits = 16
        i += 2
        exp_char = UInt8(ord("p"))
        r.hex = True
    var sawdot = False
    var sawdigits = False
    var nd = 0
    var nd_mant = 0
    var dp = 0
    while i < len(s):
        var c = s[i]
        if c == UInt8(ord("_")):
            underscores = True
            i += 1
            continue
        if c == UInt8(ord(".")):
            if sawdot:
                break
            sawdot = True
            dp = nd
            i += 1
            continue
        if c >= UInt8(ord("0")) and c <= UInt8(ord("9")):
            sawdigits = True
            if c == UInt8(ord("0")) and nd == 0:
                dp -= 1
                i += 1
                continue
            nd += 1
            r.digits.append(c)
            if nd_mant < max_mant_digits:
                r.mantissa = r.mantissa * base + UInt64(c - UInt8(ord("0")))
                nd_mant += 1
            elif c != UInt8(ord("0")):
                r.trunc = True
            i += 1
            continue
        var lc = _lower(c)
        if base == 16 and lc >= UInt8(ord("a")) and lc <= UInt8(ord("f")):
            sawdigits = True
            nd += 1
            if nd_mant < max_mant_digits:
                r.mantissa = r.mantissa * 16 + UInt64(lc - UInt8(ord("a")) + 10)
                nd_mant += 1
            else:
                r.trunc = True
            i += 1
            continue
        break
    if not sawdigits:
        r.n = i
        return r^
    if not sawdot:
        dp = nd
    if base == 16:
        dp *= 4
        nd_mant *= 4

    if i < len(s) and _lower(s[i]) == exp_char:
        i += 1
        if i >= len(s):
            r.n = i
            return r^
        var esign = 1
        if s[i] == UInt8(ord("+")):
            i += 1
        elif s[i] == UInt8(ord("-")):
            i += 1
            esign = -1
        if i >= len(s) or s[i] < UInt8(ord("0")) or s[i] > UInt8(ord("9")):
            r.n = i
            return r^
        var e = 0
        while i < len(s) and (
            (s[i] >= UInt8(ord("0")) and s[i] <= UInt8(ord("9")))
            or s[i] == UInt8(ord("_"))
        ):
            if s[i] == UInt8(ord("_")):
                underscores = True
                i += 1
                continue
            if e < 10000:
                e = e * 10 + Int(s[i]) - ord("0")
            i += 1
        dp += e * esign
    elif base == 16:
        r.n = i
        return r^

    if r.mantissa != 0:
        r.exp = dp - nd_mant
    r.dp = dp
    r.n = i
    if underscores and not _underscore_ok(s[:i]):
        return r^
    r.ok = True
    return r^


def _underscore_ok(s_in: Span[UInt8, _]) -> Bool:
    """Go's `underscoreOK`: underscores only between digits (or after a
    base prefix)."""
    var s = s_in
    var saw = UInt8(ord("^"))
    var i = 0
    if len(s) >= 1 and (s[0] == UInt8(ord("-")) or s[0] == UInt8(ord("+"))):
        s = s[1:]
    var hex = False
    if len(s) >= 2 and s[0] == UInt8(ord("0")):
        var l = _lower(s[1])
        if l == UInt8(ord("b")) or l == UInt8(ord("o")) or l == UInt8(ord("x")):
            i = 2
            saw = UInt8(ord("0"))
            hex = l == UInt8(ord("x"))
    while i < len(s):
        var c = s[i]
        var lc = _lower(c)
        if (c >= UInt8(ord("0")) and c <= UInt8(ord("9"))) or (
            hex and lc >= UInt8(ord("a")) and lc <= UInt8(ord("f"))
        ):
            saw = UInt8(ord("0"))
            i += 1
            continue
        if c == UInt8(ord("_")):
            if saw != UInt8(ord("0")):
                return False
            saw = UInt8(ord("_"))
            i += 1
            continue
        if saw == UInt8(ord("_")):
            return False
        saw = UInt8(ord("!"))
        i += 1
    return saw != UInt8(ord("_"))


def _atof_hex(
    mantissa_in: UInt64, exp_in: Int, neg: Bool, trunc: Bool, bits: Int
) -> Optional[Float64]:
    """Go's `atofHex`: rounds a hexadecimal mantissa and binary exponent to
    a `Float64` or `Float32`."""
    var mantbits = 52 if bits == 64 else 23
    var expbits = 11 if bits == 64 else 8
    var bias = -1023 if bits == 64 else -127
    var max_exp = (1 << expbits) + bias - 2
    var min_exp = bias + 1
    var mantissa = mantissa_in
    var exp = exp_in + mantbits
    var mb = UInt64(mantbits)
    while mantissa != 0 and mantissa >> (mb + 2) == 0:
        mantissa <<= 1
        exp -= 1
    if trunc:
        mantissa |= 1
    while mantissa >> (1 + mb + 2) != 0:
        mantissa = (mantissa >> 1) | (mantissa & 1)
        exp += 1
    while mantissa > 1 and exp < min_exp - 2:
        mantissa = (mantissa >> 1) | (mantissa & 1)
        exp += 1
    var round = mantissa & 3
    mantissa >>= 2
    round |= mantissa & 1
    exp += 2
    if round == 3:
        mantissa += 1
        if mantissa == UInt64(1) << (1 + mb):
            mantissa >>= 1
            exp += 1
    if mantissa >> mb == 0:
        exp = bias
    if exp > max_exp:
        return None
    var out = mantissa & ((UInt64(1) << mb) - 1)
    out |= UInt64((exp - bias) & ((1 << expbits) - 1)) << mb
    if neg:
        out |= UInt64(1) << mb << UInt64(expbits)
    if bits == 32:
        return Float64(bitcast[DType.float32](UInt32(out)))
    return bitcast[DType.float64](out)


# --- Parsing parameters ---------------------------------------------------


def _equal_fold(a: String, b: String) -> Bool:
    """Compares case-insensitively (Go `strings.EqualFold`)."""
    var x = a.as_bytes()
    var y = b.as_bytes()
    var ascii = True
    for c in x:
        if c >= 0x80:
            ascii = False
    for c in y:
        if c >= 0x80:
            ascii = False
    if not ascii:
        return a.lower() == b.lower()
    if len(x) != len(y):
        return False
    for i in range(len(x)):
        var p = x[i]
        var q = y[i]
        if p >= UInt8(ord("A")) and p <= UInt8(ord("Z")):
            p += 32
        if q >= UInt8(ord("A")) and q <= UInt8(ord("Z")):
            q += 32
        if p != q:
            return False
    return True


def _next_or_usage(line: Line) raises Message -> String:
    var arg = line.next()
    if not arg:
        raise line.usage_error()
    return arg.value()


def _int_arg(line: Line, bits: Int) raises Message -> Int64:
    """Go `parser.int`."""
    var arg = _next_or_usage(line)
    var v = parse_int(arg, bits)
    if not v:
        raise MESSAGE_NUMBER_INVALID.f(arg)
    return v.value()


def _uint_arg(line: Line, bits: Int) raises Message -> UInt64:
    """Go `parser.uint`."""
    var arg = _next_or_usage(line)
    var v = parse_uint(arg, bits)
    if not v:
        raise MESSAGE_NUMBER_INVALID.f(arg)
    return v.value()


def _float_arg(line: Line, bits: Int) raises Message -> Float64:
    """Go `parser.float`."""
    var arg = _next_or_usage(line)
    var v = parse_float(arg, bits)
    if not v:
        raise MESSAGE_NUMBER_INVALID.f(arg)
    return v.value()


def _bool_arg(line: Line) raises Message -> Bool:
    """Go `parser.bool`."""
    var arg = _next_or_usage(line)
    var v = parse_bool(arg)
    if not v:
        raise MESSAGE_BOOLEAN_INVALID.f(arg)
    return v.value()


def _vec3_arg(mut line: Line) raises Message -> Vec3:
    """Go `parser.vec3`: three floats."""
    var v = Vec3()
    v.x = _float_arg(line, 64)
    line.remove_next()
    v.y = _float_arg(line, 64)
    line.remove_next()
    v.z = _float_arg(line, 64)
    return v


def _sub_arg(line: Line, name: StringSlice) raises Message:
    """Go `parser.sub`: the next argument must be the subcommand name."""
    var arg = _next_or_usage(line)
    if _equal_fold(String(name), arg):
        return
    raise MESSAGE_PARAMETER_INVALID.f(arg)


def _random_index(n: Int) -> Int:
    try:
        return Int(random_u64() % UInt64(n))
    except:
        return 0


def parse_targets[
    S: Source
](mut line: Line, src: S, tx: S.Tx) raises Message -> List[Target]:
    """Parses a target selector or player name (Go `parser.parseTargets`).

    Parameters:
        S: The source type.

    Args:
        line: The line; the selector is its next argument (not consumed).
        src: The source, for `@s` and `@p`.
        tx: The entities to select from.

    Returns:
        The selected targets, possibly none.

    Raises:
        Message: A usage error, `No targets matched selector` for a
            selector without a world, or `That player cannot be found`.
    """
    var first = _next_or_usage(line)
    var b = first.as_bytes()
    var selector = len(b) > 0 and b[0] == UInt8(ord("@"))
    if selector and not tx.attached():
        raise MESSAGE_NO_TARGETS.f()
    var kind = UInt8(0)
    if selector and len(b) >= 2:
        kind = b[1]
    var players = tx.players() if tx.attached() else List[Target]()
    var out = List[Target]()
    if kind == UInt8(ord("p")):
        var pos = src.position()
        var best = -1
        var best_dist = Float64(0)
        for i in range(len(players)):
            var d = players[i].position.sub(pos).len()
            if best < 0 or d < best_dist:
                best = i
                best_dist = d
        if best >= 0:
            out.append(players[best].copy())
    elif kind == UInt8(ord("e")):
        return tx.entities()
    elif kind == UInt8(ord("a")):
        return players^
    elif kind == UInt8(ord("s")):
        out.append(src.target())
    elif kind == UInt8(ord("r")):
        if len(players) > 0:
            out.append(players[_random_index(len(players))].copy())
    else:
        for p in players:
            if _equal_fold(p.name, first):
                out.append(p.copy())
                return out^
        raise MESSAGE_PLAYER_NOT_FOUND.f()
    return out^


def _is_supported[T: AnyType]() -> Bool:
    """Reports whether `T` is a parameter type `_parse_argument` handles."""
    return (
        T == Int8
        or T == Int16
        or T == Int32
        or T == Int64
        or T == Int
        or T == UInt8
        or T == UInt16
        or T == UInt32
        or T == UInt64
        or T == UInt
        or T == Float32
        or T == Float64
        or T == String
        or T == Bool
        or T == Vec3
        or T == Varargs
        or T == List[Target]
        or T == SubCommand
        or conforms_to(T, Parameter)
        or conforms_to(T, Enum)
    )


def _parse_argument[
    T: AnyType, S: Source
](
    mut line: Line,
    mut v: T,
    optional: Bool,
    name: StringSlice,
    src: S,
    tx: S.Tx,
) raises Message -> Bool:
    """Parses the next argument into `v` (Go `parser.parseArgument`).

    Parameters:
        T: The field type.
        S: The source type.

    Args:
        line: The line; the argument is consumed on success.
        v: The field.
        optional: Whether the parameter may be left out.
        name: The parameter name (for subcommands).
        src: The source.
        tx: The entities target selectors choose from.

    Returns:
        True if a value was parsed, False if an optional parameter was left
        out.

    Raises:
        Message: The parse error.
    """
    comptime assert _is_supported[
        T
    ](), "unsupported command parameter type; see ignis.cmd.parameter"
    if line.len() == 0 and optional:
        return False
    comptime if T == Int8:
        rebind[Int8](v) = Int8(_int_arg(line, 8))
    elif T == Int16:
        rebind[Int16](v) = Int16(_int_arg(line, 16))
    elif T == Int32:
        rebind[Int32](v) = Int32(_int_arg(line, 32))
    elif T == Int64:
        rebind[Int64](v) = _int_arg(line, 64)
    elif T == Int:
        rebind[Int](v) = Int(_int_arg(line, 64))
    elif T == UInt8:
        rebind[UInt8](v) = UInt8(_uint_arg(line, 8))
    elif T == UInt16:
        rebind[UInt16](v) = UInt16(_uint_arg(line, 16))
    elif T == UInt32:
        rebind[UInt32](v) = UInt32(_uint_arg(line, 32))
    elif T == UInt64:
        rebind[UInt64](v) = _uint_arg(line, 64)
    elif T == UInt:
        rebind[UInt](v) = UInt(_uint_arg(line, 64))
    elif T == Float32:
        rebind[Float32](v) = Float32(_float_arg(line, 32))
    elif T == Float64:
        rebind[Float64](v) = _float_arg(line, 64)
    elif T == String:
        rebind[String](v) = _next_or_usage(line)
    elif T == Bool:
        rebind[Bool](v) = _bool_arg(line)
    elif T == Vec3:
        rebind[Vec3](v) = _vec3_arg(line)
    elif T == Varargs:
        rebind[Varargs](v) = Varargs(_join(line.leftover(), 0))
    elif T == List[Target]:
        var targets = parse_targets(line, src, tx)
        if len(targets) == 0:
            raise MESSAGE_NO_TARGETS.f()
        rebind[List[Target]](v) = targets^
    elif T == SubCommand:
        _sub_arg(line, name)
    elif conforms_to(T, Parameter):
        rebind[downcast[T, Parameter]](v).parse(line)
    elif conforms_to(T, Enum):
        ref e = rebind[downcast[T, Enum]](v)
        var arg = _next_or_usage(line)
        var opts = e.options(src)
        var found = False
        for o in opts:
            if _equal_fold(o, arg):
                e.set_option(o)
                found = True
                break
        if not found:
            raise MESSAGE_PARAMETER_INVALID.f(arg)
    line.remove_next()
    return True
