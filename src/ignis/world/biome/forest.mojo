"""`Forest`, ported from Dragonfly `server/world/biome/forest.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct Forest(Biome, Defaultable):
    """The forest biome (Go `biome.Forest`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            0.7.
        """
        return 0.7

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            0.8.
        """
        return 0.8

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`).

        Returns:
            0.1.
        """
        return 0.1

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.2.
        """
        return 0.2

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x1e, 0x97, 0xf2, 0xa5).
        """
        return RGBA(0x1E, 0x97, 0xF2, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            7 tags.
        """
        return [
            "animal",
            "forest",
            "monster",
            "overworld",
            "bee_habitat",
            "has_structure_abandoned_camp",
            "oak_forest",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `forest`.
        """
        return "forest"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            4.
        """
        return 4
