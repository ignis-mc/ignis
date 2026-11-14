"""`ModifiedBadlandsPlateau`, ported from Dragonfly `server/world/biome/modified_badlands_plateau.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct ModifiedBadlandsPlateau(Biome, Defaultable):
    """The mesa_plateau_mutated biome (Go `biome.ModifiedBadlandsPlateau`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`)."""
        return 2.0

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`)."""
        return 0.0

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`)."""
        return 0.45

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`)."""
        return 0.3

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`)."""
        return RGBA(0x55, 0x80, 0x9E, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`)."""
        return [
            "animal",
            "mesa",
            "monster",
            "mutated",
            "overworld",
            "plateau",
            "stone",
            "spawns_mesa_mobs",
            "spawns_warm_variant_farm_animals",
            "surface_mineshaft",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`)."""
        return "mesa_plateau_mutated"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`)."""
        return 167
