"""`FlowerType`, ported from Dragonfly `server/block/flower_type.go`.
"""

from ..internal.enum import enum_name


struct FlowerType(Equatable, ImplicitlyCopyable, Writable):
    """A type of flower (Go `FlowerType`)."""

    var _v: UInt8

    comptime DANDELION = FlowerType(0)
    """Go `Dandelion()`."""
    comptime POPPY = FlowerType(1)
    """Go `Poppy()`."""
    comptime BLUE_ORCHID = FlowerType(2)
    """Go `BlueOrchid()`."""
    comptime ALLIUM = FlowerType(3)
    """Go `Allium()`."""
    comptime AZURE_BLUET = FlowerType(4)
    """Go `AzureBluet()`."""
    comptime RED_TULIP = FlowerType(5)
    """Go `RedTulip()`."""
    comptime ORANGE_TULIP = FlowerType(6)
    """Go `OrangeTulip()`."""
    comptime WHITE_TULIP = FlowerType(7)
    """Go `WhiteTulip()`."""
    comptime PINK_TULIP = FlowerType(8)
    """Go `PinkTulip()`."""
    comptime OXEYE_DAISY = FlowerType(9)
    """Go `OxeyeDaisy()`."""
    comptime CORNFLOWER = FlowerType(10)
    """Go `Cornflower()`."""
    comptime LILY_OF_THE_VALLEY = FlowerType(11)
    """Go `LilyOfTheValley()`."""
    comptime WITHER_ROSE = FlowerType(12)
    """Go `WitherRose()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `FlowerType{v}`).

        Args:
            v: 0 to 12.
        """
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values.

        Args:
            other: The value to compare with.

        Returns:
            True if both are the same.
        """
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`).

        Returns:
            0 to 12.
        """
        return self._v

    def name(self) -> StaticString:
        """Returns the display name (Go `Name`).

        Returns:
            The name.
        """
        return enum_name(
            (
                "Dandelion,Poppy,Blue Orchid,Allium,Azure Bluet,"
                "Red Tulip,Orange Tulip,White Tulip,Pink Tulip,"
                "Oxeye Daisy,Cornflower,Lily of the Valley,Wither Rose"
            ),
            Int(self._v),
        )

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`).

        Args:
            writer: The destination.
        """
        writer.write(
            enum_name(
                (
                    "dandelion,poppy,blue_orchid,allium,azure_bluet,"
                    "red_tulip,orange_tulip,white_tulip,pink_tulip,"
                    "oxeye_daisy,cornflower,lily_of_the_valley,wither_rose"
                ),
                Int(self._v),
            )
        )


def flower_types() -> List[FlowerType]:
    """Returns every flower type (Go `FlowerTypes`).

    Returns:
        The values.
    """
    var out = List[FlowerType](capacity=13)
    for i in range(13):
        out.append(FlowerType(i))
    return out^
