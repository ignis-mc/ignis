"""`End`, ported from Dragonfly `server/world/biome/end.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct End(Biome, Defaultable):
    """The the_end biome (Go `biome.End`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 0.5

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.5

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`)."""
        return 0.1

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`)."""
        return 0.2

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`)."""
        return RGBA(0x62, 0x52, 0x9E, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return [
            "the_end",
            "spawns_cold_variant_farm_animals",
            "spawns_cold_variant_frogs",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "the_end"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 9
