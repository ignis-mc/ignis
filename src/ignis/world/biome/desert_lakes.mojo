"""`DesertLakes`, ported from Dragonfly `server/world/biome/desert_lakes.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct DesertLakes(Biome, Defaultable):
    """The desert_mutated biome (Go `biome.DesertLakes`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            2.0.
        """
        return 2.0

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            0.0.
        """
        return 0.0

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`).

        Returns:
            0.225.
        """
        return 0.225

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.25.
        """
        return 0.25

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x32, 0xa5, 0x98, 0xa5).
        """
        return RGBA(0x32, 0xA5, 0x98, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            6 tags.
        """
        return [
            "desert",
            "monster",
            "mutated",
            "overworld_generation",
            "spawns_gold_rabbits",
            "spawns_warm_variant_farm_animals",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `desert_mutated`.
        """
        return "desert_mutated"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            130.
        """
        return 130
