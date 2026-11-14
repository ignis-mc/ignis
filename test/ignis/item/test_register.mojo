from ignis.block.hash import HASH_NETHER_BRICKS, HASH_SLAB, HASH_STAIRS
from ignis.internal.fnv import fnv1a_64
from ignis.item.register import (
    VanillaBlockItems,
    VanillaItems,
    vanilla_item_registry,
)
from ignis.item.stack import Stack
from ignis.world.item import AnyItem, ItemRegistry
from std.memory import bitcast
from std.testing import TestSuite, assert_equal, assert_true


def test_vanilla_item_registry() raises:
    var reg = vanilla_item_registry()
    assert_true(reg.item_by_name("minecraft:smooth_stone", 0))
    assert_true(reg.item_by_name("minecraft:shears", 0))


def _float_hex(f: Float64) -> String:
    var bits = bitcast[DType.uint64](f)
    var s = String()
    for i in range(16):
        var nibble = Int((bits >> UInt64(60 - 4 * i)) & 0xF)
        s += String("0123456789abcdef"[byte=nibble])
    return s^


def _b01(b: Bool) -> String:
    return "1" if b else "0"


def _sorted(var l: List[String]) -> List[String]:
    for i in range(1, len(l)):
        var j = i
        while j > 0 and l[j] < l[j - 1]:
            l.swap_elements(j, j - 1)
            j -= 1
    return l^


def _join(l: List[String], empty: String) -> String:
    if len(l) == 0:
        return empty
    return String(",").join(l)


def _stack_name(reg: ItemRegistry, s: Stack) -> String:
    """`stackName` of `interop/items`: `name:meta*count` or `-`."""
    if s.empty():
        return "-"
    var enc = reg.encode_item(s.item().value())
    if not enc:
        return String(t"unregistered*{s.count()}")
    var e = enc.value()
    return String(t"{e.name}:{e.meta}*{s.count()}")


def _fixed_go_hash(kind: UInt64, hash: UInt64) -> UInt64:
    """The state hash Go gives a block Ignis registers with `hash`: they
    differ only for the nether brick slabs and stairs Go swaps (see
    `test/ignis/block/test_register.mojo`)."""
    if kind != HASH_SLAB and kind != HASH_STAIRS:
        return hash
    var inner_kind = hash & 0xFFFF
    var inner_state = (hash >> 16) & 0xFFFF
    if inner_kind == HASH_NETHER_BRICKS and inner_state <= 1:
        return hash ^ (1 << 16)
    return hash


