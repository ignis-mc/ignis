from ignis.block.register import vanilla_block_registry
from ignis.item.creative.creative import load_creative_items
from ignis.item.register import vanilla_item_registry
from ignis.session.creative import creative_content, delete_damage
from minecraft.nbt.decode import from_nbt
from minecraft.nbt.encode import to_nbt
from minecraft.nbt.nbt import LITTLE_ENDIAN
from minecraft.protocol.item import ItemStack
from minecraft.protocol.writer import Writer
from std.testing import TestSuite, assert_equal, assert_true
from support.item_vectors import canonical, sorted_tree


def _stack(s: ItemStack) raises -> String:
    var n = String("{}")
    if len(s.nbt_data.raw) != 0:
        var t = from_nbt(s.nbt_data)
        n = canonical(t, t.root())
    return String(
        t"{s.item_type.network_id}:{s.item_type.metadata_value}*{s.count}"
        t" {s.block_runtime_id} {n}"
    )


def _sorted(var s: ItemStack) raises -> ItemStack:
    if len(s.nbt_data.raw) != 0:
        s.nbt_data = to_nbt(sorted_tree(from_nbt(s.nbt_data)), LITTLE_ENDIAN)
    return s^


def test_creative_content_matches_dragonfly() raises:
    """The CreativeContent packet lists the groups and items Dragonfly sends
    (`creative.txt` from `interop/items`) and, with NBT keys sorted, has the
    same bytes (`creative_content.bin`)."""
    var br = vanilla_block_registry()
    var reg = vanilla_item_registry()
    var c = load_creative_items(br, reg)
    var pk = creative_content(br, reg, c)
    var got = List[String]()
    for i in range(len(pk.groups)):
        ref g = pk.groups[i]
        got.append(String(t"g\t{i}\t{g.category}\t{g.name}\t{_stack(g.icon)}"))
    for ref it in pk.items:
        got.append(
            String(
                t"i\t{it.creative_item_network_id}\t{it.group_index}\t"
                t"{_stack(it.item)}"
            )
        )
    var want = List[String]()
    with open("test/data/items/creative.txt", "r") as f:
        for line in f.read().split("\n"):
            if line.byte_length() != 0:
                want.append(String(line))
    var mismatches = 0
    var n = min(len(got), len(want))
    for i in range(n):
        if got[i] != want[i]:
            mismatches += 1
            if mismatches <= 20:
                print("want:", want[i])
                print("got: ", got[i])
    assert_equal(len(got), len(want), "group and item count")
    assert_equal(mismatches, 0, "every creative entry matches Dragonfly")

    for ref g in pk.groups:
        g.icon = _sorted(g.icon.copy())
    for ref it in pk.items:
        it.item = _sorted(it.item.copy())
    var w = Writer(0)
    pk.marshal(w)
    var bytes = w.take()
    var expected: List[UInt8]
    with open("test/data/items/creative_content.bin", "r") as f:
        expected = f.read_bytes()
    assert_equal(len(bytes), len(expected))
    assert_true(bytes == expected, "CreativeContent bytes match")


def test_delete_damage() raises:
    var s = ItemStack()
    assert_equal(len(delete_damage(s^).nbt_data.raw), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
