"""`MangroveSwamp`, ported from Dragonfly `server/world/biome/mangrove_swamp.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct MangroveSwamp(Biome, Defaultable):
    """The mangrove_swamp biome (Go `biome.MangroveSwamp`)."""

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
            RGBA(0x60, 0xb7, 0xff, 0xa6).
        """
        return RGBA(0x60, 0xB7, 0xFF, 0xA6)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            7 tags.
        """
        return [
            "mangrove_swamp",
            "overworld",
            "monster",
            "spawns_slimes_on_surface",
            "spawns_warm_variant_farm_animals",
            "spawns_warm_variant_frogs",
            "slime",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `mangrove_swamp`.
        """
        return "mangrove_swamp"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            191.
        """
        return 191
