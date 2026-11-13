"""Biomes: the `Biome` trait from Dragonfly `server/world/biome.go`, and the
vanilla biomes of `server/world/biome`.

Mojo cannot have a module and a package with the same name, so Go's
`world/biome.go` lives in this package's `__init__`.

The biome registry (`RegisterBiome`, `BiomeByID`) comes with the biome
package port; chunks store biome IDs (`encode_biome`).
"""


@fieldwise_init
struct RGBA(Equatable, ImplicitlyCopyable, Writable):
    """A colour with alpha (Go `color.RGBA`)."""

    var r: UInt8
    """Red."""
    var g: UInt8
    """Green."""
    var b: UInt8
    """Blue."""
    var a: UInt8
    """Alpha."""


trait Biome(ImplicitlyCopyable):
    """A region with distinct features, temperature, rainfall and colours."""

    def temperature(self) -> Float64:
        """Returns the temperature of the biome.

        Returns:
            The temperature.
        """
        ...

    def rainfall(self) -> Float64:
        """Returns the rainfall of the biome.

        Returns:
            The rainfall.
        """
        ...

    def depth(self) -> Float64:
        """Returns the depth of the biome.

        Returns:
            The depth.
        """
        ...

    def scale(self) -> Float64:
        """Returns the scale of the biome.

        Returns:
            The scale.
        """
        ...

    def water_colour(self) -> RGBA:
        """Returns the water colour of the biome.

        Returns:
            The colour.
        """
        ...

    def tags(self) -> List[String]:
        """Returns the tags of the biome.

        Returns:
            The tags.
        """
        ...

    def string(self) -> String:
        """Returns the biome name (Go `String`).

        Returns:
            The name, such as `plains`.
        """
        ...

    def encode_biome(self) -> Int:
        """Returns the biome ID used on the network and in chunks.

        Returns:
            The biome ID.
        """
        ...
