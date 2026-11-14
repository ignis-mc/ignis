"""`MushroomFieldShore`, ported from Dragonfly `server/world/biome/mushroom_field_shore.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct MushroomFieldShore(Biome, Defaultable):
    """The mushroom_island_shore biome (Go `biome.MushroomFieldShore`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            0.9.
        """
        return 0.9

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            1.0.
        """
        return 1.0

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`).

        Returns:
            0.0.
        """
        return 0.0

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.025.
        """
        return 0.025

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x81, 0x81, 0x93, 0xa5).
        """
        return RGBA(0x81, 0x81, 0x93, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            4 tags.
        """
        return [
            "mooshroom_island",
            "overworld",
            "shore",
            "spawns_without_patrols",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `mushroom_island_shore`.
        """
        return "mushroom_island_shore"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            15.
        """
        return 15
