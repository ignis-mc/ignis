"""Internal keys and the bytewise comparator, ported from goleveldb
`key.go`, `comparer.go` and `comparer/bytes_comparer.go`.

An internal key is the user key followed by 8 little-endian bytes holding
`seq << 8 | type`. Internal keys sort by user key ascending, then by that
number descending, so the newest version of a key comes first.
"""

from .util import compare_bytes, get_u64, put_u64

comptime KEY_TYPE_DEL: UInt8 = 0
"""The type of a deletion marker (Go `keyTypeDel`)."""
comptime KEY_TYPE_VAL: UInt8 = 1
"""The type of a value (Go `keyTypeVal`)."""
comptime KEY_MAX_SEQ: UInt64 = (UInt64(1) << 56) - 1
"""The largest sequence number (Go `keyMaxSeq`)."""
comptime KEY_MAX_NUM: UInt64 = (KEY_MAX_SEQ << 8) | UInt64(KEY_TYPE_VAL)
"""The largest packed number, used for seeking (Go `keyMaxNum`)."""
comptime COMPARER_NAME = "leveldb.BytewiseComparator"
"""The comparator name recorded in the manifest."""


def make_internal_key(
    mut out: List[UInt8], ukey: Span[UInt8, _], seq: UInt64, kt: UInt8
):
    """Appends an internal key (Go `makeInternalKey`).

    Args:
        out: The destination.
        ukey: The user key.
        seq: The sequence number, at most `KEY_MAX_SEQ`.
        kt: `KEY_TYPE_DEL` or `KEY_TYPE_VAL`.
    """
    out.extend(ukey)
    put_u64(out, (seq << 8) | UInt64(kt))


def internal_key(ukey: Span[UInt8, _], seq: UInt64, kt: UInt8) -> List[UInt8]:
    """Builds an internal key.

    Args:
        ukey: The user key.
        seq: The sequence number.
        kt: The key type.

    Returns:
        The internal key.
    """
    var out = List[UInt8](capacity=len(ukey) + 8)
    make_internal_key(out, ukey, seq, kt)
    return out^


def ukey(ikey: Span[UInt8, _]) -> Span[UInt8, ikey.origin]:
    """Returns the user key part of an internal key.

    Args:
        ikey: The internal key, at least 8 bytes.

    Returns:
        A view of the user key.
    """
    return ikey[: len(ikey) - 8]


def key_num(ikey: Span[UInt8, _]) -> UInt64:
    """Returns the packed `seq << 8 | type` of an internal key.

    Args:
        ikey: The internal key, at least 8 bytes.

    Returns:
        The packed number.
    """
    return get_u64(ikey, len(ikey) - 8)


def key_seq(ikey: Span[UInt8, _]) -> UInt64:
    """Returns the sequence number of an internal key.

    Args:
        ikey: The internal key.

    Returns:
        The sequence number.
    """
    return key_num(ikey) >> 8


def key_type(ikey: Span[UInt8, _]) -> UInt8:
    """Returns the type byte of an internal key.

    Args:
        ikey: The internal key.

    Returns:
        `KEY_TYPE_DEL` or `KEY_TYPE_VAL` (other values mean corruption).
    """
    return ikey[len(ikey) - 8]


def valid_internal_key(ikey: Span[UInt8, _]) -> Bool:
    """Reports whether bytes form a well-formed internal key.

    Args:
        ikey: The bytes.

    Returns:
        True if at least 8 bytes long with a known type.
    """
    return len(ikey) >= 8 and key_type(ikey) <= KEY_TYPE_VAL


def compare_internal(a: Span[UInt8, _], b: Span[UInt8, _]) -> Int:
    """Compares internal keys (Go `iComparer.Compare`).

    Args:
        a: The first key.
        b: The second key.

    Returns:
        -1, 0 or 1.
    """
    var x = compare_bytes(ukey(a), ukey(b))
    if x != 0:
        return x
    var m = key_num(a)
    var n = key_num(b)
    if m > n:
        return -1
    if m < n:
        return 1
    return 0


def separator(a: Span[UInt8, _], b: Span[UInt8, _]) -> Optional[List[UInt8]]:
    """A short internal key in `[a, b)` (Go `iComparer.Separator` over
    `bytesComparer.Separator`), or None to use `a` itself.

    Args:
        a: The last key of a block.
        b: The first key of the next block.

    Returns:
        The separator, or None.
    """
    var ua = ukey(a)
    var ub = ukey(b)
    var n = min(len(ua), len(ub))
    var i = 0
    while i < n and ua[i] == ub[i]:
        i += 1
    if i >= n:
        return None
    var c = ua[i]
    if c < 0xFF and c + 1 < ub[i]:
        var dst = List[UInt8](ua[: i + 1])
        dst[i] += 1
        if len(dst) < len(ua) and compare_bytes(ua, dst) < 0:
            put_u64(dst, KEY_MAX_NUM)
            return dst^
    return None


def successor(b: Span[UInt8, _]) -> Optional[List[UInt8]]:
    """A short internal key not less than `b` (Go `iComparer.Successor`), or
    None to use `b` itself.

    Args:
        b: The last key of a table.

    Returns:
        The successor, or None.
    """
    var ub = ukey(b)
    for i in range(len(ub)):
        if ub[i] != 0xFF:
            var dst = List[UInt8](ub[: i + 1])
            dst[i] += 1
            if len(dst) < len(ub) and compare_bytes(ub, dst) < 0:
                put_u64(dst, KEY_MAX_NUM)
                return dst^
            return None
    return None
