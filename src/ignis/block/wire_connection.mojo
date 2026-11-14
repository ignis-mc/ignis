"""`WireConnection` and `WireConnections`, ported from Dragonfly
`server/block/wire_connection.go`.
"""

from ..internal.enum import enum_name
from ..world.block_state import Properties


struct WireConnection(Equatable, ImplicitlyCopyable, Writable):
    """How redstone wire connects on one side (Go `WireConnection`)."""

    var _v: UInt8

    comptime NONE = WireConnection(0)
    """Go `NoWireConnection()`."""
    comptime SIDE = WireConnection(1)
    """Go `SideWireConnection()`."""
    comptime UP = WireConnection(2)
    """Go `UpWireConnection()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `WireConnection{v}`)."""
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`)."""
        return self._v

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`)."""
        writer.write(enum_name("none,side,up", Int(self._v)))


def wire_connection_types() -> List[WireConnection]:
    """Returns every wire connection, none, side and up (no Go counterpart)."""
    var out = List[WireConnection](capacity=3)
    for i in range(3):
        out.append(WireConnection(i))
    return out^


@fieldwise_init
struct WireConnections(Equatable, ImplicitlyCopyable):
    """The connections of redstone wire on its four sides (Go
    `WireConnections`)."""

    var north: WireConnection
    """The connection to the north."""
    var east: WireConnection
    """The connection to the east."""
    var south: WireConnection
    """The connection to the south."""
    var west: WireConnection
    """The connection to the west."""

    def __init__(out self):
        """Creates wire connected on no side (Go `WireConnections{}`)."""
        self = WireConnections(
            WireConnection.NONE,
            WireConnection.NONE,
            WireConnection.NONE,
            WireConnection.NONE,
        )

    def __init__(out self, *, bits: Int):
        """Unpacks the value `uint8` returns."""
        self = WireConnections(
            WireConnection(bits % 3),
            WireConnection(bits // 3 % 3),
            WireConnection(bits // 9 % 3),
            WireConnection(bits // 27 % 3),
        )

    def __eq__(self, other: Self) -> Bool:
        """Compares two connection sets."""
        return self.uint8() == other.uint8()

    def uint8(self) -> UInt8:
        """Packs the connections into a base-3 number (Go `Uint8`)."""
        return (
            self.north.uint8()
            + self.east.uint8() * 3
            + self.south.uint8() * 9
            + self.west.uint8() * 27
        )

    def properties(self, var p: Properties) -> Properties:
        """Adds the wire connection block properties (Go `properties`)."""
        return p^.with_string("redstone_north", String(self.north)).with_string(
            "redstone_east", String(self.east)
        ).with_string("redstone_south", String(self.south)).with_string(
            "redstone_west", String(self.west)
        )


def all_wire_connections() -> List[WireConnections]:
    """Returns all 81 wire connection sets (Go `allWireConnections`)."""
    var out = List[WireConnections](capacity=81)
    for i in range(81):
        out.append(WireConnections(bits=i))
    return out^
