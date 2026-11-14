"""`SwampHills`, ported from Dragonfly `server/world/biome/swamp_hills.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct SwampHills(Biome, Defaultable):
    """The swampland_mutated biome (Go `biome.SwampHills`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 0.8

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.5

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`)."""
        return -0.1

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`)."""
        return 0.3

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`)."""
        return RGBA(0x61, 0x7B, 0x64, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return [
            "animal",
            "monster",
            "mutated",
            "swamp",
            "overworld_generation",
            "spawns_slimes_on_surface",
            "slime",
            "swamp_water_huge_mushroom",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "swampland_mutated"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 134
