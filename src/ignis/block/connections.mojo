"""Horizontal connections of panes, bars and fences, ported from Dragonfly
`server/block/connections.go`.

`calculateConnections` and the `connector` interface need `world.Tx` and
block models: TODO(world-runtime).
"""

from ..world.block_state import Properties


@fieldwise_init
struct Connections(Equatable, ImplicitlyCopyable):
    """The sides a pane-like block connects on (Go `Connections`)."""

    var north: Bool
    """Whether the block connects to the north."""
    var east: Bool
    """Whether the block connects to the east."""
    var south: Bool
    """Whether the block connects to the south."""
    var west: Bool
    """Whether the block connects to the west."""

    def __init__(out self):
        """Creates connections on no side (Go `Connections{}`)."""
        self = Connections(False, False, False, False)

    def __init__(out self, *, bits: Int):
        """Unpacks the value `uint8` returns."""
        self = Connections(
            bits & 1 != 0, bits & 2 != 0, bits & 4 != 0, bits & 8 != 0
        )

    def __eq__(self, other: Self) -> Bool:
        """Compares two connection sets."""
        return self.uint8() == other.uint8()

    def uint8(self) -> UInt8:
        """Packs the connections into bits (Go `Uint8`)."""
        return (
            UInt8(self.north)
            | UInt8(self.east) << 1
            | UInt8(self.south) << 2
            | UInt8(self.west) << 3
        )

    def properties(self, var p: Properties) -> Properties:
        """Adds the connection block properties (Go `properties`)."""
        return p^.with_bool("minecraft:connection_north", self.north).with_bool(
            "minecraft:connection_east", self.east
        ).with_bool("minecraft:connection_south", self.south).with_bool(
            "minecraft:connection_west", self.west
        )


def all_connections() -> List[Connections]:
    """Returns all 16 connection sets (Go `allConnections`)."""
    var out = List[Connections](capacity=16)
    for i in range(16):
        out.append(Connections(bits=i))
    return out^


@fieldwise_init
struct FireConnections(Equatable, ImplicitlyCopyable):
    """The sides fire attaches to (Go `FireConnections`)."""

    var north: Bool
    """Whether the fire attaches to the north."""
    var east: Bool
    """Whether the fire attaches to the east."""
    var south: Bool
    """Whether the fire attaches to the south."""
    var west: Bool
    """Whether the fire attaches to the west."""
    var up: Bool
    """Whether the fire attaches to the block above."""

    def __init__(out self):
        """Creates connections on no side (Go `FireConnections{}`)."""
        self = FireConnections(False, False, False, False, False)

    def __init__(out self, *, bits: Int):
        """Unpacks the value `uint8` returns."""
        self = FireConnections(
            bits & 1 != 0,
            bits & 2 != 0,
            bits & 4 != 0,
            bits & 8 != 0,
            bits & 16 != 0,
        )

    def __eq__(self, other: Self) -> Bool:
        """Compares two connection sets."""
        return self.uint8() == other.uint8()

    def uint8(self) -> UInt8:
        """Packs the connections into bits (Go `Uint8`)."""
        return (
            UInt8(self.north)
            | UInt8(self.east) << 1
            | UInt8(self.south) << 2
            | UInt8(self.west) << 3
            | UInt8(self.up) << 4
        )

    def properties(self, var p: Properties) -> Properties:
        """Adds the connection block properties (Go `properties`)."""
        return p^.with_bool("minecraft:connection_north", self.north).with_bool(
            "minecraft:connection_east", self.east
        ).with_bool("minecraft:connection_south", self.south).with_bool(
            "minecraft:connection_west", self.west
        ).with_bool(
            "minecraft:connection_up", self.up
        )


def all_fire_connections() -> List[FireConnections]:
    """Returns all 32 fire connection sets (Go `allFireConnections`)."""
    var out = List[FireConnections](capacity=32)
    for i in range(32):
        out.append(FireConnections(bits=i))
    return out^
