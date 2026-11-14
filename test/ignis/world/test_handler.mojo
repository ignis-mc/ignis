from ignis.world.handler import NopHandler
from std.testing import TestSuite, assert_true
from support.world_runtime import RecordingHandler, new_world


def test_handler_events() raises:
    var w = new_world()
    assert_true(not w.handler())
    w.handle(RecordingHandler())
    assert_true(w.handler())
    # The handler sees the close, then the world drops it (Go sets
    # NopHandler).
    w.close()
    assert_true(not w.handler())


def test_nop_handler() raises:
    _ = NopHandler()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
