"""`GiantTreeTaigaHills`, ported from Dragonfly `server/world/biome/giant_tree_taiga_hills.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct GiantTreeTaigaHills(Biome, Defaultable):
    """The mega_taiga_hills biome (Go `biome.GiantTreeTaigaHills`)."""

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
            RGBA(0x28, 0x63, 0x78, 0xa5).
        """
        return RGBA(0x28, 0x63, 0x78, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            8 tags.
        """
        return [
            "animal",
            "forest",
            "hills",
            "mega",
            "monster",
            "overworld",
            "taiga",
            "spawns_cold_variant_farm_animals",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `mega_taiga_hills`.
        """
        return "mega_taiga_hills"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            33.
        """
        return 33
