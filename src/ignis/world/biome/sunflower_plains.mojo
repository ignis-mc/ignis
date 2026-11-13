"""`SunflowerPlains`, ported from Dragonfly `server/world/biome/sunflower_plains.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct SunflowerPlains(Biome, Defaultable):
    """The sunflower_plains biome (Go `biome.SunflowerPlains`)."""

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
            RGBA(0x60, 0xb7, 0xff, 0xa6).
        """
        return RGBA(0x60, 0xB7, 0xFF, 0xA6)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            6 tags.
        """
        return [
            "animal",
            "monster",
            "mutated",
            "overworld",
            "plains",
            "bee_habitat",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `sunflower_plains`.
        """
        return "sunflower_plains"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            129.
        """
        return 129
