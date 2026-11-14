"""NetherQuartz, ported from Dragonfly `server/item/nether_quartz.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .armour_trim import ArmourTrimMaterial


@fieldwise_init
struct NetherQuartz(ArmourTrimMaterial, Equatable, ImplicitlyCopyable, Item):
    """A smooth, white mineral found in the Nether."""

    comptime BASE_HASH: UInt64 = item_hash("NetherQuartz")
    """`item_hash("NetherQuartz")`."""

    def trim_material(self) -> StaticString:
        """Returns the trim material identifier (Go `TrimMaterial`)."""
        return "quartz"

    def material_colour(self) -> StaticString:
        """Returns the trim text colour (Go `MaterialColour`, `text.Quartz`)."""
        return "§h"

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:quartz", 0)

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
