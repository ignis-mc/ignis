"""Shared block helpers, ported from parts of Dragonfly
`server/block/block.go`.

The embedded helper structs of that file (`solid`, `transparent`,
`replaceable`, the instrument helpers) become methods on each block; see
`docs/architecture.md`.
"""

from .cube.direction import Direction
from .cube.face import Face

comptime UNKNOWN_DIRECTION = Direction(4)
"""A direction past the four real ones, for blocks that may face none (Go
`unknownDirection`)."""
comptime UNKNOWN_FACE = Face(6)
"""A face past the six real ones (Go `unknownFace`)."""


def horizontal_direction(d: Direction) -> Direction:
    """Converts a direction to the legacy horizontal direction some block
    properties use (Go `horizontalDirection`)."""
    if d == Direction.SOUTH:
        return Direction.NORTH
    if d == Direction.WEST:
        return Direction.SOUTH
    if d == Direction.NORTH:
        return Direction.WEST
    return Direction.EAST
