"""`WindsweptForest`, ported from Dragonfly `server/world/biome/windswept_forest.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct WindsweptForest(Biome, Defaultable):
    """The extreme_hills_plus_trees biome (Go `biome.WindsweptForest`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 0.2

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.3

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`)."""
        return 1.0

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`)."""
        return 0.5

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`)."""
        return RGBA(0x0E, 0x63, 0xAB, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return [
            "animal",
            "extreme_hills",
            "forest",
            "monster",
            "mountain",
            "overworld",
            "spawns_cold_variant_farm_animals",
            "has_structure_abandoned_camp",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "extreme_hills_plus_trees"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 34
