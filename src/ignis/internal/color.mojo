"""The colour type of Go's `image/color` package that Dragonfly uses."""


@fieldwise_init
struct RGBA(Equatable, ImplicitlyCopyable, Writable):
    """A colour with 8-bit red, green, blue and alpha channels (Go
    `color.RGBA`)."""

    var r: UInt8
    """The red channel."""
    var g: UInt8
    """The green channel."""
    var b: UInt8
    """The blue channel."""
    var a: UInt8
    """The alpha channel."""

    def __init__(out self):
        """Creates transparent black (Go `color.RGBA{}`)."""
        self = RGBA(0, 0, 0, 0)

    def __eq__(self, other: Self) -> Bool:
        """Compares two colours."""
        return (
            self.r == other.r
            and self.g == other.g
            and self.b == other.b
            and self.a == other.a
        )

    def write_to(self, mut writer: Some[Writer]):
        """Writes the colour as `{r g b a}`, as Go prints it."""
        writer.write("{", self.r, " ", self.g, " ", self.b, " ", self.a, "}")
