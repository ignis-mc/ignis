"""The network block hash, ported from Dragonfly
`server/world/network_block_hash.go`.

The hash is FNV-1a (32 bits) of the state written as little-endian NBT with
an empty root name: `{name: string, states: {...}}`, properties in key order.
Clients that are told to use hashed block network IDs identify blocks by it.
"""

from minecraft.nbt.nbt import TAG_BYTE, TAG_COMPOUND, TAG_INT, TAG_STRING

from ..internal.fnv import fnv1a_32
from .block_state import Properties

comptime UNKNOWN_BLOCK_HASH: UInt32 = 0xFFFFFFFE
"""The hash of `minecraft:unknown` (-2 as an int32)."""


def _put_string(mut data: List[UInt8], s: StringSlice):
    var n = s.byte_length()
    data.append(UInt8(n & 0xFF))
    data.append(UInt8((n >> 8) & 0xFF))
    data.extend(s.as_bytes())


def network_block_hash(
    name: StringSlice, properties: Properties, mut scratch: List[UInt8]
) -> UInt32:
    """Returns the network block hash of a block state."""
    if name == "minecraft:unknown":
        return UNKNOWN_BLOCK_HASH
    scratch.clear()
    scratch.append(TAG_COMPOUND)
    scratch.append(0)
    scratch.append(0)

    scratch.append(TAG_STRING)
    _put_string(scratch, "name")
    _put_string(scratch, name)

    scratch.append(TAG_COMPOUND)
    _put_string(scratch, "states")
    for ref p in properties.entries:
        scratch.append(p.value.tag)
        _put_string(scratch, p.key)
        if p.value.tag == TAG_STRING:
            _put_string(scratch, p.value.string)
        elif p.value.tag == TAG_INT:
            var v = UInt32(p.value.int)
            for i in range(4):
                scratch.append(UInt8((v >> UInt32(8 * i)) & 0xFF))
        else:
            scratch.append(UInt8(p.value.int))
    scratch.append(0)
    scratch.append(0)
    return fnv1a_32(Span(scratch))
