"""`NetherWastes`, ported from Dragonfly `server/world/biome/nether_wastes.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct NetherWastes(Biome, Defaultable):
    """The hell biome (Go `biome.NetherWastes`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            2.0.
        """
        return 2.0

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            0.0.
        """
        return 0.0

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
            RGBA(0x90, 0x59, 0x57, 0xa5).
        """
        return RGBA(0x90, 0x59, 0x57, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            9 tags.
        """
        return [
            "nether",
            "nether_wastes",
            "spawn_endermen",
            "spawn_few_piglins",
            "spawn_ghast",
            "spawn_magma_cubes",
            "spawns_nether_mobs",
            "spawn_zombified_piglin",
            "spawns_warm_variant_farm_animals",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `hell`.
        """
        return "hell"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            8.
        """
        return 8
