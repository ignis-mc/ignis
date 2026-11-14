"""`LegacyFrozenOcean`, ported from Dragonfly `server/world/biome/legacy_frozen_ocean.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct LegacyFrozenOcean(Biome, Defaultable):
    """The legacy_frozen_ocean biome (Go `biome.LegacyFrozenOcean`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 0.0

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.5

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`)."""
        return -1.0

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`)."""
        return 0.1

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`)."""
        return RGBA(0x60, 0xB7, 0xFF, 0xA6)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return [
            "legacy",
            "frozen",
            "ocean",
            "overworld",
            "spawns_cold_variant_farm_animals",
            "spawns_polar_bears_on_alternate_blocks",
            "fast_fishing",
            "high_seas",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "legacy_frozen_ocean"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 10
