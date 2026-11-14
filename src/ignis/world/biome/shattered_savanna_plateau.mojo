"""`ShatteredSavannaPlateau`, ported from Dragonfly `server/world/biome/shattered_savanna_plateau.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct ShatteredSavannaPlateau(Biome, Defaultable):
    """The savanna_plateau_mutated biome (Go `biome.ShatteredSavannaPlateau`).
    """

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 1.0

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.5

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`)."""
        return 1.05

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`)."""
        return 1.2125

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`)."""
        return RGBA(0x60, 0xB7, 0xFF, 0xA6)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return [
            "animal",
            "monster",
            "mutated",
            "overworld",
            "plateau",
            "savanna",
            "spawns_savanna_mobs",
            "spawns_warm_variant_farm_animals",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "savanna_plateau_mutated"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 164
