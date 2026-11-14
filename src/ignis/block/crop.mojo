"""Crops, ported from Dragonfly `server/block/crop.go`.

Go's embedded `crop` struct supplies `NeighbourUpdateTick`,
`HasLiquidDrops`, `GrowthStage` and `CalculateGrowthChance`; here each crop
calls `crop_neighbour_update_tick` and `calculate_growth_chance`. Go's
`SameCrop` is true for two crops of the same type, which is how
`same_crop` compares them.
"""

from ..world.block import Block
from ..world.world import World, WorldTypes
from .break_info import break_block
from .cube.face import Face
from .cube.pos import Pos
from .farmland import Farmland


trait Crop(Block):
    """A crop that grows in stages (Go `Crop`)."""

    def growth_stage(self) -> Int:
        """Returns the growth stage, 0 to 7 (Go `GrowthStage`)."""
        ...


def crop_neighbour_update_tick[
    B: Block, T: WorldTypes
](b: B, pos: Pos, mut tx: World[T]):
    """Breaks a crop that is not on farmland (Go
    `crop.NeighbourUpdateTick`)."""
    if not tx.block_as[Farmland](pos.side(Face.DOWN)):
        break_block(tx.block(pos), pos, tx)


def _same_crop[T: WorldTypes](mut tx: World[T], a: UInt32, pos: Pos) -> Bool:
    # Go `sameCrop`.
    var br = tx.block_registry()
    var b = tx.block(pos)
    var ka = br[].kind(a)
    if not T.Blocks.is_crop(ka, br[].state_hash(a)):
        return False
    var kb = br[].kind(b)
    return T.Blocks.is_crop(kb, br[].state_hash(b)) and ka == kb


def calculate_growth_chance[
    T: WorldTypes
](pos: Pos, mut tx: World[T]) -> Float64:
    """Returns the chance the crop at `pos` grows, from the farmland and
    crops around it (Go `CalculateGrowthChance`)."""
    var points = 0.0
    var block = tx.block(pos)
    var under = pos.side(Face.DOWN)
    for x in range(-1, 2):
        for z in range(-1, 2):
            if case .Some(f) = tx.block_as[Farmland](under.add(Pos(x, 0, z))):
                var farmland_points = 4.0 if f.hydration > 0 else 2.0
                if x != 0 or z != 0:
                    farmland_points = (farmland_points - 1) / 4
                points += farmland_points
    var north = pos.side(Face.NORTH)
    var south = pos.side(Face.SOUTH)
    var north_south = _same_crop(tx, block, north) or _same_crop(
        tx, block, south
    )
    var west_east = _same_crop(tx, block, pos.side(Face.WEST)) or _same_crop(
        tx, block, pos.side(Face.EAST)
    )
    if north_south and west_east:
        points /= 2
    else:
        var diagonal = (
            _same_crop(tx, block, north.side(Face.WEST))
            or _same_crop(tx, block, north.side(Face.EAST))
            or _same_crop(tx, block, south.side(Face.WEST))
            or _same_crop(tx, block, south.side(Face.EAST))
        )
        if diagonal:
            points /= 2
    return 1 / (25 / points + 1)
