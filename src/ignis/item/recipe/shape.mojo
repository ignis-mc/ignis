"""`Shape`, ported from Dragonfly `server/item/recipe/shape.go`."""


@fieldwise_init
struct Shape(Equatable, ImplicitlyCopyable, Writable):
    """The width and height of a shaped recipe (Go `Shape`)."""

    var _width: Int
    var _height: Int

    def width(self) -> Int:
        """Returns the width of the shape (Go `Width`)."""
        return self._width

    def height(self) -> Int:
        """Returns the height of the shape (Go `Height`)."""
        return self._height

    def write_to(self, mut writer: Some[Writer]):
        """Writes the shape as `widthxheight`."""
        writer.write(self._width, "x", self._height)


def new_shape(width: Int, height: Int) -> Shape:
    """Creates a shape (Go `NewShape`)."""
    return Shape(width, height)
