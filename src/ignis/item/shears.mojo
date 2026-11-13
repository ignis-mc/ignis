"""Shears, ported from Dragonfly `server/item/shears.go`.

`UseOnBlock` (carving pumpkins) follows with players.
"""

from ..world.item import EncodedItem, Item, item_hash
from .durability import DurabilityInfo, Durable
from .item import MaxCounter
from .tool import TYPE_SHEARS, Tool, ToolType


@fieldwise_init
struct Shears(Durable, Equatable, ImplicitlyCopyable, Item, MaxCounter, Tool):
    """A tool used to shear sheep, mine a few types of blocks, and carve
    pumpkins."""

    comptime BASE_HASH: UInt64 = item_hash("Shears")
    """`item_hash("Shears")`."""

    def tool_type(self) -> ToolType:
        """Returns the tool type (Go `ToolType`).

        Returns:
            `TYPE_SHEARS`.
        """
        return TYPE_SHEARS

    def harvest_level(self) -> Int:
        """Returns the harvest level (Go `HarvestLevel`).

        Returns:
            1.
        """
        return 1

    def base_mining_efficiency(self, block_kind: UInt64) -> Float64:
        """Returns the base mining efficiency (Go `BaseMiningEfficiency`).

        Args:
            block_kind: The block's type.

        Returns:
            1.5 for every block.
        """
        return 1.5

    def durability_info(self) -> DurabilityInfo:
        """Returns the durability info (Go `DurabilityInfo`).

        Returns:
            238 uses, 1 per block broken, none per attack.
        """
        return DurabilityInfo(
            max_durability=238,
            attack_durability=0,
            break_durability=1,
            persistent=False,
        )

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`).

        Returns:
            1.
        """
        return 1

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`).

        Returns:
            `minecraft:shears`, metadata 0.
        """
        return EncodedItem("minecraft:shears", 0)

    def hash(self) -> UInt64:
        """Returns the item hash; the type has one value.

        Returns:
            0.
        """
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash.

        Args:
            hash: The hash.

        Returns:
            The shears.
        """
        return Self()

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            The one value.
        """
        return [Self()]
