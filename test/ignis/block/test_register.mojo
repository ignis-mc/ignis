from ignis.block.bedrock import Bedrock
from ignis.block.grass import Grass
from ignis.block.hash import HASH_GRASS, HASH_WOOL
from ignis.block.register import VanillaBlocks, vanilla_block_registry
from std.testing import TestSuite, assert_false, assert_true


def test_vanilla_blocks() raises:
    assert_true(VanillaBlocks.contains(HASH_GRASS))
    assert_false(VanillaBlocks.contains(HASH_WOOL))


def test_vanilla_block_registry() raises:
    var br = vanilla_block_registry()
    assert_true(br.finalized())
    assert_true(br.is_block[Grass](br.block_runtime_id(Grass())))
    var burning = br.block_runtime_id(Bedrock(infinite_burning=True))
    assert_true(br.block[Bedrock](burning).value().infinite_burning)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
