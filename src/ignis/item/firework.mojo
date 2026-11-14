"""Firework, ported from Dragonfly `server/item/firework.go`.

TODO(player): `Use`, `UseOnBlock`.
TODO(world-runtime): `RandomisedDuration`, which needs a random source.
"""

from minecraft.nbt.nbt import TAG_COMPOUND, TAG_LIST
from minecraft.nbt.tree import Tag, Tree

from ..world.block import NBTer
from ..world.item import EncodedItem, Item, item_hash
from .firework_explosion import FireworkExplosion
from .item import OffHand


struct Firework(Equatable, Item, NBTer, OffHand):
    """An item (and entity) used for creating decorative explosions, boosting
    when flying with elytra, and loading into a crossbow as ammunition."""

    comptime BASE_HASH: UInt64 = item_hash("Firework")
    """`item_hash("Firework")`."""

    var duration: Int
    """How long the firework flies before exploding, in milliseconds. Not
    hashed."""
    var explosions: List[FireworkExplosion]
    """The explosions of the firework. Not hashed."""

    def __init__(
        out self,
        *,
        duration: Int = 0,
        var explosions: List[FireworkExplosion] = [],
    ):
        """Creates the item; omitted fields take Go zero values."""
        self.duration = duration
        self.explosions = explosions^

    def __eq__(self, other: Self) -> Bool:
        """Compares two fireworks by duration and explosions."""
        return (
            self.duration == other.duration
            and self.explosions == other.explosions
        )

    def off_hand(self) -> Bool:
        """Reports that the item may be held in the off hand (Go `OffHand`)."""
        return True

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the firework's NBT (Go `EncodeNBT`)."""
        var fw = tag.put_compound(root, "Fireworks")
        var l = tag.put_list(fw, "Explosions")
        for e in self.explosions:
            var c = tag.append_compound(l)
            e.encode_nbt(tag, c)
        # Go: uint8((Duration/10 - 50ms).Milliseconds() / 50), truncating.
        var ms = _trunc_div(
            self.duration * 1_000_000 // 10 - 50_000_000, 1_000_000
        )
        _ = tag.put_byte(fw, "Flight", UInt8(_trunc_div(ms, 50) & 0xFF))

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the firework with its NBT decoded (Go `DecodeNBT`)."""
        var f = self.copy()
        if case .Some(fw) = tag.get(root, "Fireworks"):
            if tag.type_of(fw) != TAG_COMPOUND:
                return f^
            if case .Some(l) = tag.get(fw, "Explosions"):
                if tag.type_of(l) == TAG_LIST:
                    f.explosions = List[FireworkExplosion]()
                    for c in tag.children(l):
                        f.explosions.append(
                            FireworkExplosion().decode_nbt(tag, c)
                        )
            if tag.has(fw, "Flight"):
                var ticks = Int(tag.get_byte(fw, "Flight"))
                f.duration = (ticks * 50 + 50) * 10
        return f^

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:firework_rocket", 0)

    def hash(self) -> UInt64:
        """Returns the item hash; duration and explosions are not hashed."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Self()

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Self()]


def _trunc_div(a: Int, b: Int) -> Int:
    """Divides rounding towards zero, as Go does."""
    var q = a // b
    if q < 0 and q * b != a:
        q += 1
    return q
