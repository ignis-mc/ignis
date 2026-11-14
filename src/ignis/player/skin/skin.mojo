"""Skins, ported from Dragonfly `server/player/skin/skin.go`."""

from .animation import Animation
from .cape import Cape
from .model_config import ModelConfig


struct Skin(Copyable, Defaultable):
    """A player's skin (Go `skin.Skin`)."""

    var _w: Int
    var _h: Int
    var persona: Bool
    """Whether the skin is a persona skin."""
    var full_id: String
    """The skin's full ID, unique per skin."""
    var pix: List[UInt8]
    """The RGBA pixels, row by row."""
    var model_config: ModelConfig
    """The geometry the skin uses (the resource patch)."""
    var model: List[UInt8]
    """The geometry JSON."""
    var cape: Cape
    """The cape."""
    var animations: List[Animation]
    """The animations."""

    def __init__(out self):
        """Creates an empty 0x0 skin."""
        self = Self(0, 0)

    def __init__(out self, width: Int, height: Int):
        """Creates a transparent skin (Go `New`)."""
        self._w = width
        self._h = height
        self.persona = False
        self.full_id = String()
        self.pix = List[UInt8](length=max(width * height * 4, 0), fill=0)
        self.model_config = ModelConfig()
        self.model = List[UInt8]()
        self.cape = Cape()
        self.animations = List[Animation]()

    def bounds(self) -> Tuple[Int, Int]:
        """Returns the width and height (Go `Bounds().Max`)."""
        return (self._w, self._h)

    def at(self, x: Int, y: Int) -> Tuple[UInt8, UInt8, UInt8, UInt8]:
        """Returns the RGBA of a pixel (Go `At`)."""
        debug_assert(
            x >= 0 and y >= 0 and x < self._w and y < self._h,
            "pixel coordinates out of bounds",
        )
        var o = x * 4 + self._w * y * 4
        return (self.pix[o], self.pix[o + 1], self.pix[o + 2], self.pix[o + 3])
