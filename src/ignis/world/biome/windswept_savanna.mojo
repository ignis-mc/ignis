"""`WindsweptSavanna`, ported from Dragonfly `server/world/biome/windswept_savanna.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct WindsweptSavanna(Biome, Defaultable):
    """The savanna_mutated biome (Go `biome.WindsweptSavanna`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            2.0.
        """
        return 2.0

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            0.0.
        """
        return 0.0

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`).

        Returns:
            0.3625.
        """
        return 0.3625

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            1.225.
        """
        return 1.225

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x60, 0xb7, 0xff, 0xa6).
        """
        return RGBA(0x60, 0xB7, 0xFF, 0xA6)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            7 tags.
        """
        return [
            "animal",
            "monster",
            "mutated",
            "overworld",
            "savanna",
            "spawns_savanna_mobs",
            "spawns_warm_variant_farm_animals",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `savanna_mutated`.
        """
        return "savanna_mutated"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            163.
        """
        return 163
