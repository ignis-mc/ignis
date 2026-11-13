"""FNV-1 and FNV-1a hashes, as `github.com/segmentio/fasthash` computes them.

Dragonfly sorts block runtime IDs by `fnv1.HashString64` of the block name and
derives network block hashes with `fnv1a.HashBytes32`.
"""

comptime _OFFSET64: UInt64 = 14695981039346656037
comptime _PRIME64: UInt64 = 1099511628211
comptime _OFFSET32: UInt32 = 2166136261
comptime _PRIME32: UInt32 = 16777619


def fnv1_64(data: Span[UInt8, _]) -> UInt64:
    """Returns the 64-bit FNV-1 hash of `data` (`fnv1.HashBytes64`).

    Args:
        data: The bytes to hash.

    Returns:
        The hash.
    """
    var h = _OFFSET64
    for b in data:
        h = (h * _PRIME64) ^ UInt64(b)
    return h


def fnv1a_32(data: Span[UInt8, _]) -> UInt32:
    """Returns the 32-bit FNV-1a hash of `data` (`fnv1a.HashBytes32`).

    Args:
        data: The bytes to hash.

    Returns:
        The hash.
    """
    var h = _OFFSET32
    for b in data:
        h = (h ^ UInt32(b)) * _PRIME32
    return h
