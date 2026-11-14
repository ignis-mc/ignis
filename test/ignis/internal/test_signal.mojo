from ignis.internal.signal import (
    SIGINT,
    SIGTERM,
    SignalFD,
    blocked,
    raise_signal,
)
from nethernet.os.poll import wait_readable
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_signal_is_read_not_delivered() raises:
    var s = SignalFD([SIGINT, SIGTERM])
    assert_true(blocked([SIGINT, SIGTERM]))
    assert_false(Bool(s.read()))
    raise_signal(SIGTERM)
    # Blocked, so the process survives and the signal waits in the fd.
    assert_true(wait_readable(s.fd(), 1000))
    assert_equal(s.read().value(), SIGTERM)
    raise_signal(SIGINT)
    assert_equal(s.read().value(), SIGINT)
    assert_false(Bool(s.read()))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
