"""`Meadow`, ported from Dragonfly `server/world/biome/meadow.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct Meadow(Biome, Defaultable):
    """The meadow biome (Go `biome.Meadow`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            0.3.
        """
        return 0.3

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            0.8.
        """
        return 0.8

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
            RGBA(0x60, 0xb7, 0xff, 0xa6).
        """
        return RGBA(0x60, 0xB7, 0xFF, 0xA6)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            6 tags.
        """
        return [
            "mountains",
            "monster",
            "overworld",
            "meadow",
            "bee_habitat",
            "has_structure_abandoned_camp",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `meadow`.
        """
        return "meadow"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            186.
        """
        return 186
