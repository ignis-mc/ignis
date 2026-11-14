"""`GiantSpruceTaigaHills`, ported from Dragonfly `server/world/biome/giant_spruce_taiga_hills.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct GiantSpruceTaigaHills(Biome, Defaultable):
    """The redwood_taiga_hills_mutated biome (Go
    `biome.GiantSpruceTaigaHills`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 0.3

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.8

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`)."""
        return 0.55

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`)."""
        return 0.5

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`)."""
        return RGBA(0x28, 0x63, 0x78, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return [
            "animal",
            "forest",
            "hills",
            "mega",
            "monster",
            "mutated",
            "taiga",
            "overworld_generation",
            "spawns_cold_variant_farm_animals",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "redwood_taiga_hills_mutated"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 161