def _line(
    reg: ItemRegistry, all: List[AnyItem], it: AnyItem, go_type: String
) raises -> String:
    """Builds the `defs.txt` line of `interop/items` for a registered
    item."""
    var k = it.kind
    var h = it.hash
    var enc = reg.encode_item(it).value()
    var f = List[String]()
    f.append(enc.name)
    f.append(String(enc.meta))
    # The type: Go's name if the kind is the one Ignis derives from it.
    if it.block:
        f.append(go_type)
        f.append(String(t"{k}:{_fixed_go_hash(k, h)}"))
    else:
        f.append(go_type if k == fnv1a_64(go_type.as_bytes()) else "?")
        f.append("-")

    var mc = VanillaItems.max_count(k, h)
    if not mc:
        mc = VanillaBlockItems.max_count(k, h)
    f.append(String(mc.or_else(64)))

    var d = VanillaItems.durability_info(k, h)
    if not d:
        d = VanillaBlockItems.durability_info(k, h)
    if case .Some(ref di) = d:
        f.append(
            String(
                t"{di.max_durability},{di.attack_durability},"
                t"{di.break_durability},{_b01(di.persistent)},-"
            )
        )
    else:
        f.append("-")

    var tt = VanillaItems.tool_type(k, h)
    if case .Some(t) = tt:
        var level = VanillaItems.harvest_level(k, h).value()
        # block.Stone{} and block.Cobweb{}.
        var stone = VanillaItems.base_mining_efficiency(
            k, h, _block_kind("Stone")
        ).value()
        var cobweb = VanillaItems.base_mining_efficiency(
            k, h, _block_kind("Cobweb")
        ).value()
        f.append(
            String(t"{t.t},{level},{_float_hex(stone)},{_float_hex(cobweb)}")
        )
    else:
        f.append("-")

    var slot_ = VanillaItems.armour_slot(k, h)
    var def_ = VanillaItems.defence_points(k, h)
    var tough = VanillaItems.toughness(k, h)
    var kb = VanillaItems.knock_back_resistance(k, h)
    if not slot_:
        # Carved pumpkins and skulls are block helmets.
        slot_ = VanillaBlockItems.armour_slot(k, h)
        def_ = VanillaBlockItems.defence_points(k, h)
        tough = VanillaBlockItems.toughness(k, h)
        kb = VanillaBlockItems.knock_back_resistance(k, h)
    if case .Some(slot) = slot_:
        var s = String("?")
        if slot >= 0:
            s = String("hclb"[byte=slot])
        f.append(
            String(
                t"{s},{_float_hex(def_.value())},{_float_hex(tough.value())},"
                t"{_float_hex(kb.value())}"
            )
        )
    else:
        f.append("-")

    var always = VanillaItems.always_consumable(k, h)
    if not always:
        always = VanillaBlockItems.always_consumable(k, h)
    if case .Some(a) = always:
        var dur = VanillaItems.consume_duration(k, h)
        var info = VanillaItems.consume_info(k, h)
        if not dur:
            dur = VanillaBlockItems.consume_duration(k, h)
            info = VanillaBlockItems.consume_info(k, h)
        f.append(String(t"{_b01(a)},{dur.value()}"))
        ref c = info.value()
        var effects = List[String]()
        for e in c.effects:
            effects.append(String(e))
        var removed = List[String]()
        if c.removes_all_effects:
            removed.append("*")
        for id in c.removed_effects:
            removed.append(String(id))
        f.append(
            String(
                t"{c.food},{_float_hex(c.saturation)};"
                t"{_join(_sorted(effects^), '-')};"
                t"{_join(_sorted(removed^), '-')};"
                t"{_stack_name(reg, c.residue)}"
            )
        )
    else:
        f.append("-")
        f.append("-")

    var fuel = VanillaItems.fuel_info(k, h)
    if not fuel:
        fuel = VanillaBlockItems.fuel_info(k, h)
    if case .Some(ref fi) = fuel:
        f.append(String(t"{fi.duration},{_stack_name(reg, fi.residue)}"))
    else:
        f.append("-")

    var smelt = VanillaItems.smelt_info(k, h)
    if not smelt:
        smelt = VanillaBlockItems.smelt_info(k, h)
    if case .Some(ref si) = smelt:
        f.append(
            String(
                t"{_stack_name(reg, si.product)},"
                t"{_float_hex(si.experience)},{_b01(si.food)},"
                t"{_b01(si.ores)}"
            )
        )
    else:
        f.append("-")

    var ench = VanillaItems.enchantment_value(k, h)
    if not ench:
        ench = VanillaBlockItems.enchantment_value(k, h)
    f.append(String(ench.value()) if ench else String("-"))

    var empty = Stack()
    if VanillaItems.repairable_by(k, h, empty):
        var names = List[String]()
        for other in all:
            var n = reg.encode_item(other).value().name
            if n in names:
                continue
            var reg_other = reg.item_by_name(
                n, reg.encode_item(other).value().meta
            ).value()
            if VanillaItems.repairable_by(k, h, Stack(reg_other, 1)).value():
                names.append(n)
        f.append(_join(_sorted(names^), "none"))
    else:
        f.append("-")

    var compost = VanillaItems.compost_chance(k, h)
    if not compost:
        compost = VanillaBlockItems.compost_chance(k, h)
    f.append(_float_hex(compost.value()) if compost else String("-"))

    var misc = List[String]()
    var off = VanillaItems.off_hand(k, h)
    misc.append(_b01(off.value()) if off else String("-"))
    var beacon = VanillaItems.payable_for_beacon(k, h)
    misc.append(_b01(beacon.value()) if beacon else String("-"))
    var attack = VanillaItems.attack_damage(k, h)
    misc.append(_float_hex(attack.value()) if attack else String("-"))
    var cooldown = VanillaItems.cooldown(k, h)
    misc.append(String(cooldown.value()) if cooldown else String("-"))
    f.append(String(",").join(misc))
    return String("\t").join(f)


def _block_kind(name: StaticString) -> UInt64:
    from ignis.block.hash import HASH_COBWEB, HASH_STONE

    if name == "Stone":
        return HASH_STONE
    return HASH_COBWEB


def test_every_item_matches_dragonfly() raises:
    """Every item Dragonfly registers (`defs.txt` from `interop/items`) is
    registered here with the same type, name, metadata and block state, and
    the same maximum count, durability, tool, armour, consumable, fuel,
    smelting, enchantability, repair, compost and weapon data."""
    var reg = vanilla_item_registry()
    var expected = Dict[String, String]()
    var go_types = Dict[String, String]()
    with open("test/data/items/defs.txt", "r") as f:
        for line in f.read().split("\n"):
            if line.byte_length() == 0:
                continue
            var parts = line.split("\t")
            var key = String(t"{parts[0]}:{parts[1]}")
            expected[key] = String(line)
            go_types[key] = String(parts[2])
    var all = reg.items()
    var missing = Dict[String, Int]()
    var checked = 0
    var failed = 0
    for it in all:
        var enc = reg.encode_item(it).value()
        var key = String(t"{enc.name}:{enc.meta}")
        assert_true(key in expected, String(t"{key} not registered in Go"))
        var got = _line(reg, all, it, go_types[key])
        if got != expected[key]:
            print("want:", expected[key])
            print("got: ", got)
            failed += 1
        _ = expected.pop(key)
        checked += 1
    for e in expected.items():
        var t = String(e.value.split("\t")[2])
        missing[t] = missing.get(t, 0) + 1
    for m in missing.items():
        print("not registered:", m.key, m.value)
    assert_equal(failed, 0, "every registered item matches Dragonfly")
    assert_equal(len(missing), 0, "every Dragonfly item is registered")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
