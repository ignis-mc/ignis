"""`DarkForestHills`, ported from Dragonfly `server/world/biome/dark_forest_hills.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct DarkForestHills(Biome, Defaultable):
    """The roofed_forest_mutated biome (Go `biome.DarkForestHills`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 0.7

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.8

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`)."""
        return 0.2

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`)."""
        return 0.4

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`)."""
        return RGBA(0x3B, 0x6C, 0xD1, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return [
            "animal",
            "forest",
            "monster",
            "mutated",
            "roofed",
            "overworld_generation",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "roofed_forest_mutated"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 157
