"""`SherdType`, ported from Dragonfly `server/item/sherd_type.go`."""

from ..internal.enum import enum_name


struct SherdType(Equatable, ImplicitlyCopyable, Writable):
    """The type of a pottery sherd (Go `SherdType`)."""

    var _v: UInt8

    comptime ANGLER = SherdType(0)
    """Go `SherdTypeAngler()`."""
    comptime ARCHER = SherdType(1)
    """Go `SherdTypeArcher()`."""
    comptime ARMS_UP = SherdType(2)
    """Go `SherdTypeArmsUp()`."""
    comptime BLADE = SherdType(3)
    """Go `SherdTypeBlade()`."""
    comptime BREWER = SherdType(4)
    """Go `SherdTypeBrewer()`."""
    comptime BURN = SherdType(5)
    """Go `SherdTypeBurn()`."""
    comptime DANGER = SherdType(6)
    """Go `SherdTypeDanger()`."""
    comptime EXPLORER = SherdType(7)
    """Go `SherdTypeExplorer()`."""
    comptime FRIEND = SherdType(8)
    """Go `SherdTypeFriend()`."""
    comptime HEART = SherdType(9)
    """Go `SherdTypeHeart()`."""
    comptime HEARTBREAK = SherdType(10)
    """Go `SherdTypeHeartbreak()`."""
    comptime HOWL = SherdType(11)
    """Go `SherdTypeHowl()`."""
    comptime MINER = SherdType(12)
    """Go `SherdTypeMiner()`."""
    comptime MOURNER = SherdType(13)
    """Go `SherdTypeMourner()`."""
    comptime PLENTY = SherdType(14)
    """Go `SherdTypePlenty()`."""
    comptime PRIZE = SherdType(15)
    """Go `SherdTypePrize()`."""
    comptime SHEAF = SherdType(16)
    """Go `SherdTypeSheaf()`."""
    comptime SHELTER = SherdType(17)
    """Go `SherdTypeShelter()`."""
    comptime SKULL = SherdType(18)
    """Go `SherdTypeSkull()`."""
    comptime SNORT = SherdType(19)
    """Go `SherdTypeSnort()`."""
    comptime FLOW = SherdType(20)
    """Go `SherdTypeFlow()`."""
    comptime GUSTER = SherdType(21)
    """Go `SherdTypeGuster()`."""
    comptime SCRAPE = SherdType(22)
    """Go `SherdTypeScrape()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `SherdType{v}`)."""
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`)."""
        return self._v

    def name(self) -> StaticString:
        """Returns the value's name (Go `String`)."""
        return enum_name(
            (
                "angler,archer,arms_up,blade,brewer,burn,danger,explorer,"
                "friend,heart,heartbreak,howl,miner,mourner,plenty,prize,"
                "sheaf,shelter,skull,snort,flow,guster,scrape"
            ),
            Int(self._v),
        )

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's name (Go `String`)."""
        writer.write(self.name())


def sherd_types() -> List[SherdType]:
    """Returns every value (Go `SherdTypes`)."""
    var out = List[SherdType](capacity=23)
    for i in range(23):
        out.append(SherdType(i))
    return out^
