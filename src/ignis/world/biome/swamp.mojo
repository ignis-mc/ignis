"""`Swamp`, ported from Dragonfly `server/world/biome/swamp.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct Swamp(Biome, Defaultable):
    """The swampland biome (Go `biome.Swamp`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            0.8.
        """
        return 0.8

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            0.9.
        """
        return 0.9

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`).

        Returns:
            -0.2.
        """
        return -0.2

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.1.
        """
        return 0.1

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x61, 0x7b, 0x64, 0xa5).
        """
        return RGBA(0x61, 0x7B, 0x64, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            8 tags.
        """
        return [
            "animal",
            "monster",
            "overworld",
            "swamp",
            "spawns_slimes_on_surface",
            "slime",
            "swamp_water_huge_mushroom",
            "has_structure_abandoned_camp",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `swampland`.
        """
        return "swampland"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            6.
        """
        return 6
