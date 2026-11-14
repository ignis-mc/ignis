"""`NetherBricksType`, ported from Dragonfly `server/block/nether_bricks_type.go`.
"""

from ..internal.enum import enum_name


struct NetherBricksType(Equatable, ImplicitlyCopyable, Writable):
    """A type of nether bricks (Go `NetherBricksType`)."""

    var _v: UInt8

    comptime NORMAL = NetherBricksType(0)
    """Go `NormalNetherBricks()`."""
    comptime RED = NetherBricksType(1)
    """Go `RedNetherBricks()`."""
    comptime CRACKED = NetherBricksType(2)
    """Go `CrackedNetherBricks()`."""
    comptime CHISELED = NetherBricksType(3)
    """Go `ChiseledNetherBricks()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `NetherBricksType{v}`)."""
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`)."""
        return self._v

    def name(self) -> StaticString:
        """Returns the display name (Go `Name`)."""
        return enum_name(
            (
                "Nether Bricks,Red Nether Bricks,Cracked Nether Bricks,"
                "Chiseled Nether Bricks"
            ),
            Int(self._v),
        )

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`)."""
        writer.write(
            enum_name(
                (
                    "nether_brick,red_nether_brick,cracked_nether_bricks,"
                    "chiseled_nether_bricks"
                ),
                Int(self._v),
            )
        )


def nether_bricks_types() -> List[NetherBricksType]:
    """Returns every nether bricks type (Go `NetherBricksTypes`)."""
    var out = List[NetherBricksType](capacity=4)
    for i in range(4):
        out.append(NetherBricksType(i))
    return out^
