"""`MushroomFieldShore`, ported from Dragonfly `server/world/biome/mushroom_field_shore.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct MushroomFieldShore(Biome, Defaultable):
    """The mushroom_island_shore biome (Go `biome.MushroomFieldShore`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 0.9

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 1.0

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`)."""
        return 0.0

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`)."""
        return 0.025

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`)."""
        return RGBA(0x81, 0x81, 0x93, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return [
            "mooshroom_island",
            "overworld",
            "shore",
            "spawns_without_patrols",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "mushroom_island_shore"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 15
