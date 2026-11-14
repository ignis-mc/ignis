"""`IceSpikes`, ported from Dragonfly `server/world/biome/ice_spikes.go`."""

from ...internal.color import RGBA
from . import Biome


@fieldwise_init
struct IceSpikes(Biome, Defaultable):
    """The ice_plains_spikes biome (Go `biome.IceSpikes`)."""

    def temperature(self) -> Float64:
        """Returns the temperature (Go `Temperature`).

        Returns:
            0.0.
        """
        return 0.0

    def rainfall(self) -> Float64:
        """Returns the rainfall (Go `Rainfall`).

        Returns:
            1.0.
        """
        return 1.0

    def depth(self) -> Float64:
        """Returns the depth (Go `Depth`).

        Returns:
            0.425.
        """
        return 0.425

    def scale(self) -> Float64:
        """Returns the scale (Go `Scale`).

        Returns:
            0.45.
        """
        return 0.45

    def water_colour(self) -> RGBA:
        """Returns the colour of water in the biome (Go `WaterColour`).

        Returns:
            RGBA(0x60, 0xb7, 0xff, 0xa6).
        """
        return RGBA(0x60, 0xB7, 0xFF, 0xA6)

    def tags(self) -> List[String]:
        """Returns the tags of the biome (Go `Tags`).

        Returns:
            8 tags.
        """
        return [
            "frozen",
            "ice_plains",
            "monster",
            "mutated",
            "overworld",
            "spawns_cold_variant_farm_animals",
            "spawns_cold_variant_frogs",
            "spawns_white_rabbits",
        ]

    def string(self) -> String:
        """Returns the name of the biome (Go `String`).

        Returns:
            `ice_plains_spikes`.
        """
        return "ice_plains_spikes"

    def encode_biome(self) -> Int:
        """Returns the biome ID (Go `EncodeBiome`).

        Returns:
            140.
        """
        return 140
