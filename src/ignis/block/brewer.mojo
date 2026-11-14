"""Brewing, ported from Dragonfly `server/block/brewer.go`.

Go's `*brewer` holds the inventory, viewers, brew time and fuel behind a
pointer. Here the inventory and viewers live with the world's block entity
and the brew time and fuel (`Brewer`) are NBT fields of the brewing stand,
written back after each tick. Slots: 0 the ingredient, 1 to 3 the bottles,
4 the blaze powder fuel.
"""

from minecraft.nbt.nbt import TAG_SHORT
from minecraft.nbt.tree import Tag, Tree

from ..item.blaze_powder import BlazePowder
from ..item.glass_bottle import GlassBottle
from ..item.inventory.inventory import Inventory
from ..item.lingering_potion import LingeringPotion
from ..item.potion import Potion
from ..item.splash_potion import SplashPotion
from ..item.stack import Stack
from ..world.item import EncodedItem
from ..world.sound.block import PotionBrewed
from ..world.world import World, WorldTypes
from .cube.face import Face
from .cube.pos import Pos


struct Brewer(Defaultable, Equatable, ImplicitlyCopyable):
    """The brew time and fuel of a brewing stand (Go's `brewer` fields
    besides the inventory and viewers)."""

    var duration_ms: Int
    """Brewing time left (Go `duration`)."""
    var fuel_amount: Int
    """Brews the fuel still gives (Go `fuelAmount`)."""
    var fuel_total: Int
    """Brews one blaze powder gives (Go `fuelTotal`)."""

    def __init__(out self):
        """Creates an idle brewer (Go `newBrewer`)."""
        self.duration_ms = 0
        self.fuel_amount = 0
        self.fuel_total = 0

    def encode(self, mut tag: Tree, root: Tag) raises:
        """Writes Go's `CookTime`, `FuelTotal` and `FuelAmount`."""
        _ = tag.put_short(root, "CookTime", Int16(self.duration_ms // 50))
        _ = tag.put_short(root, "FuelTotal", Int16(self.fuel_total))
        _ = tag.put_short(root, "FuelAmount", Int16(self.fuel_amount))

    @staticmethod
    def decode(tag: Tree, root: Tag) raises -> Self:
        """Reads the fields `encode` writes."""
        var b = Self()
        b.duration_ms = _short(tag, root, "CookTime") * 50
        b.fuel_amount = _short(tag, root, "FuelAmount")
        b.fuel_total = _short(tag, root, "FuelTotal")
        return b


def _short(tag: Tree, root: Tag, key: StringSpan) raises -> Int:
    if case .Some(t) = tag.get(root, key):
        if tag.type_of(t) == TAG_SHORT:
            return Int(tag.as_short(t))
    return 0


def _perform[
    T: WorldTypes
](
    mut tx: World[T], block: String, bottle: Stack, ingredient: Stack
) -> Optional[Stack]:
    # Go `recipe.Perform(block, bottle.Item(), ingredient.Item())`.
    var a = tx.encode_stack(bottle)
    var b = tx.encode_stack(ingredient)
    if not a or not b:
        return None
    try:
        var out = tx.recipes()[].perform(
            block, [a.value(), b.value()], tx.item_registry()[]
        )
        if case .Some(l) = out:
            if len(l) > 0:
                return l[0].copy()
    except:
        pass
    return None


def tick_brewing[
    T: WorldTypes
](mut b: Brewer, block: String, pos: Pos, mut tx: World[T]):
    """Brews for one tick (Go `tickBrewing`): blaze powder gives 20 brews,
    a brew takes 20 s and turns every bottle the ingredient affects."""
    var found = tx.inventory(pos)
    if not found:
        return
    var inv = found.value().copy()
    var bottles = List[Stack]()
    var fuel: Stack
    var ingredient: Stack
    try:
        for i in range(1, 4):
            bottles.append(inv.item(i))
        fuel = inv.item(4)
        ingredient = inv.item(0)
    except:
        return
    var prev_duration = b.duration_ms
    var prev_fuel = b.fuel_amount
    var prev_total = b.fuel_total
    var sets = List[Tuple[Int, Stack]]()
    if fuel.item_as[BlazePowder]() and b.fuel_amount <= 0:
        sets.append((4, fuel.grow(-1)))
        b.fuel_amount = 20
        b.fuel_total = 20
    var outputs = List[Optional[Stack]]()
    var affected = False
    for ref bottle in bottles:
        var out = _perform(tx, block, bottle, ingredient)
        if out:
            affected = True
        outputs.append(out^)
    if b.fuel_amount > 0:
        if affected:
            if b.duration_ms == 0:
                b.duration_ms = 20000
            b.duration_ms -= 50
            if b.duration_ms <= 0:
                for i in range(3):
                    if case .Some(ref o) = outputs[i]:
                        sets.append((i + 1, o.copy()))
                sets.append((0, ingredient.grow(-1)))
                tx.play_sound(pos.vec3_centre(), PotionBrewed())
                b.fuel_amount -= 1
                b.duration_ms = 0
        else:
            b.duration_ms = 0
    else:
        b.duration_ms = 0
        b.fuel_amount = 0
        b.fuel_total = 0
    for ref e in sets:
        try:
            inv.set_item(e[0], e[1])
        except:
            pass
    if inv.changed():
        tx.set_inventory(pos, inv^)
    for v in tx.container_viewers(pos):
        tx.viewer(v).view_brewing_update(
            prev_duration,
            b.duration_ms,
            prev_fuel,
            b.fuel_amount,
            prev_total,
            b.fuel_total,
        )


def _bottle(s: Stack) -> Bool:
    return Bool(
        s.item_as[Potion]()
        or s.item_as[SplashPotion]()
        or s.item_as[LingeringPotion]()
        or s.item_as[GlassBottle]()
    )


def brewer_insert[
    T: WorldTypes
](mut hopper: Inventory, facing: Face, pos: Pos, mut tx: World[T]) -> Bool:
    """Takes one item from a hopper: ingredients from above, blaze powder
    and bottles from the side (Go `brewer.InsertItem`)."""
    var found = tx.inventory(pos)
    if not found:
        return False
    var inv = found.value().copy()
    for source_slot in range(hopper.size()):
        var source: Stack
        try:
            source = hopper.item(source_slot)
        except:
            return False
        if source.empty():
            continue
        var slot = 0
        if facing == Face.DOWN:
            var e = tx.encode_stack(source)
            if not e or not tx.recipes()[].valid_brewing_reagent(e.value()):
                continue
        elif source.item_as[BlazePowder]():
            slot = 4
        else:
            if not _bottle(source):
                continue
            for i in range(1, 4):
                var it: Stack
                try:
                    it = inv.item(i)
                except:
                    continue
                if it.count() == it.max_count() or not it.comparable(source):
                    continue
                slot = i
                break
            if slot == 0:
                continue
        var stack = source.grow(-source.count() + 1)
        var it: Stack
        try:
            it = inv.item(slot)
        except:
            continue
        if not source.comparable(it) or it.count() == it.max_count():
            continue
        if not it.empty():
            stack = it.grow(1)
        try:
            inv.set_item(slot, stack)
            hopper.set_item(source_slot, source.grow(-1))
        except:
            return False
        tx.set_inventory(pos, inv^)
        return True
    return False


def brewer_extract[
    T: WorldTypes
](mut hopper: Inventory, pos: Pos, mut tx: World[T]) -> Bool:
    """Gives a hopper below one bottle (Go `brewer.ExtractItem`)."""
    var found = tx.inventory(pos)
    if not found:
        return False
    var inv = found.value().copy()
    for slot in range(1, 4):
        var source: Stack
        try:
            source = inv.item(slot)
        except:
            return False
        if source.empty():
            continue
        var one = source.grow(-source.count() + 1)
        if hopper.add_item(one.copy()) < one.count():
            continue
        try:
            inv.set_item(slot, source.grow(-1))
        except:
            return False
        tx.set_inventory(pos, inv^)
        return True
    return False
