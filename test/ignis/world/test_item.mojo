from ignis.block.bedrock import Bedrock
from ignis.block.dirt import Dirt
from ignis.item.beef import Beef
from ignis.item.item import item_info
from ignis.item.register import vanilla_item_registry
from ignis.item.shears import Shears
from ignis.item.stick import Stick
from ignis.world.item import (
    AnyItem,
    EncodedItem,
    ItemInfo,
    ItemRegistry,
    item_hash,
)
from minecraft.nbt.decode import decode
from minecraft.nbt.nbt import NETWORK_LITTLE_ENDIAN
from nethernet.crypto.sha256 import Sha256
from nethernet.wire import hex_encode
from std.collections import Dict
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)
from support.item_vectors import canonical, load_item_vectors


def _listing(reg: ItemRegistry) raises -> List[String]:
    """The entries as Go's `itemTable` lines, sorted by runtime ID."""
    ref entries = reg.vanilla_entries()
    var order = List[Int]()
    for i in range(len(entries)):
        var j = len(order)
        while (
            j > 0 and entries[order[j - 1]].runtime_id > entries[i].runtime_id
        ):
            j -= 1
        order.insert(j, i)
    var out = List[String]()
    for i in order:
        ref e = entries[i]
        var data = String("-")
        if case .Some(ref d) = e.data:
            data = canonical(d, d.root())
        var cb = 1 if e.component_based else 0
        out.append(
            String(t"{e.runtime_id}\t{e.name}\t{cb}\t{e.version}\t{data}")
        )
    return out^


def test_item_table_matches_dragonfly() raises:
    var reg = vanilla_item_registry()
    var v = load_item_vectors()
    var lines = _listing(reg)
    assert_equal(String(len(lines)), v["items.count"])
    var h = Sha256()
    for line in lines:
        h.update((line + "\n").as_bytes())
    var digest = h.finish()
    assert_equal(hex_encode(Span(digest)), v["items.sha256"])


def test_item_table_sample() raises:
    var reg = vanilla_item_registry()
    var by_rid = Dict[String, String]()
    for line in _listing(reg):
        by_rid[String(line.split("\t")[0])] = line
    var n = 0
    with open("test/data/items/items_sample.txt", "r") as f:
        for want in f.read().split("\n"):
            if want.byte_length() == 0:
                continue
            assert_equal(by_rid[String(want.split("\t")[0])], String(want))
            n += 1
    assert_equal(n, 462)


def test_item_runtime_ids_match_dragonfly() raises:
    var reg = vanilla_item_registry()
    var v = load_item_vectors()
    var id = reg.item_runtime_id(Stick()).value()
    assert_equal(String(id.runtime_id), v["item.stick.rid"])
    assert_equal(String(id.meta), v["item.stick.meta"])
    assert_equal(
        String(reg.item_runtime_id(Beef(cooked=True)).value().runtime_id),
        v["item.cooked_beef.rid"],
    )
    assert_equal(
        String(reg.item_runtime_id(Dirt(coarse=True)).value().runtime_id),
        v["item.coarse_dirt.rid"],
    )
    assert_equal(
        String(
            reg.any_item_runtime_id(AnyItem.of(Shears())).value().runtime_id
        ),
        v["item.shears.rid"],
    )


def test_item_by_runtime_id() raises:
    var reg = vanilla_item_registry()
    var rid = reg.runtime_id("minecraft:cooked_beef").value()
    var found = reg.item_by_runtime_id(rid, 0).value()
    assert_true(found.item.get[Beef]().value() == Beef(cooked=True))
    assert_false(found.item.block)
    # Unknown metadata falls back to metadata 0 (Go `ItemByName`).
    assert_true(reg.item_by_runtime_id(rid, 7).value().item == found.item)
    var shears = reg.item_by_name("minecraft:shears", 0).value()
    assert_equal(shears.info.max_count, 1)
    assert_equal(shears.info.max_durability, 238)
    var dirt = reg.item_by_name("minecraft:dirt", 0).value()
    assert_true(dirt.item.block)
    assert_true(dirt.item.get[Dirt]().value() == Dirt())
    assert_false(reg.item_by_name("minecraft:no_such_item", 0))
    # Burning bedrock is a block state but not a registered item.
    assert_false(reg.encode_item(AnyItem.of(Bedrock(infinite_burning=True))))


def test_register_errors() raises:
    var reg = vanilla_item_registry()
    with assert_raises(contains="already exists"):
        reg.register_item(Stick(), ItemInfo())
    var empty = ItemRegistry()
    with assert_raises(contains="does not have a runtime ID"):
        empty.register_item(Stick(), ItemInfo())


def test_item_hash() raises:
    # FNV-1a 64 of the Go type name, computed at compile time.
    comptime h = Stick.BASE_HASH
    assert_equal(h, item_hash("Stick"))
    assert_equal(h, 17492513201671331655)
    assert_true(Stick.BASE_HASH != Shears.BASE_HASH)


def test_any_item() raises:
    var a = AnyItem.of(Beef(cooked=True))
    assert_true(a.is_a[Beef]())
    assert_false(a.is_a[Stick]())
    assert_false(a.get[Stick]())
    assert_true(a == AnyItem(Beef.BASE_HASH, 1, False))
    assert_true(AnyItem.of(Dirt()).block)


def test_item_info() raises:
    assert_true(item_info(Stick()) == ItemInfo())
    var s = item_info(Shears())
    assert_equal(s.max_count, 1)
    assert_equal(s.max_durability, 238)
    assert_false(s.persistent)
    assert_true(s.durable())
    assert_false(ItemInfo().durable())


def test_item_entries() raises:
    var reg = vanilla_item_registry()
    var entries = reg.item_entries()
    assert_equal(len(entries), 2080)
    ref raw = reg.vanilla_entries()
    for i in range(len(entries)):
        assert_equal(entries[i].name, raw[i].name)
        assert_equal(Int32(entries[i].runtime_id), raw[i].runtime_id)
        # The data re-encodes to a root compound with the same value.
        var t = decode(Span(entries[i].data.raw), NETWORK_LITTLE_ENDIAN)
        if case .Some(ref d) = raw[i].data:
            assert_equal(canonical(t, t.root()), canonical(d, d.root()))
        else:
            assert_equal(canonical(t, t.root()), "{}")


def test_encoded_item() raises:
    assert_equal(String(EncodedItem("minecraft:stick", 0)), "minecraft:stick:0")
    assert_true(Stick().encode_item() == EncodedItem("minecraft:stick", 0))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
