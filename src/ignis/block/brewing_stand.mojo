"""`BrewingStand`, ported from Dragonfly `server/block/brewing_stand.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the `*brewer` (brewer.go: inventory, fuel, brewing
progress), NewBrewingStand, Tick, Model, Activate, UseOnBlock, the break
handler and the drops.
"""

from minecraft.nbt.tree import Tag, Tree

from ..world.block import Block, LightDiffuser, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    PICKAXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_BREWING_STAND
from .model.brewing_stand import BrewingStand as BrewingStandModel
from ..world.block import LiquidDisplacer
from .hash import AnyBlock
from .liquid import source_water_can_displace


struct BrewingStand(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidDisplacer,
    ModelledBlock,
    NBTer,
):
    """A block used for brewing potions, splash potions, and lingering potions.
    """

    comptime BASE_HASH: UInt64 = HASH_BREWING_STAND
    """Go `hashBrewingStand`."""
    comptime ModelType = BrewingStandModel
    """The model type (Go `Model`)."""

    var left_slot: Bool
    """Whether the left slot holds a potion."""
    var middle_slot: Bool
    """Whether the middle slot holds a potion."""
    var right_slot: Bool
    """Whether the right slot holds a potion."""

    def __init__(
        out self,
        *,
        left_slot: Bool = False,
        middle_slot: Bool = False,
        right_slot: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.left_slot = left_slot
        self.middle_slot = middle_slot
        self.right_slot = right_slot

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:brewing_stand",
            Properties()
            .with_bool("brewing_stand_slot_a_bit", self.left_slot)
            .with_bool("brewing_stand_slot_b_bit", self.middle_slot)
            .with_bool("brewing_stand_slot_c_bit", self.right_slot),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            (UInt64(1) if self.left_slot else UInt64(0))
            | (UInt64(1) if self.middle_slot else UInt64(0)) << 1
            | (UInt64(1) if self.right_slot else UInt64(0)) << 2
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return BrewingStand(
            left_slot=hash & 0x1 != 0,
            middle_slot=(hash >> 1) & 0x1 != 0,
            right_slot=(hash >> 2) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for left_slot in [False, True]:
            for middle_slot in [False, True]:
                for right_slot in [False, True]:
                    out.append(
                        BrewingStand(
                            left_slot=left_slot,
                            middle_slot=middle_slot,
                            right_slot=right_slot,
                        )
                    )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.5, ALWAYS_HARVESTABLE, PICKAXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> BrewingStandModel:
        """Returns the model of the block (Go `Model`)."""
        return BrewingStandModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:brewing_stand", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`)."""
        # TODO(world-runtime): the brewer's state and inventory; these are a
        # new brewing stand's.
        _ = tag.put_string(root, "id", "BrewingStand")
        _ = tag.put_list(root, "Items")
        _ = tag.put_short(root, "CookTime", 0)
        _ = tag.put_short(root, "FuelTotal", 0)
        _ = tag.put_short(root, "FuelAmount", 0)

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        # TODO(world-runtime): the brewer's state. Go returns a new brewing
        # stand, without the slot state.
        return Self()

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)
