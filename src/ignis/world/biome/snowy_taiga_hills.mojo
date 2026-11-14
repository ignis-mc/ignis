"""`SnowyTaigaHills`, ported from Dragonfly `server/world/biome/snowy_taiga_hills.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct SnowyTaigaHills(Biome, Defaultable):
    """The cold_taiga_hills biome (Go `biome.SnowyTaigaHills`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            -0.5.
        """
        return -0.5

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            0.4.
        """
        return 0.4

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
            RGBA(0x24, 0x5b, 0x78, 0xa5).
        """
        return RGBA(0x24, 0x5B, 0x78, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            10 tags.
        """
        return [
            "animal",
            "cold",
            "forest",
            "hills",
            "monster",
            "overworld",
            "taiga",
            "spawns_cold_variant_farm_animals",
            "spawns_cold_variant_frogs",
            "spawns_white_rabbits",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `cold_taiga_hills`.
        """
        return "cold_taiga_hills"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            31.
        """
        return 31
