"""`BambooJungleHills`, ported from Dragonfly `server/world/biome/bamboo_jungle_hills.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct BambooJungleHills(Biome, Defaultable):
    """The bamboo_jungle_hills biome (Go `biome.BambooJungleHills`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 0.95

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.9

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`)."""
        return 0.45

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`)."""
        return 0.3

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`)."""
        return RGBA(0x1B, 0x9E, 0xD8, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return [
            "animal",
            "bamboo",
            "hills",
            "jungle",
            "monster",
            "overworld",
            "spawns_jungle_mobs",
            "spawns_warm_variant_farm_animals",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "bamboo_jungle_hills"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 49
