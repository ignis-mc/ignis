"""`PaleGarden`, ported from Dragonfly `server/world/biome/pale_garden.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct PaleGarden(Biome, Defaultable):
    """The pale_garden biome (Go `biome.PaleGarden`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 0.7

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.8

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
        return [
            "monster",
            "overworld",
            "pale_garden",
            "has_structure_abandoned_camp",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "pale_garden"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 193
