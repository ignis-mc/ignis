"""`SnowyPlains`, ported from Dragonfly `server/world/biome/snowy_plains.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct SnowyPlains(Biome, Defaultable):
    """The ice_plains biome (Go `biome.SnowyPlains`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            0.0.
        """
        return 0.0

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            0.5.
        """
        return 0.5

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`).

        Returns:
            0.125.
        """
        return 0.125

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.05.
        """
        return 0.05

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x14, 0x55, 0x9b, 0xa5).
        """
        return RGBA(0x14, 0x55, 0x9B, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            8 tags.
        """
        return [
            "frozen",
            "ice",
            "ice_plains",
            "overworld",
            "spawns_cold_variant_farm_animals",
            "spawns_cold_variant_frogs",
            "spawns_snow_foxes",
            "spawns_white_rabbits",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `ice_plains`.
        """
        return "ice_plains"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            12.
        """
        return 12
