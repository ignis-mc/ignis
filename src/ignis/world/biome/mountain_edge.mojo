"""`MountainEdge`, ported from Dragonfly `server/world/biome/mountain_edge.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct MountainEdge(Biome, Defaultable):
    """The extreme_hills_edge biome (Go `biome.MountainEdge`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            0.2.
        """
        return 0.2

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            0.3.
        """
        return 0.3

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`).

        Returns:
            0.8.
        """
        return 0.8

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.4.
        """
        return 0.4

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x04, 0x5c, 0xd5, 0xa5).
        """
        return RGBA(0x04, 0x5C, 0xD5, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            7 tags.
        """
        return [
            "animal",
            "edge",
            "extreme_hills",
            "monster",
            "mountain",
            "overworld",
            "spawns_cold_variant_farm_animals",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `extreme_hills_edge`.
        """
        return "extreme_hills_edge"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            20.
        """
        return 20
