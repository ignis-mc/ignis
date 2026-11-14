"""`SnowyMountains`, ported from Dragonfly `server/world/biome/snowy_mountains.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct SnowyMountains(Biome, Defaultable):
    """The ice_mountains biome (Go `biome.SnowyMountains`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 0.0

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.5

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`)."""
        return 0.45

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`)."""
        return 0.3

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`)."""
        return RGBA(0x11, 0x56, 0xA7, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return [
            "frozen",
            "ice",
            "mountain",
            "overworld",
            "spawns_cold_variant_farm_animals",
            "spawns_cold_variant_frogs",
            "spawns_snow_foxes",
            "spawns_white_rabbits",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "ice_mountains"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 13
