"""`Jungle`, ported from Dragonfly `server/world/biome/jungle.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct Jungle(Biome, Defaultable):
    """The jungle biome (Go `biome.Jungle`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            0.95.
        """
        return 0.95

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            0.9.
        """
        return 0.9

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`).

        Returns:
            0.1.
        """
        return 0.1

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.2.
        """
        return 0.2

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x14, 0xa2, 0xc5, 0xa5).
        """
        return RGBA(0x14, 0xA2, 0xC5, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            8 tags.
        """
        return [
            "animal",
            "has_structure_trail_ruins",
            "jungle",
            "monster",
            "overworld",
            "rare",
            "spawns_jungle_mobs",
            "spawns_warm_variant_farm_animals",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `jungle`.
        """
        return "jungle"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            21.
        """
        return 21
