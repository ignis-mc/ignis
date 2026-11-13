"""Read access to the blocks of a world, ported from Dragonfly
`server/world/block_source.go`.

Go's `BlockSource.Block(pos)` returns a `world.Block`; here a block of
unknown type is its runtime ID, and the source also maps runtime IDs to
the registry's `kind` and state hash, so that block models can find the
types of their neighbours without holding the registry themselves.
`StateDeriver` needs `world.Tx`: TODO(world-runtime).
"""

from ..block.cube.pos import Pos


trait BlockSource:
    """Something blocks can be read from, such as a world or a transaction
    (Go `world.BlockSource`)."""

    def block(self, pos: Pos) -> UInt32:
        """Returns the block at a position (Go `Block`).

        Args:
            pos: The position.

        Returns:
            The runtime ID of the block; air outside the world.
        """
        ...

    def kind(self, rid: UInt32) -> UInt64:
        """Returns the `BASE_HASH` of the type of a block, as
        `BasicBlockRegistry.kind` does.

        Args:
            rid: A runtime ID returned by `block`.

        Returns:
            The base hash, or `UNKNOWN_KIND` for states without a type.
        """
        ...

    def state_hash(self, rid: UInt32) -> UInt64:
        """Returns the state hash of a block, as
        `BasicBlockRegistry.state_hash` does.

        Args:
            rid: A runtime ID returned by `block`.

        Returns:
            The value `hash()` returned for the block.
        """
        ...
