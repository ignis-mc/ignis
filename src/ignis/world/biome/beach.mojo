"""`Beach`, ported from Dragonfly `server/world/biome/beach.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct Beach(Biome, Defaultable):
    """The beach biome (Go `biome.Beach`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 0.8

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.4

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`)."""
        return 0.0

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`)."""
        return 0.025

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`)."""
        return RGBA(0x15, 0x7C, 0xAB, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return ["beach", "monster", "overworld", "warm"]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "beach"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 16
