"""Plains, ported from Dragonfly `server/world/biome/plains.go`."""

from . import RGBA, Biome


@fieldwise_init
struct Plains(Biome):
    """The plains biome."""

    def temperature(self) -> Float64:
        """Returns the temperature.

        Returns:
            0.8.
        """
        return 0.8

    def rainfall(self) -> Float64:
        """Returns the rainfall.

        Returns:
            0.4.
        """
        return 0.4

    def depth(self) -> Float64:
        """Returns the depth.

        Returns:
            0.125.
        """
        return 0.125

    def scale(self) -> Float64:
        """Returns the scale.

        Returns:
            0.05.
        """
        return 0.05

    def water_colour(self) -> RGBA:
        """Returns the water colour.

        Returns:
            `#44aff5a5`.
        """
        return RGBA(0x44, 0xAF, 0xF5, 0xA5)

    def tags(self) -> List[String]:
        """Returns the tags.

        Returns:
            The tags `animal`, `monster`, `overworld`, `plains` and
            `bee_habitat`.
        """
        return ["animal", "monster", "overworld", "plains", "bee_habitat"]

    def string(self) -> String:
        """Returns the name.

        Returns:
            `plains`.
        """
        return "plains"

    def encode_biome(self) -> Int:
        """Returns the biome ID.

        Returns:
            1.
        """
        return 1
