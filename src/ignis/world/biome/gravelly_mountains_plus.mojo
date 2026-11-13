"""`GravellyMountainsPlus`, ported from Dragonfly `server/world/biome/gravelly_mountains_plus.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct GravellyMountainsPlus(Biome, Defaultable):
    """The extreme_hills_plus_trees_mutated biome (Go
    `biome.GravellyMountainsPlus`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            0.2.
        """
        return 0.2

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            0.3.
        """
        return 0.3

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`).

        Returns:
            1.0.
        """
        return 1.0

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.5.
        """
        return 0.5

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x0e, 0x63, 0xab, 0xa5).
        """
        return RGBA(0x0E, 0x63, 0xAB, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            7 tags.
        """
        return [
            "animal",
            "extreme_hills",
            "forest",
            "monster",
            "mutated",
            "overworld",
            "spawns_cold_variant_farm_animals",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `extreme_hills_plus_trees_mutated`.
        """
        return "extreme_hills_plus_trees_mutated"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            162.
        """
        return 162
