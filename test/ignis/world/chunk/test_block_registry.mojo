from ignis.block.register import vanilla_block_registry
from ignis.world.block_state import Properties
from ignis.world.chunk.block_registry import BlockRegistry
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _air_name[R: BlockRegistry](br: R) -> String:
    return br.runtime_id_to_state(br.air_runtime_id()).value().name


def test_basic_registry_is_a_chunk_registry() raises:
    var br = vanilla_block_registry()
    assert_equal(_air_name(br), "minecraft:air")
    assert_false(br.random_tick_block(br.air_runtime_id()))
    assert_false(br.nbt_block(br.air_runtime_id()))
    assert_false(br.liquid_block(br.air_runtime_id()))
    assert_false(br.liquid_displacing_block(br.air_runtime_id()))
    assert_false(br.runtime_id_to_state(UInt32(br.block_count())))
    assert_false(br.runtime_id_to_hash(UInt32(br.block_count())))
    assert_true(br.default_properties("minecraft:bedrock"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
