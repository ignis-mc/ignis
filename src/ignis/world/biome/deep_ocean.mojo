"""`DeepOcean`, ported from Dragonfly `server/world/biome/deep_ocean.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct DeepOcean(Biome, Defaultable):
    """The deep_ocean biome (Go `biome.DeepOcean`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            0.5.
        """
        return 0.5

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            0.5.
        """
        return 0.5

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`).

        Returns:
            -1.8.
        """
        return -1.8

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.1.
        """
        return 0.1

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x17, 0x87, 0xd4, 0xa5).
        """
        return RGBA(0x17, 0x87, 0xD4, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            7 tags.
        """
        return [
            "deep",
            "monster",
            "ocean",
            "overworld",
            "spawns_warm_variant_farm_animals",
            "fast_fishing",
            "high_seas",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `deep_ocean`.
        """
        return "deep_ocean"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            24.
        """
        return 24
