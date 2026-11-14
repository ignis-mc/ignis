"""`JungleHills`, ported from Dragonfly `server/world/biome/jungle_hills.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct JungleHills(Biome, Defaultable):
    """The jungle_hills biome (Go `biome.JungleHills`)."""

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
            0.45.
        """
        return 0.45

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.3.
        """
        return 0.3

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x1b, 0x9e, 0xd8, 0xa5).
        """
        return RGBA(0x1B, 0x9E, 0xD8, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            7 tags.
        """
        return [
            "animal",
            "hills",
            "jungle",
            "monster",
            "overworld",
            "spawns_jungle_mobs",
            "spawns_warm_variant_farm_animals",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `jungle_hills`.
        """
        return "jungle_hills"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            22.
        """
        return 22
