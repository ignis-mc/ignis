"""`FrozenPeaks`, ported from Dragonfly `server/world/biome/frozen_peaks.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct FrozenPeaks(Biome, Defaultable):
    """The frozen_peaks biome (Go `biome.FrozenPeaks`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return -0.7

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.9

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
            "mountains",
            "monster",
            "overworld",
            "frozen",
            "frozen_peaks",
            "spawns_cold_variant_farm_animals",
            "spawns_cold_variant_frogs",
            "spawns_snow_foxes",
            "spawns_white_rabbits",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "frozen_peaks"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 183
