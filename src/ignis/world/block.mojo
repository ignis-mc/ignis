"""The `Block` trait, ported from Dragonfly `server/world/block.go`.

Go's `world.Block` is an interface with hundreds of implementations held as
interface values. Mojo 1.2 has traits but no trait objects, so Ignis splits
the two roles:

- Each block type is a struct conforming to `Block`. Code that knows the
  type works with it directly (`Dirt(coarse=True)`).
- A block of unknown type is its runtime ID (`UInt32`). The registry maps a
  runtime ID back to its type's `BASE_HASH` and state hash, from which
  `T.from_hash` rebuilds the value, and `BlockSet` dispatches behaviour to
  the type by `BASE_HASH`.

See `docs/architecture.md` for how block ports follow this.
"""

from .block_state import BlockState


trait Block(Copyable, Deinitable):
    """A block that may be placed or found in a world.

    Conforming types must make `from_hash(b.hash()) == b` hold for every
    value `b` they register.
    """

    comptime BASE_HASH: UInt64
    """The type's base hash (first value of Go's `Hash()`): the `hash*`
    constant generated for the type in `block/hash.go`, unique per type."""

    def encode_block(self) -> BlockState:
        """Encodes the block to its name and properties (Go `EncodeBlock`).

        Returns:
            The block state; its version is unused.
        """
        ...

    def hash(self) -> UInt64:
        """Returns the hash of the block's own state (second value of Go's
        `Hash()`).

        Returns:
            A value unique among the block's states, below `1 << 49`.
        """
        ...

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from the value `hash` returned.

        Args:
            hash: A value previously returned by `hash`.

        Returns:
            The block.
        """
        ...

    @staticmethod
    def all_states() -> List[Self]:
        """Returns every value of the type that is registered (the
        `RegisterBlock` calls for the type in Go's `block/register.go`).

        Returns:
            The values, in Go's registration order.
        """
        ...


trait LightEmitter:
    """A block that emits light (Go `block.LightEmitter`; `world` uses the
    same trait for its private `lightEmitter`)."""

    def light_emission_level(self) -> UInt8:
        """Returns the light level the block emits, 0 to 15.

        Returns:
            The light emission level.
        """
        ...


trait LightDiffuser:
    """A block that lets light through partly or fully (Go
    `block.LightDiffuser`). Blocks that do not conform block all light."""

    def light_diffusion_level(self) -> UInt8:
        """Returns how much light the block takes away, 0 to 15.

        Returns:
            The light diffusion level.
        """
        ...
