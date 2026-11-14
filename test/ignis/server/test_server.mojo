from ignis.server.conf import Config
from ignis.server.server import (
    data_driven_block_entries,
    open_world,
    item_entries,
    parse_skin,
)
from ignis.session.session import biome_definition_packet
from ignis.world.biome.register import vanilla_biome_registry
from minecraft.protocol.login.data import ClientData
from minecraft.protocol.packet.packet import PacketData
from minecraft.protocol.packet.biome_definition_list import (
    BiomeDefinitionList,
)
from minecraft.protocol.packet.id import ID_BIOME_DEFINITION_LIST
from nethernet.crypto.base64 import base64_encode
from nethernet.wire import hex_encode
from std.testing import TestSuite, assert_equal, assert_true
from support.go_values import read_lines
from support.tempdir import remove_all, temp_dir
from ignis.block.cube.pos import Pos
from ignis.block.stone import Stone
from ignis.internal.fs import exists, join


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
    var raw = biome_definition_packet(vanilla_biome_registry())
    var pk = PacketData.parse(Span(raw))
    assert_equal(pk.id(), ID_BIOME_DEFINITION_LIST)
    var list = pk.decode[BiomeDefinitionList](0, False)
    assert_equal(len(list.biome_definitions), 89)
    # The payload is Dragonfly's packet (test/data/world/defs.txt, from
    # interop/world).
    var want = String()
    for line in read_lines("test/data/world/defs.txt"):
        if line.startswith("biome_definition_list\t"):
            want = String(line.split("\t")[1])
    assert_equal(hex_encode(Span(pk.payload)), want)


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
    var w = open_world(Config(), 0)
    assert_equal(w.spawn().y(), -59)
    assert_equal(w.name(), "World")


def test_world_on_disk_persists() raises:
    var dir = temp_dir("server-world")
    var conf = Config()
    conf.world_folder = join(dir, "world")
    conf.world_name = "Disk"
    var w = open_world(conf, 0)
    assert_equal(w.spawn().y(), -59)
    var stone = w.block_registry()[].block_runtime_id(Stone())
    w.set_block_runtime_id(Pos(3, -50, 4), stone)
    w.set_time(1234)
    w.close()
    _ = w^
    assert_true(exists(join(conf.world_folder.value(), "level.dat")))
    # The second open reads level.dat and the stored chunk; the name in the
    # config only applies to new worlds.
    conf.world_name = "Ignored"
    var again = open_world(conf, 0)
    assert_equal(again.name(), "Disk")
    assert_equal(again.time(), 1234)
    assert_equal(again.spawn().y(), -59)
    assert_equal(again.block(Pos(3, -50, 4)), stone)
    again.close()
    _ = again^
    remove_all(dir)


def test_surface_spawn() raises:
    # A level.dat with vanilla's spawn Y of 32767 spawns on the surface.
    var dir = temp_dir("server-spawn")
    var conf = Config()
    conf.world_folder = join(dir, "world")
    var w = open_world(conf, 0)
    w.set_spawn(Pos(5, 32767, 7))
    w.close()
    _ = w^
    var again = open_world(conf, 0)
    assert_equal(again.spawn().y(), -60)
    assert_equal(again.spawn().x(), 5)
    again.close()
    _ = again^
    remove_all(dir)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
