"""`Barrel`, ported from Dragonfly `server/block/barrel.go`.

TODO(world-runtime): the inventory and viewer fields, NewBarrel, Inventory,
WithName, open/close, AddViewer, RemoveViewer, Activate, UseOnBlock,
DecodeNBT, EncodeNBT, the break handler, FlammabilityInfo, FuelInfo,
EncodeItem and the drops.
"""

from ..world.block import Block
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.face import Face
from .hash import HASH_BARREL


struct Barrel(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A fisherman's job site block, used to store items."""

    comptime BASE_HASH: UInt64 = HASH_BARREL
    """Go `hashBarrel`."""

    var facing: Face
    """The direction the barrel faces."""
    var open: Bool
    """Whether the barrel is open."""
    var custom_name: String
    """The custom name of the block, shown in its window."""

    def __init__(
        out self,
        *,
        facing: Face = Face.DOWN,
        open: Bool = False,
        custom_name: String = String(),
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            facing: The direction the barrel faces.
            open: Whether the barrel is open.
            custom_name: The custom name of the block, shown in its window.
        """
        self.facing = facing
        self.open = open
        self.custom_name = custom_name

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state and hold the same data.
        """
        return (
            self.hash() == other.hash()
            and self.custom_name == other.custom_name
        )

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        return BlockState(
            "minecraft:barrel",
            Properties()
            .with_byte("open_bit", UInt8(self.open))
            .with_int("facing_direction", Int32(Int(self.facing))),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(Int(self.facing))
            | (UInt64(1) if self.open else UInt64(0)) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Barrel(facing=Face(Int(hash & 0x7)), open=(hash >> 3) & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for i in range(6):
            out.append(Barrel(facing=Face(i)))
            out.append(Barrel(facing=Face(i), open=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(2.5, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)
