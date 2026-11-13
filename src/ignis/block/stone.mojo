"""Stone, ported from the `Stone` part of Dragonfly `server/block/stone.go`.

Granite, diorite and andesite, and `BreakInfo`/`SmeltInfo`, follow with the
item package.
"""

from ..world.block import Block
from ..world.block_state import BlockState
from .hash import HASH_STONE


@fieldwise_init
struct Stone(Block, Equatable, ImplicitlyCopyable):
    """A block found underground in the world or on mountains."""

    comptime BASE_HASH: UInt64 = HASH_STONE
    """Go `hashStone`."""

    var smooth: Bool
    """Whether the stone is its smooth variant."""

    def __init__(out self):
        """Creates plain stone (Go `Stone{}`)."""
        self.smooth = False

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            `minecraft:smooth_stone` or `minecraft:stone`, no properties.
        """
        if self.smooth:
            return BlockState("minecraft:smooth_stone")
        return BlockState("minecraft:stone")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            1 for smooth stone, 0 otherwise.
        """
        return UInt64(1) if self.smooth else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The stone.
        """
        return Stone(smooth=hash & 1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Smooth stone and stone.
        """
        return [Stone(smooth=True), Stone()]
