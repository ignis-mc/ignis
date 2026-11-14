"""`BrewingStand`, ported from Dragonfly `server/block/brewing_stand.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the `*brewer` (brewer.go: inventory, fuel, brewing
progress), NewBrewingStand, Tick, Model, SideClosed, Activate, UseOnBlock,
EncodeNBT, DecodeNBT, the break handler, EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    PICKAXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_BREWING_STAND
from .model.brewing_stand import BrewingStand as BrewingStandModel


struct BrewingStand(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    ModelledBlock,
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
        """Creates the block; omitted fields take Go zero values.

        Args:
            left_slot: Whether the left slot holds a potion.
            middle_slot: Whether the middle slot holds a potion.
            right_slot: Whether the right slot holds a potion.
        """
        self.left_slot = left_slot
        self.middle_slot = middle_slot
        self.right_slot = right_slot

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state.
        """
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        return BlockState(
            "minecraft:brewing_stand",
            Properties()
            .with_bool("brewing_stand_slot_a_bit", self.left_slot)
            .with_bool("brewing_stand_slot_b_bit", self.middle_slot)
            .with_bool("brewing_stand_slot_c_bit", self.right_slot),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            (UInt64(1) if self.left_slot else UInt64(0))
            | (UInt64(1) if self.middle_slot else UInt64(0)) << 1
            | (UInt64(1) if self.right_slot else UInt64(0)) << 2
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return BrewingStand(
            left_slot=hash & 0x1 != 0,
            middle_slot=(hash >> 1) & 0x1 != 0,
            right_slot=(hash >> 2) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
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
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.5, ALWAYS_HARVESTABLE, PICKAXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0

    def model(self) -> BrewingStandModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return BrewingStandModel()
