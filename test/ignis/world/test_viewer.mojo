from ignis.block.cube.pos import Pos
from ignis.world.viewer import NopViewer
from std.testing import TestSuite


def test_nop_viewer_accepts_everything() raises:
    # Every method has a default body.
    var v = NopViewer()
    v.view_time(5)
    v.view_block_update(Pos(0, 0, 0), 1, 0)
    v.view_weather(True, False)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
