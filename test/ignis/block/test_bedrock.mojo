from ignis.block.bedrock import Bedrock
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_hash_round_trips() raises:
    for b in Bedrock.all_states():
        assert_true(Bedrock.from_hash(b.hash()) == b)


def test_encode_block() raises:
    assert_equal(
        String(Bedrock(infinite_burning=True).encode_block()),
        "minecraft:bedrock{infiniburn_bit=b:1}",
    )


def test_behaviour() raises:
    assert_true(Bedrock().supports_end_crystal())


def test_encode_item() raises:
    assert_equal(Bedrock().encode_item().name, "minecraft:bedrock")
    assert_equal(len(Bedrock.all_items()), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
