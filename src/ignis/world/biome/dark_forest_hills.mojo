"""`DarkForestHills`, ported from Dragonfly `server/world/biome/dark_forest_hills.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct DarkForestHills(Biome, Defaultable):
    """The roofed_forest_mutated biome (Go `biome.DarkForestHills`)."""

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
            0.2.
        """
        return 0.2

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.4.
        """
        return 0.4

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x3b, 0x6c, 0xd1, 0xa5).
        """
        return RGBA(0x3B, 0x6C, 0xD1, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            6 tags.
        """
        return [
            "animal",
            "forest",
            "monster",
            "mutated",
            "roofed",
            "overworld_generation",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `roofed_forest_mutated`.
        """
        return "roofed_forest_mutated"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            157.
        """
        return 157
