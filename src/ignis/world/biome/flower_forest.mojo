"""`FlowerForest`, ported from Dragonfly `server/world/biome/flower_forest.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct FlowerForest(Biome, Defaultable):
    """The flower_forest biome (Go `biome.FlowerForest`)."""

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
            0.1.
        """
        return 0.1

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.4.
        """
        return 0.4

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x20, 0xa3, 0xcc, 0xa5).
        """
        return RGBA(0x20, 0xA3, 0xCC, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            7 tags.
        """
        return [
            "animal",
            "flower_forest",
            "monster",
            "mutated",
            "overworld",
            "bee_habitat",
            "has_structure_abandoned_camp",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `flower_forest`.
        """
        return "flower_forest"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            132.
        """
        return 132
