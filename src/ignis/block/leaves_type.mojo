"""`LeavesType`, ported from Dragonfly `server/block/leaves_type.go`.
"""

from ..internal.enum import enum_name
from .sapling_type import SaplingType
from .wood_type import WoodType


struct LeavesType(Equatable, ImplicitlyCopyable, Writable):
    """A type of leaves (Go `LeavesType`)."""

    var _t: UInt8

    comptime OAK = LeavesType(0)
    """Go `OakLeaves()`."""
    comptime SPRUCE = LeavesType(1)
    """Go `SpruceLeaves()`."""
    comptime BIRCH = LeavesType(2)
    """Go `BirchLeaves()`."""
    comptime JUNGLE = LeavesType(3)
    """Go `JungleLeaves()`."""
    comptime ACACIA = LeavesType(4)
    """Go `AcaciaLeaves()`."""
    comptime DARK_OAK = LeavesType(5)
    """Go `DarkOakLeaves()`."""
    comptime MANGROVE = LeavesType(6)
    """Go `MangroveLeaves()`."""
    comptime CHERRY = LeavesType(7)
    """Go `CherryLeaves()`."""
    comptime PALE_OAK = LeavesType(8)
    """Go `PaleOakLeaves()`."""
    comptime AZALEA = LeavesType(9)
    """Go `AzaleaLeaves()`."""
    comptime FLOWERING_AZALEA = LeavesType(10)
    """Go `FloweringAzaleaLeaves()`."""
    comptime ORANGE_POPLAR = LeavesType(11)
    """Go `OrangePoplarLeaves()`."""
    comptime RED_POPLAR = LeavesType(12)
    """Go `RedPoplarLeaves()`."""
    comptime YELLOW_POPLAR = LeavesType(13)
    """Go `YellowPoplarLeaves()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `LeavesType{v}`).

        Args:
            v: 0 to 13.
        """
        self._t = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values.

        Args:
            other: The value to compare with.

        Returns:
            True if both are the same.
        """
        return self._t == other._t

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`).

        Returns:
            0 to 13.
        """
        return self._t

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`).

        Args:
            writer: The destination.
        """
        writer.write(
            enum_name(
                (
                    "oak_leaves,spruce_leaves,birch_leaves,jungle_leaves,"
                    "acacia_leaves,dark_oak_leaves,mangrove_leaves,"
                    "cherry_leaves,pale_oak_leaves,azalea_leaves,"
                    "azalea_leaves_flowered,orange_poplar_leaves,"
                    "red_poplar_leaves,yellow_poplar_leaves"
                ),
                Int(self._t),
            )
        )

    def sapling(self) -> Optional[SaplingType]:
        """Returns the sapling the leaves drop (Go `Sapling`).

        Returns:
            The sapling type, or None for mangrove and azalea leaves.
        """
        if self._t <= 5:
            return SaplingType(Int(self._t))
        if self == LeavesType.CHERRY:
            return SaplingType.CHERRY
        if self == LeavesType.PALE_OAK:
            return SaplingType.PALE_OAK
        if self._t >= 11:
            return SaplingType.POPLAR
        return None

    def wood(self) -> Optional[WoodType]:
        """Returns the wood type of trees with the leaves (Go `Wood`).

        Returns:
            The wood type, or None for azalea leaves.
        """
        if self._t <= 5:
            return WoodType(Int(self._t))
        if self == LeavesType.MANGROVE:
            return WoodType.MANGROVE
        if self == LeavesType.CHERRY:
            return WoodType.CHERRY
        if self == LeavesType.PALE_OAK:
            return WoodType.PALE_OAK
        if self._t >= 11:
            return WoodType.POPLAR
        return None


def leaves_types() -> List[LeavesType]:
    """Returns every leaves type (Go `LeavesTypes`).

    Returns:
        The values.
    """
    var out = List[LeavesType](capacity=14)
    for i in range(14):
        out.append(LeavesType(i))
    return out^


def poplar_leaves_types() -> List[LeavesType]:
    """Returns the poplar leaves types (Go `PoplarLeavesTypes`).

    Returns:
        Orange, red and yellow poplar leaves.
    """
    return [
        LeavesType.ORANGE_POPLAR,
        LeavesType.RED_POPLAR,
        LeavesType.YELLOW_POPLAR,
    ]


def wood_leaves_types() -> List[LeavesType]:
    """Returns the leaves types that belong to a wood type (Go
    `WoodLeavesTypes`).

    Returns:
        Every leaves type except the azalea ones.
    """
    var out = List[LeavesType]()
    for t in leaves_types():
        if t.wood():
            out.append(t)
    return out^
