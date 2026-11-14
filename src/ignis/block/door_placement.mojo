"""Door placement, ported from Dragonfly `server/block/door_placement.go`."""

from ..world.world import World, WorldTypes
from .block import face_solid_at, first_replaceable, light_diffuser_at
from .block import replaceable_with
from .cube.direction import Direction
from .cube.face import Face, faces
from .cube.pos import Pos
from .hash import AnyBlock
from .model.door import Door as DoorModel
from .register import block_model_as


def door_placement_position[
    T: WorldTypes
](mut tx: World[T], pos: Pos, face: Face, door: AnyBlock) -> Optional[Pos]:
    """Returns where the lower half of a door goes: a replaceable clicked
    cell or the top of the clicked block, with room above and a solid block
    below; None if the door cannot go there (Go `doorPlacementPosition`)."""
    var at = first_replaceable(tx, pos, face, door)
    if not at or at.value()[1] != Face.UP:
        return None
    var p = at.value()[0]
    if not replaceable_with(tx, p.side(Face.UP), door):
        return None
    if not face_solid_at(tx, p.side(Face.DOWN), Face.UP):
        return None
    return p


def door_hinge_right[
    T: WorldTypes
](mut tx: World[T], pos: Pos, facing: Direction) -> Bool:
    """Chooses the hinge from doors and solid blocks beside both halves (Go
    `doorHingeRight`)."""
    var left = door_hinge_side(tx, pos.side(facing.rotate_left().face()))
    var right = door_hinge_side(tx, pos.side(facing.rotate_right().face()))
    return (left[1] and not right[1]) or right[0] > left[0]


def door_hinge_side[
    T: WorldTypes
](mut tx: World[T], pos: Pos) -> Tuple[Int, Bool]:
    """Counts the opaque full blocks beside both halves and reports whether
    either is a door (Go `doorHingeSide`)."""
    var solid = 0
    var door = False
    var br = tx.block_registry()
    for p in [pos, pos.side(Face.UP)]:
        var rid = tx.block(p)
        if block_model_as[DoorModel](
            AnyBlock(br[].kind(rid), br[].state_hash(rid))
        ):
            door = True
        if case .Some(level) = light_diffuser_at(tx, p):
            if level != 15:
                continue
        var full = True
        for f in faces():
            if not face_solid_at(tx, p, f):
                full = False
                break
        if full:
            solid += 1
    return (solid, door)
