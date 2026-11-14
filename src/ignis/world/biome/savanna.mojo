"""`Savanna`, ported from Dragonfly `server/world/biome/savanna.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct Savanna(Biome, Defaultable):
    """The savanna biome (Go `biome.Savanna`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            1.2.
        """
        return 1.2

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            0.0.
        """
        return 0.0

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`).

        Returns:
            0.125.
        """
        return 0.125

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.05.
        """
        return 0.05

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x2c, 0x8b, 0x9c, 0xa5).
        """
        return RGBA(0x2C, 0x8B, 0x9C, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            7 tags.
        """
        return [
            "animal",
            "monster",
            "overworld",
            "savanna",
            "spawns_savanna_mobs",
            "spawns_warm_variant_farm_animals",
            "has_structure_abandoned_camp",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `savanna`.
        """
        return "savanna"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            35.
        """
        return 35
