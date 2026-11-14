"""Copper oxidation, ported from Dragonfly `server/block/oxidizable.go`.

`attempt_oxidation` reads the copper around a block through the world's
block set (Go type asserts each neighbour to `Oxidisable`).
"""

from ..world.block import Block
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .oxidation_type import OxidationType


trait Oxidisable(Block):
    """A copper block that oxidises over time (Go `Oxidisable`)."""

    def can_oxidate(self) -> Bool:
        """Reports whether the block can still oxidise (Go `CanOxidate`)."""
        ...

    def oxidation_level(self) -> OxidationType:
        """Returns the oxidation level (Go `OxidationLevel`)."""
        ...

    def with_oxidation_level(self, o: OxidationType) -> Self:
        """Returns the block with another oxidation level (Go
        `WithOxidationLevel`)."""
        ...


def copper_block_name(
    block_name: StringSlice, oxidation: OxidationType, waxed: Bool
) -> String:
    """Returns the name of a copper block with its oxidation and wax
    prefixes (Go `copperBlockName`)."""
    var name = String(block_name)
    if oxidation != OxidationType.UNOXIDISED:
        name = String(t"{oxidation}_{name}")
    if waxed:
        name = "waxed_" + name
    return "minecraft:" + name


def attempt_oxidation[
    O: Oxidisable, T: WorldTypes
](pos: Pos, mut tx: World[T], o: O):
    """Oxidises a copper block one level, more likely when the copper
    around it is further along (Go `attemptOxidation`)."""
    var level = o.oxidation_level()
    if level == OxidationType.OXIDISED or not o.can_oxidate():
        return
    elif tx.rand().float64() > 64.0 / 1125.0:
        return
    var all = 0
    var higher = 0
    var br = tx.block_registry()
    for x in range(-4, 5):
        for y in range(-4, 5):
            for z in range(-4, 5):
                if x == 0 and y == 0 and z == 0:
                    continue
                if abs(x) + abs(y) + abs(z) > 4:
                    continue
                var rid = tx.block(pos.add(Pos(x, y, z)))
                var info = T.Blocks.oxidation(
                    br[].kind(rid), br[].state_hash(rid)
                )
                if not info or not info.value()[0]:
                    continue
                var other = info.value()[1]
                if other.uint8() < level.uint8():
                    return
                all += 1
                if other.uint8() > level.uint8():
                    higher += 1
    var chance = Float64(higher + 1) / Float64(all + 1)
    if level == OxidationType.UNOXIDISED:
        chance *= chance * 0.75
    else:
        chance *= chance
    if tx.rand().float64() < chance:
        if case .Some(next) = level.increase():
            tx.set_block(pos, o.with_oxidation_level(next))
