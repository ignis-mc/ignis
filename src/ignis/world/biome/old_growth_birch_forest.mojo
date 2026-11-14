"""`OldGrowthBirchForest`, ported from Dragonfly `server/world/biome/old_growth_birch_forest.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct OldGrowthBirchForest(Biome, Defaultable):
    """The birch_forest_mutated biome (Go `biome.OldGrowthBirchForest`)."""

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
            RGBA(0x06, 0x77, 0xce, 0xa5).
        """
        return RGBA(0x06, 0x77, 0xCE, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            9 tags.
        """
        return [
            "animal",
            "birch",
            "forest",
            "monster",
            "mutated",
            "bee_habitat",
            "overworld_generation",
            "has_structure_trail_ruins",
            "has_structure_abandoned_camp",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `birch_forest_mutated`.
        """
        return "birch_forest_mutated"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            155.
        """
        return 155
