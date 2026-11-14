"""`Ocean`, ported from Dragonfly `server/world/biome/ocean.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct Ocean(Biome, Defaultable):
    """The ocean biome (Go `biome.Ocean`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            0.5.
        """
        return 0.5

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            0.5.
        """
        return 0.5

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`).

        Returns:
            -1.0.
        """
        return -1.0

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.1.
        """
        return 0.1

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x17, 0x87, 0xd4, 0xa5).
        """
        return RGBA(0x17, 0x87, 0xD4, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            5 tags.
        """
        return ["monster", "ocean", "overworld", "fast_fishing", "high_seas"]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `ocean`.
        """
        return "ocean"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            0.
        """
        return 0
