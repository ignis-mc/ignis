"""`FrozenRiver`, ported from Dragonfly `server/world/biome/frozen_river.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct FrozenRiver(Biome, Defaultable):
    """The frozen_river biome (Go `biome.FrozenRiver`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            0.0.
        """
        return 0.0

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
            RGBA(0x18, 0x53, 0x90, 0xa5).
        """
        return RGBA(0x18, 0x53, 0x90, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            8 tags.
        """
        return [
            "frozen",
            "overworld",
            "river",
            "spawns_cold_variant_farm_animals",
            "spawns_cold_variant_frogs",
            "spawns_river_mobs",
            "spawns_snow_foxes",
            "spawns_white_rabbits",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `frozen_river`.
        """
        return "frozen_river"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            11.
        """
        return 11
