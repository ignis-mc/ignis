"""`Slab`, ported from Dragonfly `server/block/slab.go`.

TODO(world-runtime): UseOnBlock, Instrument, FlammabilityInfo, FuelInfo,
CanDisplace, SideClosed, CanRedstoneWireStepDown, Model, EncodeItem and the
drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .blackstone import Blackstone
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .end_bricks import EndBricks
from .hash import HASH_SLAB, AnyBlock, hash_block, unhash_block
from .model.slab import Slab as SlabModel
from .polished_blackstone_brick import PolishedBlackstoneBrick
from .purpur import Purpur
from .quartz import Quartz
from .register import break_info
from .sandstone import Sandstone
from .slab_type import encode_slab_block, slab_blocks
from .stone import Stone
from .stone_bricks import StoneBricks
from .stone_bricks_type import StoneBricksType


struct Slab(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    ModelledBlock,
):
    """A half block that allows entities to walk up blocks without jumping."""

    comptime BASE_HASH: UInt64 = HASH_SLAB
    """Go `hashSlab`."""
    comptime ModelType = SlabModel
    """The model type (Go `Model`)."""

    var block: AnyBlock
    """The block the slab is made of."""
    var top: Bool
    """Whether the slab is in the top half of the block."""
    var double: Bool
    """Whether the slab is a double slab."""

    def __init__(
        out self, *, block: AnyBlock, top: Bool = False, double: Bool = False
    ):
        """Creates the block; `block` is required, the other fields default to Go zero values.

        Args:
            block: The block the slab is made of.
            top: Whether the slab is in the top half of the block.
            double: Whether the slab is a double slab.
        """
        self.block = block
        self.top = top
        self.double = double

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
        var side = "top" if self.top else "bottom"
        var n = encode_slab_block(self.block, self.double)
        return BlockState(
            String(t"minecraft:{n[0]}{n[1]}"),
            Properties().with_string("minecraft:vertical_half", side),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            hash_block(self.block)
            | (UInt64(1) if self.top else UInt64(0)) << 32
            | (UInt64(1) if self.double else UInt64(0)) << 33
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Slab(
            block=unhash_block(hash & 0xFFFFFFFF),
            top=(hash >> 32) & 0x1 != 0,
            double=(hash >> 33) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for s in slab_blocks():
            out.append(Slab(block=s, double=True))
            out.append(Slab(block=s, top=True, double=True))
            out.append(Slab(block=s, top=True))
            out.append(Slab(block=s))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        var hardness = 2.0
        var blast_resistance = 6.0
        var harvestable = PICKAXE_HARVESTABLE
        var effective = PICKAXE_EFFECTIVE
        var b = self.block
        if (
            b.is_a[Stone]()
            or b.is_a[Sandstone]()
            or b.is_a[Quartz]()
            or b.is_a[Purpur]()
            or b.is_a[Blackstone]()
            or b.is_a[PolishedBlackstoneBrick]()
        ):
            pass
        elif b.is_a[EndBricks]():
            hardness = 3
        elif case .Some(s) = b.get[StoneBricks]():
            if s.type == StoneBricksType.MOSSY:
                hardness = 1.5
        elif case .Some(info) = break_info(b.kind, b.state):
            hardness = info.hardness
            blast_resistance = info.blast_resistance
            harvestable = info.harvestable
            effective = info.effective
        return new_break_info(
            hardness, harvestable, effective
        ).with_blast_resistance(blast_resistance)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 15 if self.double else 0

    def model(self) -> SlabModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SlabModel(double=self.double, top=self.top)
