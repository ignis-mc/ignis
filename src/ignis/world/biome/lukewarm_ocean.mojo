"""`LukewarmOcean`, ported from Dragonfly `server/world/biome/lukewarm_ocean.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct LukewarmOcean(Biome, Defaultable):
    """The lukewarm_ocean biome (Go `biome.LukewarmOcean`)."""

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
            -1.0.
        """
        return -1.0

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.1.
        """
        return 0.1

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x0d, 0x96, 0xdb, 0xa5).
        """
        return RGBA(0x0D, 0x96, 0xDB, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            8 tags.
        """
        return [
            "lukewarm",
            "monster",
            "ocean",
            "overworld",
            "spawns_warm_variant_farm_animals",
            "fast_fishing",
            "high_seas",
            "temperate_ocean",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `lukewarm_ocean`.
        """
        return "lukewarm_ocean"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            42.
        """
        return 42
