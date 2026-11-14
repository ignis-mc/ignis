"""`SnowyTaigaMountains`, ported from Dragonfly `server/world/biome/snowy_taiga_mountains.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct SnowyTaigaMountains(Biome, Defaultable):
    """The cold_taiga_mutated biome (Go `biome.SnowyTaigaMountains`)."""

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
            0.3.
        """
        return 0.3

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.4.
        """
        return 0.4

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x20, 0x5e, 0x83, 0xa5).
        """
        return RGBA(0x20, 0x5E, 0x83, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            8 tags.
        """
        return [
            "animal",
            "cold",
            "forest",
            "monster",
            "mutated",
            "taiga",
            "overworld_generation",
            "spawns_cold_variant_farm_animals",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `cold_taiga_mutated`.
        """
        return "cold_taiga_mutated"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            158.
        """
        return 158
