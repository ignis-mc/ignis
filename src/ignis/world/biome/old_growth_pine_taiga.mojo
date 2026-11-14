"""`OldGrowthPineTaiga`, ported from Dragonfly `server/world/biome/old_growth_pine_taiga.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct OldGrowthPineTaiga(Biome, Defaultable):
    """The mega_taiga biome (Go `biome.OldGrowthPineTaiga`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 0.3

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.8

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`)."""
        return 0.2

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`)."""
        return 0.2

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`)."""
        return RGBA(0x2D, 0x6D, 0x77, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return [
            "animal",
            "forest",
            "mega",
            "monster",
            "overworld",
            "rare",
            "taiga",
            "has_structure_trail_ruins",
            "spawns_cold_variant_farm_animals",
            "has_structure_abandoned_camp",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "mega_taiga"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 32
