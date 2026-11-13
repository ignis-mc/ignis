"""`FireType`, ported from Dragonfly `server/block/fire_type.go`.
"""

from ..internal.enum import enum_name


struct FireType(Equatable, ImplicitlyCopyable, Writable):
    """A type of fire (Go `FireType`)."""

    var _v: UInt8

    comptime NORMAL = FireType(0)
    """Go `NormalFire()`."""
    comptime SOUL = FireType(1)
    """Go `SoulFire()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `FireType{v}`).

        Args:
            v: 0 to 1.
        """
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values.

        Args:
            other: The value to compare with.

        Returns:
            True if both are the same.
        """
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`).

        Returns:
            0 to 1.
        """
        return self._v

    def name(self) -> StaticString:
        """Returns the display name (Go `Name`).

        Returns:
            The name.
        """
        return enum_name("Fire,Soul Fire", Int(self._v))

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`).

        Args:
            writer: The destination.
        """
        writer.write(enum_name("normal,soul", Int(self._v)))

    def light_level(self) -> UInt8:
        """Returns the light level fire of the type emits (Go `LightLevel`).

        Returns:
            15 for normal fire, 10 for soul fire.
        """
        return 15 if self._v == 0 else 10


def fire_types() -> List[FireType]:
    """Returns every fire type (Go `FireTypes`).

    Returns:
        The values.
    """
    var out = List[FireType](capacity=2)
    for i in range(2):
        out.append(FireType(i))
    return out^
