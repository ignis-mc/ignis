"""`StonyShore`, ported from Dragonfly `server/world/biome/stony_shore.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct StonyShore(Biome, Defaultable):
    """The stone_beach biome (Go `biome.StonyShore`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 0.2

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.3

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`)."""
        return 0.1

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`)."""
        return 0.8

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`)."""
        return RGBA(0x0D, 0x67, 0xBB, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return ["beach", "monster", "overworld", "stone"]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "stone_beach"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 25
