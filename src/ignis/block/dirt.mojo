"""Dirt, ported from Dragonfly `server/block/dirt.go`.

TODO(world-runtime): SoilFor, Till, Shovel, spreadDirt, EncodeItem and the
drops.
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from .break_info import (
    ALWAYS_HARVESTABLE,
    SHOVEL_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_DIRT
from .model.solid import Solid as SolidModel


@fieldwise_init
struct Dirt(Block, Breakable, Equatable, ImplicitlyCopyable, ModelledBlock):
    """A block found abundantly in most biomes under a layer of grass."""

    comptime BASE_HASH: UInt64 = HASH_DIRT
    """Go `hashDirt`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var coarse: Bool
    """Whether the dirt is coarse dirt; grass does not spread onto it."""

    def __init__(out self):
        """Creates plain dirt (Go `Dirt{}`)."""
        self.coarse = False

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            `minecraft:coarse_dirt` or `minecraft:dirt`, no properties.
        """
        if self.coarse:
            return BlockState("minecraft:coarse_dirt")
        return BlockState("minecraft:dirt")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            1 for coarse dirt, 0 otherwise.
        """
        return UInt64(1) if self.coarse else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The dirt.
        """
        return Dirt(coarse=hash & 1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Coarse dirt and dirt.
        """
        return [Dirt(coarse=True), Dirt()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.5, ALWAYS_HARVESTABLE, SHOVEL_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SolidModel()
