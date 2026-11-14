"""Weather, ported from Dragonfly `server/world/weather.go`.

Go's `weather` struct is embedded in `World`; its methods are `World`
methods here (`start_raining`, `stop_raining`, ...). This module holds the
counter logic on `Settings`. Durations are milliseconds; Go converts its
`time.Duration` to ticks the same way (one tick per 50 ms).

Not ported yet: lightning (`tickLightning`, `strikeLightning`), which needs
the lightning entity and block models, and `snowingAt`/`rainingAt`, which
need biome temperatures and block models.
"""

from ..internal.rand import Rand
from .settings import Settings


def set_raining(mut s: Settings, raining: Bool, duration_ms: Int):
    """Turns rain on or off for a duration (Go `setRaining`)."""
    s.raining = raining
    s.rain_time = Int64(duration_ms // 50)


def set_thunder(mut s: Settings, thundering: Bool, duration_ms: Int):
    """Turns thunder on or off for a duration (Go `setThunder`)."""
    s.thundering = thundering
    s.thunder_time = Int64(duration_ms // 50)


def advance_weather(mut s: Settings, mut r: Rand):
    """Counts the rain and thunder timers down by a tick and toggles the
    weather when they run out (Go `advanceWeather`)."""
    s.rain_time -= 1
    s.thunder_time -= 1
    if s.rain_time <= 0:
        # Rain lasts 0.5-1 game days; clear weather 0.5-7.5 days.
        if s.raining:
            set_raining(s, False, (r.int_n(8400) + 600) * 1000)
        else:
            set_raining(s, True, (r.int_n(600) + 600) * 1000)
    if s.thunder_time <= 0:
        # Thunder lasts 3-13 minutes; no thunder 0.5-7.5 days.
        if s.thundering:
            set_thunder(s, False, (r.int_n(8400) + 600) * 1000)
        else:
            set_thunder(s, True, (r.int_n(620) + 180) * 1000)
