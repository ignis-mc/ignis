"""`SnowyTaiga`, ported from Dragonfly `server/world/biome/snowy_taiga.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct SnowyTaiga(Biome, Defaultable):
    """The cold_taiga biome (Go `biome.SnowyTaiga`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            -0.5.
        """
        return -0.5

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            0.4.
        """
        return 0.4

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`).

        Returns:
            0.2.
        """
        return 0.2

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.2.
        """
        return 0.2

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x20, 0x5e, 0x83, 0xa5).
        """
        return RGBA(0x20, 0x5E, 0x83, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            9 tags.
        """
        return [
            "animal",
            "cold",
            "forest",
            "monster",
            "overworld",
            "taiga",
            "has_structure_trail_ruins",
            "spawns_cold_variant_farm_animals",
            "has_structure_abandoned_camp",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `cold_taiga`.
        """
        return "cold_taiga"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            30.
        """
        return 30
