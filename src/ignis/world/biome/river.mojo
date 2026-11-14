"""`River`, ported from Dragonfly `server/world/biome/river.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct River(Biome, Defaultable):
    """The river biome (Go `biome.River`)."""

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
            -0.5.
        """
        return -0.5

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.0.
        """
        return 0.0

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x00, 0x84, 0xff, 0xa5).
        """
        return RGBA(0x00, 0x84, 0xFF, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            5 tags.
        """
        return [
            "overworld",
            "spawns_more_frequent_drowned",
            "spawns_reduced_water_ambient_mobs",
            "spawns_river_mobs",
            "river",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `river`.
        """
        return "river"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            7.
        """
        return 7
