"""`BasaltDeltas`, ported from Dragonfly `server/world/biome/basalt_deltas.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct BasaltDeltas(Biome, Defaultable):
    """The basalt_deltas biome (Go `biome.BasaltDeltas`)."""

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
            RGBA(0x3f, 0x76, 0xe4, 0xa5).
        """
        return RGBA(0x3F, 0x76, 0xE4, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            5 tags.
        """
        return [
            "nether",
            "basalt_deltas",
            "spawn_many_magma_cubes",
            "spawn_ghast",
            "spawns_warm_variant_farm_animals",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `basalt_deltas`.
        """
        return "basalt_deltas"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            181.
        """
        return 181
