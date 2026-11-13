"""The ambient sounds, ported from Dragonfly `server/world/sound/ambient.go`.
"""

from . import Sound


@fieldwise_init
struct LightningExplode(ImplicitlyCopyable, Sound):
    """LightningExplode .. (Go `sound.LightningExplode`)."""

    comptime SOUND_ID: Int = 86
    """The sound ID of `LightningExplode`."""


@fieldwise_init
struct LightningThunder(ImplicitlyCopyable, Sound):
    """LightningThunder .. (Go `sound.LightningThunder`)."""

    comptime SOUND_ID: Int = 87
    """The sound ID of `LightningThunder`."""
