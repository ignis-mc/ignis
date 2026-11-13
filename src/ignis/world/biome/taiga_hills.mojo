"""`TaigaHills`, ported from Dragonfly `server/world/biome/taiga_hills.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct TaigaHills(Biome, Defaultable):
    """The taiga_hills biome (Go `biome.TaigaHills`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            0.25.
        """
        return 0.25

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
            RGBA(0x23, 0x65, 0x83, 0xa5).
        """
        return RGBA(0x23, 0x65, 0x83, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            7 tags.
        """
        return [
            "animal",
            "hills",
            "monster",
            "overworld",
            "forest",
            "taiga",
            "spawns_cold_variant_farm_animals",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `taiga_hills`.
        """
        return "taiga_hills"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            19.
        """
        return 19
