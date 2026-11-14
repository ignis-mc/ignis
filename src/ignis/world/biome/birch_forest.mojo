"""`BirchForest`, ported from Dragonfly `server/world/biome/birch_forest.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct BirchForest(Biome, Defaultable):
    """The birch_forest biome (Go `biome.BirchForest`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 0.6

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.6

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`)."""
        return 0.1

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`)."""
        return 0.2

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`)."""
        return RGBA(0x06, 0x77, 0xCE, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return [
            "animal",
            "birch",
            "forest",
            "monster",
            "overworld",
            "bee_habitat",
            "has_structure_abandoned_camp",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "birch_forest"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 27
