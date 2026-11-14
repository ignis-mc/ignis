"""`SoulSandValley`, ported from Dragonfly `server/world/biome/soul_sand_valley.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct SoulSandValley(Biome, Defaultable):
    """The soulsand_valley biome (Go `biome.SoulSandValley`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 2.0

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
        return RGBA(0x90, 0x59, 0x57, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return [
            "nether",
            "soulsand_valley",
            "spawn_ghast",
            "spawn_endermen",
            "spawns_warm_variant_farm_animals",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "soulsand_valley"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 178
