"""The registry interface the chunk package needs, ported from Dragonfly
`server/world/chunk/block_registry.go`.

Go chunks hold the registry; Ignis chunks do not, and the few methods that
need it (`Chunk.height_map`, `Chunk.highest_light_blocker`) take it as an
argument, so a chunk stays a plain value.
"""

from ..block_state import BlockState, Properties


trait BlockRegistry:
    """Converts between runtime IDs and block states for the chunk package."""

    def block_count(self) -> Int:
        """Returns the number of runtime IDs known by the registry."""
        ...

    def air_runtime_id(self) -> UInt32:
        """Returns the runtime ID representing air."""
        ...

    def runtime_id_to_state(self, runtime_id: UInt32) -> Optional[BlockState]:
        """Resolves a runtime ID to its name and properties."""
        ...

    def state_to_runtime_id(
        self, name: StringSlice, properties: Properties
    ) -> Optional[UInt32]:
        """Resolves a name and properties to a runtime ID, falling back to the
        block's default state if the properties do not match one."""
        ...

    def default_properties(self, name: StringSlice) -> Optional[Properties]:
        """Returns the properties of the default state of a block."""
        ...

    def filtering_block(self, rid: UInt32) -> UInt8:
        """Returns how much light the block filters, 0 to 15."""
        ...

    def light_block(self, rid: UInt32) -> UInt8:
        """Returns the light level the block emits, 0 to 15."""
        ...

    def random_tick_block(self, rid: UInt32) -> Bool:
        """Reports whether the block receives random ticks."""
        ...

    def nbt_block(self, rid: UInt32) -> Bool:
        """Reports whether the block carries NBT data."""
        ...

    def liquid_displacing_block(self, rid: UInt32) -> Bool:
        """Reports whether the block displaces liquids."""
        ...

    def liquid_block(self, rid: UInt32) -> Bool:
        """Reports whether the block is a liquid."""
        ...

    def hash_to_runtime_id(self, hash: UInt32) -> Optional[UInt32]:
        """Resolves a network block hash to a runtime ID."""
        ...

    def runtime_id_to_hash(self, runtime_id: UInt32) -> Optional[UInt32]:
        """Resolves a runtime ID to its network block hash."""
        ...
