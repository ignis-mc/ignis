"""`Plains`, ported from Dragonfly `server/world/biome/plains.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct Plains(Biome, Defaultable):
    """The plains biome (Go `biome.Plains`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            0.8.
        """
        return 0.8

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            0.4.
        """
        return 0.4

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`).

        Returns:
            0.125.
        """
        return 0.125

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.05.
        """
        return 0.05

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x44, 0xaf, 0xf5, 0xa5).
        """
        return RGBA(0x44, 0xAF, 0xF5, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            5 tags.
        """
        return ["animal", "monster", "overworld", "plains", "bee_habitat"]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `plains`.
        """
        return "plains"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            1.
        """
        return 1
