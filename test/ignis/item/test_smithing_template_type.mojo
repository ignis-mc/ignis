from ignis.item.smithing_template_type import (
    SmithingTemplateType,
    smithing_template_from_string,
    smithing_templates,
)
from std.testing import TestSuite, assert_equal


def test_values() raises:
    var all = smithing_templates()
    assert_equal(len(all), 19)
    for i in range(len(all)):
        assert_equal(Int(all[i].uint8()), i)
        assert_equal(all[i], SmithingTemplateType(i))


def test_names() raises:
    assert_equal(String(SmithingTemplateType.SENTRY), "sentry")
    assert_equal(String(SmithingTemplateType.WAY_FINDER), "wayfinder")
    assert_equal(String(SmithingTemplateType.SENTRY.name()), "sentry")


def test_from_string() raises:
    for t in smithing_templates():
        assert_equal(smithing_template_from_string(t.name()).value(), t)
    assert_equal(Bool(smithing_template_from_string("nope")), False)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
