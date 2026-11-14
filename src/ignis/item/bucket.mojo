"""`Bucket` and `BucketContent`, ported from Dragonfly
`server/item/bucket.go`.

Go's `BucketContent` holds a `world.Liquid` value; here the liquid is an
`AnyBlock` (water or lava, any state). `Liquid()` returns it; its
`LiquidType` is read from the block type.

TODO(player): `UseOnBlock`, `fillFrom` (filling and emptying need the world
and liquids), `CanConsume`, and applying `consume_info` (Go `Consume`).
"""

from ..block.hash import (
    HASH_LAVA,
    HASH_WATER,
    AnyBlock,
    hash_block,
    unhash_block,
)
from ..block.lava import Lava
from ..block.water import Water
from ..world.block import Block
from ..world.item import EncodedItem, Item, item_hash
from .item import DEFAULT_CONSUME_DURATION, Consumable, ConsumeInfo, MaxCounter
from .smelting_info import Fuel, FuelInfo
from .stack import Stack


@fieldwise_init
struct BucketContent(Equatable, ImplicitlyCopyable, Writable):
    """The content of a bucket (Go `BucketContent`)."""

    var liquid: Optional[AnyBlock]
    """The liquid in the bucket, if any."""
    var milk: Bool
    """Whether the bucket holds milk."""

    def __init__(out self):
        """Creates the content of an empty bucket (Go `BucketContent{}`)."""
        self.liquid = None
        self.milk = False

    def __eq__(self, other: Self) -> Bool:
        """Compares two contents."""
        if self.milk != other.milk or Bool(self.liquid) != Bool(other.liquid):
            return False
        if self.liquid:
            return self.liquid.value() == other.liquid.value()
        return True

    def liquid_type(self) -> String:
        """Returns the liquid's type, `milk` without liquid (Go `LiquidType`).
        """
        if case .Some(l) = self.liquid:
            return _liquid_type(l)
        return "milk"

    def write_to(self, mut writer: Some[Writer]):
        """Writes `milk`, the liquid's type, or nothing (Go `String`)."""
        if self.milk:
            writer.write("milk")
        elif case .Some(l) = self.liquid:
            writer.write(_liquid_type(l))


def liquid_bucket_content[T: Block](l: T) -> BucketContent:
    """Returns the content of a bucket of a liquid (Go `LiquidBucketContent`).
    """
    return BucketContent(AnyBlock(l), False)


def milk_bucket_content() -> BucketContent:
    """Returns the content of a milk bucket (Go `MilkBucketContent`)."""
    return BucketContent(None, True)


def _liquid_type(l: AnyBlock) -> String:
    if l.kind == HASH_LAVA:
        return "lava"
    if l.kind == HASH_WATER:
        return "water"
    return ""


struct Bucket(
    Consumable, Equatable, Fuel, ImplicitlyCopyable, Item, MaxCounter
):
    """A tool used to carry water, lava and fish."""

    comptime BASE_HASH: UInt64 = item_hash("Bucket")
    """`item_hash("Bucket")`."""

    var content: BucketContent
    """The content of the bucket."""

    def __init__(out self, *, content: BucketContent = BucketContent()):
        """Creates the item; omitted fields take Go zero values."""
        self.content = content

    def __eq__(self, other: Self) -> Bool:
        """Compares two buckets by content."""
        return self.content == other.content

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`): 16 empty, 1 full."""
        if self.empty():
            return 16
        return 1

    def always_consumable(self) -> Bool:
        """Reports whether milk may be drunk any time (Go `AlwaysConsumable`).
        """
        return self.content.milk

    def consume_duration(self) -> Int:
        """Returns how long drinking takes (Go `ConsumeDuration`)."""
        return DEFAULT_CONSUME_DURATION

    def consume_info(self) -> ConsumeInfo:
        """Returns what drinking does (Go `Consume`): every effect is removed
        and an empty bucket is left."""
        var info = ConsumeInfo(0, 0, residue=Stack(Bucket(), 1))
        info.removes_all_effects = True
        return info^

    def empty(self) -> Bool:
        """Reports whether the bucket is empty (Go `Empty`)."""
        return not self.content.liquid and not self.content.milk

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): lava burns 1000 s and leaves
        an empty bucket."""
        if case .Some(l) = self.content.liquid:
            if _liquid_type(l) == "lava":
                return FuelInfo(1_000_000).with_residue(Stack(Bucket(), 1))
        return FuelInfo()

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        if not self.empty():
            return EncodedItem(String(t"minecraft:{self.content}_bucket"), 0)
        return EncodedItem("minecraft:bucket", 0)

    def hash(self) -> UInt64:
        """Returns the item hash: milk, whether there is a liquid, and the
        liquid's packed block from bit 2."""
        var h = UInt64(1) if self.content.milk else UInt64(0)
        if case .Some(l) = self.content.liquid:
            h |= 2 | hash_block(l) << 2
        return h

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        var c = BucketContent()
        c.milk = hash & 1 != 0
        if hash & 2 != 0:
            c.liquid = unhash_block(hash >> 2)
        return Self(content=c)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go` and
        `block/register.go`): empty, lava, water and milk."""
        return [
            Self(),
            Self(content=liquid_bucket_content(Lava(depth=0))),
            Self(content=liquid_bucket_content(Water(depth=0))),
            Self(content=milk_bucket_content()),
        ]
