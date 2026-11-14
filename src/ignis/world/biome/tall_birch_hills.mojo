"""`TallBirchHills`, ported from Dragonfly `server/world/biome/tall_birch_hills.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct TallBirchHills(Biome, Defaultable):
    """The birch_forest_hills_mutated biome (Go `biome.TallBirchHills`)."""

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
            0.55.
        """
        return 0.55

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.5.
        """
        return 0.5

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x0a, 0x74, 0xc4, 0xa5).
        """
        return RGBA(0x0A, 0x74, 0xC4, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            7 tags.
        """
        return [
            "animal",
            "birch",
            "forest",
            "hills",
            "monster",
            "mutated",
            "overworld_generation",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `birch_forest_hills_mutated`.
        """
        return "birch_forest_hills_mutated"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            156.
        """
        return 156
