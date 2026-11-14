"""`Nausea`, ported from Dragonfly
`server/entity/effect/nausea.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct Nausea(Defaultable, ImplicitlyCopyable, LastingType):
    """Nausea is a lasting effect that causes the screen to warp, similarly to
    when entering a nether portal (Go `effect.Nausea`)."""

    comptime ID: Int = 9
    """The effect ID (Go `effect.Register(9, Nausea)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0x55, 0x1D, 0x4A, 0xFF)
