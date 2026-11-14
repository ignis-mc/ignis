"""`CrimsonForest`, ported from Dragonfly `server/world/biome/crimson_forest.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct CrimsonForest(Biome, Defaultable):
    """The crimson_forest biome (Go `biome.CrimsonForest`)."""

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
            6 tags.
        """
        return [
            "nether",
            "netherwart_forest",
            "crimson_forest",
            "spawn_few_zombified_piglins",
            "spawn_piglin",
            "spawns_warm_variant_farm_animals",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `crimson_forest`.
        """
        return "crimson_forest"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            179.
        """
        return 179
