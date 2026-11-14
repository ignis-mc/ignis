"""NetherStar, ported from Dragonfly `server/item/nether_star.go`."""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct NetherStar(Equatable, ImplicitlyCopyable, Item):
    """A rare item dropped by the wither that is used solely to craft beacons.
    """

    comptime BASE_HASH: UInt64 = item_hash("NetherStar")
    """`item_hash("NetherStar")`."""

    def blast_proof(self) -> Bool:
        """Reports that the item survives explosions as an item entity (Go
        `BlastProof`)."""
        return True

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:nether_star", 0)

    def hash(self) -> UInt64:
        """Returns the item hash; the type has one value."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Self()

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Self()]
