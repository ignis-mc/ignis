"""`Badlands`, ported from Dragonfly `server/world/biome/badlands.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct Badlands(Biome, Defaultable):
    """The mesa biome (Go `biome.Badlands`)."""

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
            RGBA(0x4e, 0x7f, 0x81, 0xa5).
        """
        return RGBA(0x4E, 0x7F, 0x81, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            7 tags.
        """
        return [
            "animal",
            "mesa",
            "monster",
            "overworld",
            "spawns_mesa_mobs",
            "spawns_warm_variant_farm_animals",
            "surface_mineshaft",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `mesa`.
        """
        return "mesa"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            37.
        """
        return 37
