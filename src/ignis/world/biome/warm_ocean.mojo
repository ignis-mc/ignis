"""`WarmOcean`, ported from Dragonfly `server/world/biome/warm_ocean.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct WarmOcean(Biome, Defaultable):
    """The warm_ocean biome (Go `biome.WarmOcean`)."""

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
            RGBA(0x02, 0xb0, 0xe5, 0xa5).
        """
        return RGBA(0x02, 0xB0, 0xE5, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            9 tags.
        """
        return [
            "monster",
            "ocean",
            "overworld",
            "warm",
            "spawns_warm_variant_farm_animals",
            "spawns_warm_variant_frogs",
            "fast_fishing",
            "high_seas",
            "temperate_ocean",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `warm_ocean`.
        """
        return "warm_ocean"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            40.
        """
        return 40
