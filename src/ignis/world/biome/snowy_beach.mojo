"""`SnowyBeach`, ported from Dragonfly `server/world/biome/snowy_beach.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct SnowyBeach(Biome, Defaultable):
    """The cold_beach biome (Go `biome.SnowyBeach`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 0.05

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.3

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`)."""
        return 0.0

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`)."""
        return 0.025

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`)."""
        return RGBA(0x14, 0x63, 0xA5, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return [
            "beach",
            "cold",
            "monster",
            "overworld",
            "spawns_cold_variant_farm_animals",
            "spawns_cold_variant_frogs",
            "spawns_snow_foxes",
            "spawns_white_rabbits",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "cold_beach"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 26
