"""The smelting shared by furnaces, blast furnaces and smokers, ported from
Dragonfly `server/block/smelter.go`.

Go's `*smelter` holds the inventory, the viewers and the durations behind
a pointer in the block. Here the inventory and viewers live with the
world's block entity and the durations and experience (`Smelter`) are NBT
fields of the block value, written back after each tick. Hopper insertion
and extraction (`InsertItem`, `ExtractItem`) live with the hopper.
"""

from minecraft.nbt.nbt import TAG_SHORT
from minecraft.nbt.tree import Tag, Tree

from ..item.inventory.inventory import Inventory
from ..item.register import VanillaBlockItems, VanillaItems
from ..item.smelting_info import FuelInfo, SmeltInfo
from ..item.stack import Stack
from ..world.world import World, WorldTypes
from .cube.face import Face
from .cube.pos import Pos

comptime SMELT_ANY = 0
"""A furnace smelts everything."""
comptime SMELT_FOOD = 1
"""A smoker smelts food (Go `SmeltInfo.Food`)."""
comptime SMELT_ORES = 2
"""A blast furnace smelts ores (Go `SmeltInfo.Ores`)."""


def smelt_info_of(s: Stack) -> Optional[SmeltInfo]:
    """Returns what a stack smelts into (Go `s.Item().(item.Smeltable)`)."""
    if case .Some(it) = s.item():
        if it.block:
            return VanillaBlockItems.smelt_info(it.kind, it.hash)
        return VanillaItems.smelt_info(it.kind, it.hash)
    return None


def fuel_info_of(s: Stack) -> Optional[FuelInfo]:
    """Returns how long a stack burns (Go `s.Item().(item.Fuel)`)."""
    if case .Some(it) = s.item():
        if it.block:
            return VanillaBlockItems.fuel_info(it.kind, it.hash)
        return VanillaItems.fuel_info(it.kind, it.hash)
    return None


