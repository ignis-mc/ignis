"""FireworkStar, ported from Dragonfly `server/item/firework_star.go`."""

from minecraft.nbt.nbt import TAG_COMPOUND
from minecraft.nbt.tree import Tag, Tree

from ..world.block import NBTer
from ..world.item import EncodedItem, Item, item_hash
from .colour import Colour, colours, invert_colour
from .firework_explosion import FireworkExplosion
from .item import int32_from_rgba


struct FireworkStar(Equatable, ImplicitlyCopyable, Item, NBTer):
    """An item used to determine the colour, effect and shape of firework
    rockets."""

    comptime BASE_HASH: UInt64 = item_hash("FireworkStar")
    """`item_hash("FireworkStar")`."""

    var firework_explosion: FireworkExplosion
    """The explosion (Go's embedded `FireworkExplosion`); only its colour is
    hashed."""

    def __init__(
        out self, *, firework_explosion: FireworkExplosion = FireworkExplosion()
    ):
        """Creates the item; omitted fields take Go zero values."""
        self.firework_explosion = firework_explosion

    def __eq__(self, other: Self) -> Bool:
        """Compares two stars by explosion."""
        return self.firework_explosion == other.firework_explosion

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the star's NBT (Go `EncodeNBT`)."""
        var c = tag.put_compound(root, "FireworksItem")
        self.firework_explosion.encode_nbt(tag, c)
        _ = tag.put_int(
            root,
            "customColor",
            int32_from_rgba(self.firework_explosion.colour.rgba()),
        )

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the star with its NBT decoded (Go `DecodeNBT`)."""
        var f = self
        if case .Some(c) = tag.get(root, "FireworksItem"):
            if tag.type_of(c) == TAG_COMPOUND:
                f.firework_explosion = f.firework_explosion.decode_nbt(tag, c)
        return f

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`): meta is the inverted colour."""
        return EncodedItem(
            "minecraft:firework_star",
            invert_colour(self.firework_explosion.colour),
        )

    def hash(self) -> UInt64:
        """Returns the item hash: the explosion's colour."""
        return UInt64(self.firework_explosion.colour.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Self(
            firework_explosion=FireworkExplosion(colour=Colour(Int(hash)))
        )

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`): every colour."""
        var out = List[Self]()
        for c in colours():
            out.append(Self(firework_explosion=FireworkExplosion(colour=c)))
        return out^
