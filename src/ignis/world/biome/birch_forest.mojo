"""`BirchForest`, ported from Dragonfly `server/world/biome/birch_forest.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct BirchForest(Biome, Defaultable):
    """The birch_forest biome (Go `biome.BirchForest`)."""

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
            0.1.
        """
        return 0.1

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.2.
        """
        return 0.2

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x06, 0x77, 0xce, 0xa5).
        """
        return RGBA(0x06, 0x77, 0xCE, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            7 tags.
        """
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
        """Returns the name of the biome (Go `String`).

        Returns:
            `birch_forest`.
        """
        return "birch_forest"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            27.
        """
        return 27
