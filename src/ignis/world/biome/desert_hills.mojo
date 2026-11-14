"""`DesertHills`, ported from Dragonfly `server/world/biome/desert_hills.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct DesertHills(Biome, Defaultable):
    """The desert_hills biome (Go `biome.DesertHills`)."""

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
            0.45.
        """
        return 0.45

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.3.
        """
        return 0.3

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x1a, 0x7a, 0xa1, 0xa5).
        """
        return RGBA(0x1A, 0x7A, 0xA1, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            6 tags.
        """
        return [
            "desert",
            "hills",
            "monster",
            "overworld",
            "spawns_gold_rabbits",
            "spawns_warm_variant_farm_animals",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `desert_hills`.
        """
        return "desert_hills"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            17.
        """
        return 17
