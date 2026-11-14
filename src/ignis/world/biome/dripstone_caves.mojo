"""`DripstoneCaves`, ported from Dragonfly `server/world/biome/dripstone_caves.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct DripstoneCaves(Biome, Defaultable):
    """The dripstone_caves biome (Go `biome.DripstoneCaves`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 0.2

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.0

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`)."""
        return 0.1

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`)."""
        return 0.2

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`)."""
        return RGBA(0x60, 0xB7, 0xFF, 0xA6)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return ["caves", "overworld", "dripstone_caves", "monster"]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "dripstone_caves"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 188
