"""Helpers for Go-style enumerations (no Dragonfly counterpart).

Dragonfly writes an enumeration's `String` as a `switch`; Ignis keeps the
names of an enumeration in one comma-separated string and picks by index.
"""


def enum_name(names: StaticString, index: Int) -> StaticString:
    """Returns the `index`th entry of a comma-separated list of names.

    Args:
        names: The names, separated by `,` without spaces.
        index: The index of the name, starting at 0.

    Returns:
        The name, or an empty string if the list is shorter.
    """
    var start = 0
    var n = 0
    var bytes = names.as_bytes()
    for i in range(len(bytes) + 1):
        if i == len(bytes) or bytes[i] == UInt8(ord(",")):
            if n == index:
                return names[byte=start:i]
            n += 1
            start = i + 1
    return ""
