from ignis.block.lava import Lava
from ignis.block.water import Water
from ignis.item.bucket import (
    Bucket,
    liquid_bucket_content,
    milk_bucket_content,
)
from std.testing import TestSuite, assert_equal, assert_true


def test_hash_round_trips() raises:
    for it in Bucket.all_items():
        assert_true(Bucket.from_hash(it.hash()) == it)
    var flowing = Bucket(content=liquid_bucket_content(Water(depth=3)))
    assert_true(Bucket.from_hash(flowing.hash()) == flowing)


def test_names() raises:
    assert_equal(Bucket().encode_item().name, "minecraft:bucket")
    assert_equal(
        Bucket(content=liquid_bucket_content(Lava())).encode_item().name,
        "minecraft:lava_bucket",
    )
    assert_equal(
        Bucket(content=milk_bucket_content()).encode_item().name,
        "minecraft:milk_bucket",
    )


def test_data() raises:
    assert_equal(Bucket().max_count(), 16)
    assert_equal(Bucket(content=milk_bucket_content()).max_count(), 1)
    var lava = Bucket(content=liquid_bucket_content(Lava()))
    assert_equal(lava.fuel_info().duration, 1_000_000)
    assert_equal(lava.fuel_info().residue.count(), 1)
    assert_equal(Bucket().fuel_info().duration, 0)
    assert_true(Bucket().consume_info().removes_all_effects)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
