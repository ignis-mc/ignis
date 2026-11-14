"""Lenient NBT reads, ported from Dragonfly `server/internal/nbtconv/read.go`.

Go reads `m[k].(T)` and takes the zero value when the key is missing or
holds another type; these do the same on a compound of a `Tree`.
`TickDuration` returns milliseconds.
"""

from minecraft.nbt.nbt import (
    TAG_BYTE,
    TAG_DOUBLE,
    TAG_FLOAT,
    TAG_INT,
    TAG_LIST,
    TAG_LONG,
    TAG_SHORT,
    TAG_STRING,
)
from minecraft.nbt.tree import Tag, Tree


def _entry(data: Tree, t: Tag, key: StringSpan, tag: UInt8) -> Optional[Tag]:
    if case .Some(e) = data.get(t, key):
        try:
            if data.type_of(e) == tag:
                return e
        except:
            pass
    return None


def get_bool(data: Tree, t: Tag, key: StringSpan) -> Bool:
    """Reads a byte at `key` and reports whether it is 1 (Go `Bool`)."""
    return get_uint8(data, t, key) == 1


def get_uint8(data: Tree, t: Tag, key: StringSpan) -> UInt8:
    """Reads a byte at `key`, 0 if absent (Go `Uint8`)."""
    if case .Some(e) = _entry(data, t, key, TAG_BYTE):
        try:
            return data.as_byte(e)
        except:
            pass
    return 0


def get_string(data: Tree, t: Tag, key: StringSpan) -> String:
    """Reads a string at `key`, empty if absent (Go `String`)."""
    if case .Some(e) = _entry(data, t, key, TAG_STRING):
        try:
            return data.as_string(e)
        except:
            pass
    return String()


def get_int16(data: Tree, t: Tag, key: StringSpan) -> Int16:
    """Reads a short at `key`, 0 if absent (Go `Int16`)."""
    if case .Some(e) = _entry(data, t, key, TAG_SHORT):
        try:
            return data.as_short(e)
        except:
            pass
    return 0


def get_int32(data: Tree, t: Tag, key: StringSpan) -> Int32:
    """Reads an int at `key`, 0 if absent (Go `Int32`)."""
    if case .Some(e) = _entry(data, t, key, TAG_INT):
        try:
            return data.as_int(e)
        except:
            pass
    return 0


def get_int64(data: Tree, t: Tag, key: StringSpan) -> Int64:
    """Reads a long at `key`, 0 if absent (Go `Int64`)."""
    if case .Some(e) = _entry(data, t, key, TAG_LONG):
        try:
            return data.as_long(e)
        except:
            pass
    return 0


def get_float32(data: Tree, t: Tag, key: StringSpan) -> Float32:
    """Reads a float at `key`, 0 if absent (Go `Float32`)."""
    if case .Some(e) = _entry(data, t, key, TAG_FLOAT):
        try:
            return data.as_float(e)
        except:
            pass
    return 0


def get_float64(data: Tree, t: Tag, key: StringSpan) -> Float64:
    """Reads a double at `key`, 0 if absent (Go `Float64`)."""
    if case .Some(e) = _entry(data, t, key, TAG_DOUBLE):
        try:
            return data.as_double(e)
        except:
            pass
    return 0


def get_slice(data: Tree, t: Tag, key: StringSpan) -> Optional[Tag]:
    """Returns the list at `key`, None if absent (Go `Slice` returning nil)."""
    return _entry(data, t, key, TAG_LIST)


def tick_duration_int16(data: Tree, t: Tag, key: StringSpan) -> Int:
    """Reads a short tick count at `key` as milliseconds (Go
    `TickDuration[int16]`)."""
    return Int(get_int16(data, t, key)) * 50