struct Smelter(Defaultable, Equatable, ImplicitlyCopyable):
    """The durations and experience of a smelter (Go's `smelter` fields
    besides the inventory and viewers)."""

    var remaining_ms: Int
    """Fuel time left (Go `remainingDuration`)."""
    var max_ms: Int
    """The burn time of the fuel being used (Go `maxDuration`)."""
    var cook_ms: Int
    """Progress of the item being smelted (Go `cookDuration`)."""
    var experience: Int
    """Experience collected (Go `experience`)."""

    def __init__(out self):
        """Creates an unlit smelter (Go `newSmelter`)."""
        self.remaining_ms = 0
        self.max_ms = 0
        self.cook_ms = 0
        self.experience = 0

    def encode(self, mut tag: Tree, root: Tag) raises:
        """Writes Go's smelter NBT fields, in ticks."""
        _ = tag.put_short(root, "BurnTime", Int16(self.remaining_ms // 50))
        _ = tag.put_short(root, "CookTime", Int16(self.cook_ms // 50))
        _ = tag.put_short(root, "BurnDuration", Int16(self.max_ms // 50))
        _ = tag.put_short(root, "StoredXPInt", Int16(self.experience))

    @staticmethod
    def decode(tag: Tree, root: Tag) raises -> Self:
        """Reads Go's smelter NBT fields (Go `nbtconv.TickDuration`)."""
        var s = Self()
        s.remaining_ms = _ticks(tag, root, "BurnTime") * 50
        s.max_ms = _ticks(tag, root, "BurnDuration") * 50
        s.cook_ms = _ticks(tag, root, "CookTime") * 50
        s.experience = _ticks(tag, root, "StoredXPInt")
        return s^


def _ticks(tag: Tree, root: Tag, key: StringSpan) raises -> Int:
    if case .Some(t) = tag.get(root, key):
        if tag.type_of(t) == TAG_SHORT:
            return Int(tag.as_short(t))
    return 0


def tick_smelting[
    T: WorldTypes
](
    mut s: Smelter,
    pos: Pos,
    mut tx: World[T],
    requirement_ms: Int,
    decrement_ms: Int,
    lit: Bool,
    mode: Int,
) -> Bool:
    """Smelts for one tick (Go `tickSmelting`) and returns whether the
    smelter is lit. The inventory is read from and written back to the
    world; viewers see the progress."""
    var found = tx.inventory(pos)
    if not found:
        return lit
    var inv = found.value().copy()
    var now_lit = lit
    var prev_cook = s.cook_ms
    var prev_remaining = s.remaining_ms
    var prev_max = s.max_ms
    var input: Stack
    var fuel: Stack
    var product: Stack
    try:
        input = inv.item(0)
        fuel = inv.item(1)
        product = inv.item(2)
    except:
        return lit
    var input_info = SmeltInfo()
    if case .Some(i) = smelt_info_of(input):
        if (
            mode == SMELT_ANY
            or (mode == SMELT_FOOD and i.food)
            or (mode == SMELT_ORES and i.ores)
        ):
            input_info = i.copy()
    var fuel_info = FuelInfo()
    if case .Some(f) = fuel_info_of(fuel):
        fuel_info = f.copy()
        if fuel_info.residue.empty():
            fuel_info.residue = fuel.grow(-1)
    var can_smelt = (
        input.count() > 0
        and input_info.product.comparable(product)
        and not input_info.product.empty()
        and product.count() < product.max_count()
    )
    var sets = List[Tuple[Int, Stack]]()
    if (
        s.remaining_ms <= 0
        and can_smelt
        and fuel_info.duration > 0
        and fuel.count() > 0
    ):
        s.remaining_ms = fuel_info.duration
        s.max_ms = fuel_info.duration
        now_lit = True
        sets.append((1, fuel_info.residue.copy()))
    if s.remaining_ms > 0:
        s.remaining_ms -= 50
        if can_smelt:
            s.cook_ms += 50
            if s.cook_ms >= requirement_ms:
                sets.append((0, input.grow(-1)))
                # Go `item.NewStack(product.Item(), n)`; recipe products
                # carry nothing else.
                sets.append((2, input_info.product.grow(product.count())))
                var xp = input_info.experience * Float64(
                    input_info.product.count()
                )
                var earned = Int(input_info.experience)
                var chance = xp - Float64(earned)
                if chance > 0 and tx.global_rand().float64() < chance:
                    earned += 1
                s.cook_ms -= requirement_ms
                s.experience += earned
        elif s.remaining_ms == 0:
            s.max_ms = 0
        else:
            s.cook_ms = 0
    else:
        s.max_ms = 0
        now_lit = False
    if s.cook_ms > 0 and not now_lit:
        s.cook_ms -= decrement_ms
    for ref e in sets:
        try:
            inv.set_item(e[0], e[1])
        except:
            pass
    if inv.changed():
        tx.set_inventory(pos, inv^)
    for v in tx.container_viewers(pos):
        tx.viewer(v).view_furnace_update(
            prev_cook,
            s.cook_ms,
            prev_remaining,
            s.remaining_ms,
            prev_max,
            s.max_ms,
        )
    return now_lit


def smelter_insert[
    T: WorldTypes
](mut hopper: Inventory, facing: Face, pos: Pos, mut tx: World[T]) -> Bool:
    """Takes one item from a hopper: fuel from the side, the input from
    above (Go `smelter.InsertItem`)."""
    var found = tx.inventory(pos)
    if not found:
        return False
    var inv = found.value().copy()
    for source_slot in range(hopper.size()):
        var source: Stack
        var it: Stack
        var slot = 1 if facing != Face.DOWN else 0
        try:
            source = hopper.item(source_slot)
            if source.empty():
                continue
            it = inv.item(slot)
        except:
            return False
        var stack = source.grow(-source.count() + 1)
        if slot == 1:
            var f = fuel_info_of(source)
            if not f or f.value().duration == 0:
                continue
        if not source.comparable(it):
            continue
        if it.count() == it.max_count():
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


def smelter_extract[
    T: WorldTypes
](mut hopper: Inventory, pos: Pos, mut tx: World[T]) -> Bool:
    """Gives a hopper below one product, or fuel that no longer burns (Go
    `smelter.ExtractItem`)."""
    var found = tx.inventory(pos)
    if not found:
        return False
    var inv = found.value().copy()
    for source_slot in range(inv.size()):
        var source: Stack
        try:
            source = inv.item(source_slot)
        except:
            return False
        if source.empty() or source_slot == 0:
            continue
        if source_slot == 1:
            var f = fuel_info_of(source)
            if f and f.value().duration != 0:
                continue
        var one = source.grow(-source.count() + 1)
        if hopper.add_item(one.copy()) < one.count():
            continue
        try:
            inv.set_item(source_slot, source.grow(-1))
        except:
            return False
        tx.set_inventory(pos, inv^)
        return True
    return False
