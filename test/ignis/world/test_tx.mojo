from ignis.world.tx import Context, SetOpts
from std.testing import TestSuite, assert_false, assert_true


def test_context() raises:
    var ctx = Context()
    assert_false(ctx.cancelled())
    ctx.cancel()
    assert_true(ctx.cancelled())


def test_set_opts() raises:
    var o = SetOpts()
    assert_false(o.disable_block_updates)
    assert_false(o.disable_liquid_displacement)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
