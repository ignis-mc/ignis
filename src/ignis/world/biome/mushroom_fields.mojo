"""`MushroomFields`, ported from Dragonfly `server/world/biome/mushroom_fields.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct MushroomFields(Biome, Defaultable):
    """The mushroom_island biome (Go `biome.MushroomFields`)."""

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
            0.2.
        """
        return 0.2

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.3.
        """
        return 0.3

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x8a, 0x89, 0x97, 0xa5).
        """
        return RGBA(0x8A, 0x89, 0x97, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            3 tags.
        """
        return ["mooshroom_island", "overworld", "spawns_without_patrols"]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `mushroom_island`.
        """
        return "mushroom_island"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            14.
        """
        return 14
