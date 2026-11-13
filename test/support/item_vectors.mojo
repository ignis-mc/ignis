"""The vectors `interop/items/main.go` wrote, and its canonical NBT text form
rebuilt on a `Tree`."""

from minecraft.nbt.nbt import (
    TAG_BYTE,
    TAG_BYTE_ARRAY,
    TAG_COMPOUND,
    TAG_DOUBLE,
    TAG_FLOAT,
    TAG_INT,
    TAG_INT_ARRAY,
    TAG_LIST,
    TAG_LONG,
    TAG_LONG_ARRAY,
    TAG_SHORT,
    TAG_STRING,
)
from minecraft.nbt.tree import Tag, Tree
from nethernet.wire import hex_encode
from std.collections import Dict
from std.memory import bitcast


def load_item_vectors() raises -> Dict[String, String]:
    var out = Dict[String, String]()
    with open("test/data/items/vectors.txt", "r") as f:
        for line in f.read().split("\n"):
            if line.byte_length() == 0:
                continue
            var parts = line.split(" ", 1)
            out[String(parts[0])] = String(parts[1])
    return out^


def _hex_fixed(v: UInt64, digits: Int) -> String:
    var out = String()
    for i in range(digits):
        var nib = Int((v >> UInt64(4 * (digits - 1 - i))) & 0xF)
        out += String("0123456789abcdef"[byte=nib])
    return out


def _hex_str(t: Tree, s: Tag) raises -> String:
    var b = t.as_string_bytes(s)
    return "x" + hex_encode(Span(b))


def canonical(t: Tree, tag: Tag) raises -> String:
    """Go `canonical` in `interop/items/main.go`."""
    var ty = t.type_of(tag)
    if ty == TAG_BYTE:
        return "b" + String(t.as_byte(tag))
    if ty == TAG_SHORT:
        return "s" + String(t.as_short(tag))
    if ty == TAG_INT:
        return "i" + String(t.as_int(tag))
    if ty == TAG_LONG:
        return "l" + String(t.as_long(tag))
    if ty == TAG_FLOAT:
        return "f" + _hex_fixed(
            UInt64(bitcast[DType.uint32](t.as_float(tag))), 8
        )
    if ty == TAG_DOUBLE:
        return "d" + _hex_fixed(bitcast[DType.uint64](t.as_double(tag)), 16)
    if ty == TAG_STRING:
        return _hex_str(t, tag)
    if ty == TAG_LIST:
        var parts = List[String]()
        for c in t.children(tag):
            parts.append(canonical(t, c))
        return "[" + ",".join(parts) + "]"
    if ty == TAG_COMPOUND:
        # Sort by key alone: a key that is a prefix of another sorts first,
        # which sorting whole "key=value" strings would not guarantee.
        var children = t.children(tag)
        var keys = List[String]()
        for c in children:
            keys.append("x" + hex_encode(t.name(c).as_bytes()))
        var sorted_keys = keys.copy()
        sort(sorted_keys)
        var parts = List[String]()
        for k in sorted_keys:
            for i in range(len(keys)):
                if keys[i] == k:
                    parts.append(k + "=" + canonical(t, children[i]))
        return "{" + ",".join(parts) + "}"
    if ty == TAG_BYTE_ARRAY:
        var parts = List[String]()
        for b in t.as_byte_array(tag):
            parts.append(String(b))
        return "B[" + ",".join(parts) + "]"
    if ty == TAG_INT_ARRAY:
        var parts = List[String]()
        for v in t.as_int_array(tag):
            parts.append(String(v))
        return "I[" + ",".join(parts) + "]"
    if ty == TAG_LONG_ARRAY:
        var parts = List[String]()
        for v in t.as_long_array(tag):
            parts.append(String(v))
        return "L[" + ",".join(parts) + "]"
    raise Error(t"canonical: tag type {ty}")
