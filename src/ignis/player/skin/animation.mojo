"""Skin animations, ported from Dragonfly `server/player/skin/animation.go`.

Go's `image.Image` methods become `bounds`/`at` returning plain values.
"""

comptime AnimationType = Int
"""The kind of a skin animation (Go `AnimationType`)."""
comptime ANIMATION_HEAD: AnimationType = 0
comptime ANIMATION_BODY_32X32: AnimationType = 1
comptime ANIMATION_BODY_128X128: AnimationType = 2


struct Animation(Copyable):
    """An animation over a skin (Go `skin.Animation`)."""

    var _w: Int
    var _h: Int
    var _type: AnimationType
    var pix: List[UInt8]
    """The RGBA pixels, row by row."""
    var frame_count: Int
    """How many frames `pix` holds."""
    var animation_expression: Int
    """The expression of the animation."""

    def __init__(
        out self,
        width: Int,
        height: Int,
        expression: Int,
        animation_type: AnimationType,
    ):
        """Creates an empty one-frame animation (Go `NewAnimation`)."""
        self._w = width
        self._h = height
        self._type = animation_type
        self.pix = List[UInt8](length=max(width * height * 4, 0), fill=0)
        self.frame_count = 1
        self.animation_expression = expression

    def type(self) -> AnimationType:
        """Returns the kind of animation (Go `Type`)."""
        return self._type

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
