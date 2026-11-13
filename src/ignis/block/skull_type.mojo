"""`SkullType`, ported from Dragonfly `server/block/skull_type.go`.
"""

from ..internal.enum import enum_name


struct SkullType(Equatable, ImplicitlyCopyable, Writable):
    """A type of skull or head (Go `SkullType`)."""

    var _v: UInt8

    comptime SKELETON = SkullType(0)
    """Go `SkeletonSkull()`."""
    comptime WITHER_SKELETON = SkullType(1)
    """Go `WitherSkeletonSkull()`."""
    comptime ZOMBIE = SkullType(2)
    """Go `ZombieHead()`."""
    comptime PLAYER = SkullType(3)
    """Go `PlayerHead()`."""
    comptime CREEPER = SkullType(4)
    """Go `CreeperHead()`."""
    comptime DRAGON = SkullType(5)
    """Go `DragonHead()`."""
    comptime PIGLIN = SkullType(6)
    """Go `PiglinHead()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `SkullType{v}`).

        Args:
            v: 0 to 6.
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
            0 to 6.
        """
        return self._v

    def name(self) -> StaticString:
        """Returns the display name (Go `Name`).

        Returns:
            The name.
        """
        return enum_name(
            (
                "Skeleton Skull,Wither Skeleton Skull,Zombie Head,"
                "Player Head,Creeper Head,Dragon Head,Piglin Head"
            ),
            Int(self._v),
        )

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`).

        Args:
            writer: The destination.
        """
        writer.write(
            enum_name(
                (
                    "skeleton_skull,wither_skeleton_skull,zombie_head,"
                    "player_head,creeper_head,dragon_head,piglin_head"
                ),
                Int(self._v),
            )
        )


def skull_types() -> List[SkullType]:
    """Returns every skull type (Go `SkullTypes`).

    Returns:
        The values.
    """
    var out = List[SkullType](capacity=7)
    for i in range(7):
        out.append(SkullType(i))
    return out^
