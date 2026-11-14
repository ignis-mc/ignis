from ignis.server.conf import Config
from ignis.server.server import (
    data_driven_block_entries,
    flat_world,
    item_entries,
    parse_skin,
)
from ignis.session.session import load_biome_definitions
from minecraft.protocol.login.data import ClientData
from minecraft.protocol.packet.packet import PacketData
from minecraft.protocol.packet.biome_definition_list import (
    BiomeDefinitionList,
)
from minecraft.protocol.packet.id import ID_BIOME_DEFINITION_LIST
from nethernet.crypto.base64 import base64_encode
from std.testing import TestSuite, assert_equal, assert_true


def test_item_entries() raises:
    var items = item_entries("resources/vanilla_items.nbt")
    # Dragonfly v0.11.6 sends 2080 entries (see interop/items).
    assert_equal(len(items), 2080)
    var found = False
    for ref it in items:
        if it.name == "minecraft:shield":
            found = True
            assert_equal(it.runtime_id, 358)
    assert_true(found)


def test_data_driven_blocks() raises:
    var blocks = data_driven_block_entries("resources/data_driven_blocks.nbt")
    # Dragonfly's StartGame lists 98 blocks.
    assert_equal(len(blocks), 98)
    for ref b in blocks:
        assert_true(b.name.startswith("minecraft:"))
        assert_true(len(b.properties.raw) > 3)


def test_biome_definitions() raises:
    var raw = load_biome_definitions()
    var pk = PacketData.parse(Span(raw))
    assert_equal(pk.id(), ID_BIOME_DEFINITION_LIST)
    var list = pk.decode[BiomeDefinitionList](0, False)
    assert_equal(len(list.biome_definitions), 89)


def test_parse_skin() raises:
    var data = ClientData()
    data.skin_image_width = 64
    data.skin_image_height = 32
    var pixels = List[UInt8](length=64 * 32 * 4, fill=7)
    data.skin_data = base64_encode(Span(pixels))
    data.skin_id = "custom-skin"
    var s = parse_skin(data)
    assert_equal(len(s.skin_data), 64 * 32 * 4)
    assert_equal(s.full_id, "custom-skin")
    assert_equal(String(unsafe_from_utf8=Span(s.skin_geometry)), "{}")
    assert_true(s.trusted)
    # Bad base64 decodes to nothing, as Go ignores the error.
    data.skin_data = "!!!"
    assert_equal(len(parse_skin(data).skin_data), 0)


def test_flat_world_spawn() raises:
    var w = flat_world(Config(), 0)
    assert_equal(w.spawn().y(), -59)
    assert_equal(w.name(), "World")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
