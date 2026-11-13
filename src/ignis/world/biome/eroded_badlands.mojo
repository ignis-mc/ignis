"""`ErodedBadlands`, ported from Dragonfly `server/world/biome/eroded_badlands.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct ErodedBadlands(Biome, Defaultable):
    """The mesa_bryce biome (Go `biome.ErodedBadlands`)."""

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
            RGBA(0x14, 0xa2, 0xc5, 0xa5).
        """
        return RGBA(0x14, 0xA2, 0xC5, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            8 tags.
        """
        return [
            "animal",
            "mesa",
            "monster",
            "mutated",
            "overworld",
            "spawns_mesa_mobs",
            "spawns_warm_variant_farm_animals",
            "surface_mineshaft",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `mesa_bryce`.
        """
        return "mesa_bryce"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            165.
        """
        return 165
