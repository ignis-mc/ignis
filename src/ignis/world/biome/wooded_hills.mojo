"""`WoodedHills`, ported from Dragonfly `server/world/biome/wooded_hills.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct WoodedHills(Biome, Defaultable):
    """The forest_hills biome (Go `biome.WoodedHills`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            0.7.
        """
        return 0.7

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            0.8.
        """
        return 0.8

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
            RGBA(0x05, 0x6b, 0xd1, 0xa5).
        """
        return RGBA(0x05, 0x6B, 0xD1, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            6 tags.
        """
        return [
            "animal",
            "hills",
            "monster",
            "overworld",
            "forest",
            "bee_habitat",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `forest_hills`.
        """
        return "forest_hills"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            18.
        """
        return 18
