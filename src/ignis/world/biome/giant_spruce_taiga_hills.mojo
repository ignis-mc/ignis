"""`GiantSpruceTaigaHills`, ported from Dragonfly `server/world/biome/giant_spruce_taiga_hills.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct GiantSpruceTaigaHills(Biome, Defaultable):
    """The redwood_taiga_hills_mutated biome (Go
    `biome.GiantSpruceTaigaHills`)."""

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
            0.55.
        """
        return 0.55

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.5.
        """
        return 0.5

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x28, 0x63, 0x78, 0xa5).
        """
        return RGBA(0x28, 0x63, 0x78, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            9 tags.
        """
        return [
            "animal",
            "forest",
            "hills",
            "mega",
            "monster",
            "mutated",
            "taiga",
            "overworld_generation",
            "spawns_cold_variant_farm_animals",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `redwood_taiga_hills_mutated`.
        """
        return "redwood_taiga_hills_mutated"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            161.
        """
        return 161
