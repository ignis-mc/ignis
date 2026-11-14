"""Shared block helpers, ported from parts of Dragonfly
`server/block/block.go`.

The embedded helper structs of that file (`solid`, `transparent`,
`replaceable`, the instrument helpers) become methods on each block; see
`docs/architecture.md`.
"""

from ..mgl64 import Vec3
from ..world.block import Block
from ..world.world import World, WorldTypes
from .cube.direction import Direction
from .cube.face import Face
from .cube.pos import Pos
from .cube.rotation import Rotation
from .hash import AnyBlock

comptime UNKNOWN_DIRECTION = Direction(4)
"""A direction past the four real ones, for blocks that may face none (Go
`unknownDirection`)."""
comptime UNKNOWN_FACE = Face(6)
"""A face past the six real ones (Go `unknownFace`)."""


trait Replaceable:
    """A block that another block may replace when placed (Go
    `Replaceable`)."""

    def replaceable_by(self, b: AnyBlock) -> Bool:
        """Reports whether `b` may replace this block (Go `ReplaceableBy`)."""
        ...


@fieldwise_init
struct Placement(Copyable):
    """A block a `UsableOnBlock` block places (one call of Go's `place`)."""

    var pos: Pos
    """Where."""
    var block: AnyBlock
    """The block."""
    var ignore_bbox: Bool
    """Place even if an entity is in the way (Go `UseContext.IgnoreBBox`,
    set by doors)."""


trait UsableOnBlock(Block):
    """A block item that decides itself how it is placed (Go
    `item.UsableOnBlock` implemented by blocks)."""

    def use_on_block[
        T: WorldTypes
    ](
        self,
        pos: Pos,
        face: Face,
        click: Vec3,
        user: Rotation,
        mut tx: World[T],
    ) -> List[Placement]:
        """Returns the blocks to place when the item is used on the face of
        the block at `pos`, clicked at `click` by a user looking at
        `user`; empty if it cannot be placed (Go `UseOnBlock` up to its
        `place` calls)."""
        ...


def replaceable_with[
    T: WorldTypes
](mut tx: World[T], pos: Pos, with_: AnyBlock) -> Bool:
    """Reports whether the block at `pos` may be replaced by `with_` (Go
    `replaceableWith`, without the liquid check: liquids are not ported)."""
    if pos.out_of_bounds(tx.range()):
        return False
    var br = tx.block_registry()
    var rid = tx.block(pos)
    var kind = br[].kind(rid)
    var hash = br[].state_hash(rid)
    if not T.Blocks.replaceable_by(kind, hash, with_):
        return False
    return AnyBlock(kind, hash) != with_


def first_replaceable[
    T: WorldTypes
](mut tx: World[T], pos: Pos, face: Face, with_: AnyBlock) -> Optional[
    Tuple[Pos, Face]
]:
    """Returns where `with_` goes when used on a face of the block at `pos`:
    into the block if it is replaceable (then on its top face), else on the
    clicked side (Go `firstReplaceable`); None if neither is free."""
    if replaceable_with(tx, pos, with_):
        return (pos, Face.UP)
    var side = pos.side(face)
    if replaceable_with(tx, side, with_):
        return (side, face)
    return None


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
