"""`JumpBoost`, ported from Dragonfly
`server/entity/effect/jump_boost.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct JumpBoost(Defaultable, ImplicitlyCopyable, LastingType):
    """JumpBoost is a lasting effect that causes the affected entity to be able
    to jump much higher, depending on the level of the effect (Go
    `effect.JumpBoost`)."""

    comptime ID: Int = 8
    """The effect ID (Go `effect.Register(8, JumpBoost)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0xFD, 0xFF, 0x84, 0xFF)
