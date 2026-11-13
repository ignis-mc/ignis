"""`BirchForestHills`, ported from Dragonfly `server/world/biome/birch_forest_hills.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct BirchForestHills(Biome, Defaultable):
    """The birch_forest_hills biome (Go `biome.BirchForestHills`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            0.6.
        """
        return 0.6

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            0.6.
        """
        return 0.6

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`).

        Returns:
            0.45.
        """
        return 0.45

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.3.
        """
        return 0.3

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
            "overworld",
            "bee_habitat",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `birch_forest_hills`.
        """
        return "birch_forest_hills"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            28.
        """
        return 28
