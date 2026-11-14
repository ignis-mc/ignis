from ignis.item.banner_pattern_type import BannerPatternType, banner_patterns
from std.testing import TestSuite, assert_equal


def test_values() raises:
    var all = banner_patterns()
    assert_equal(len(all), 10)
    for i in range(len(all)):
        assert_equal(Int(all[i].uint8()), i)
        assert_equal(all[i], BannerPatternType(i))


def test_names() raises:
    assert_equal(String(BannerPatternType.FIELD_MASONED), "field_masoned")
    assert_equal(String(BannerPatternType.GUSTER), "guster")
    assert_equal(
        String(BannerPatternType.FIELD_MASONED.name()), "field_masoned"
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
