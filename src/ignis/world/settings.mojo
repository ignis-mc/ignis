"""World settings, ported from Dragonfly `server/world/settings.go`.

Go shares one `*Settings` between worlds created from the same provider and
guards it with a mutex. Ignis worlds own their `Settings`; there is nothing
to lock on the single loop thread.
"""

from ..block.cube.pos import Pos
from ..internal.rand import Rand
from .difficulty import DIFFICULTY_NORMAL, Difficulty
from .game_mode import GAME_MODE_SURVIVAL, GameMode


@fieldwise_init
struct Settings(Copyable, Writable):
    """The settings of a World, typically saved to `level.dat` (Go
    `Settings`)."""

    var name: String
    """The display name of the world."""
    var spawn: Pos
    """Where new players spawn."""
    var time: Int64
    """The time of day; advances every tick while `time_cycle` is set."""
    var time_cycle: Bool
    """Whether time advances."""
    var rain_time: Int64
    """Ticks until rain toggles; counts down while `weather_cycle` is
    set."""
    var raining: Bool
    """Whether it is raining."""
    var thunder_time: Int64
    """Ticks until thunder toggles; counts down while `weather_cycle` is
    set."""
    var thundering: Bool
    """Whether it is thundering (only effective while raining)."""
    var weather_cycle: Bool
    """Whether weather changes by itself."""
    var required_sleep_ticks: Int64
    """Ticks players must still sleep before the time is set to day."""
    var current_tick: Int64
    """The world's tick counter; only ever goes up."""
    var default_game_mode: GameMode
    """The game mode of players joining for the first time."""
    var difficulty: Difficulty
    """The difficulty."""
    var tick_range: Int32
    """The radius in chunks around viewers in which blocks and entities are
    ticked; 0 disables ticking."""


def default_settings(mut r: Rand) -> Settings:
    """Returns the settings of a new world (Go `defaultSettings`)."""
    var rain = Int64(r.int_n(8400) + 600) * 20
    var thunder = Int64(r.int_n(8400) + 600) * 20
    return Settings(
        name="World",
        spawn=Pos(0, 0, 0),
        time=0,
        time_cycle=True,
        rain_time=rain,
        raining=False,
        thunder_time=thunder,
        thundering=False,
        weather_cycle=True,
        required_sleep_ticks=0,
        current_tick=0,
        default_game_mode=GAME_MODE_SURVIVAL,
        difficulty=DIFFICULTY_NORMAL,
        tick_range=6,
    )
