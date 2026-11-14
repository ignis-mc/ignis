"""`Swamp`, ported from Dragonfly `server/world/biome/swamp.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct Swamp(Biome, Defaultable):
    """The swampland biome (Go `biome.Swamp`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 0.8

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.9

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`)."""
        return -0.2

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`)."""
        return 0.1

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`)."""
        return RGBA(0x61, 0x7B, 0x64, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return [
            "animal",
            "monster",
            "overworld",
            "swamp",
            "spawns_slimes_on_surface",
            "slime",
            "swamp_water_huge_mushroom",
            "has_structure_abandoned_camp",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "swampland"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 6
