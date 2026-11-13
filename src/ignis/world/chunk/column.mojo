"""A chunk with its entities, block entities and scheduled updates, as a
provider stores it; ported from Dragonfly `server/world/chunk/col.go`."""

from minecraft.nbt.tree import Tree

from ...block.cube.pos import Pos
from .chunk import Chunk


@fieldwise_init
struct Entity(Copyable):
    """An entity as stored with a column (Go `chunk.Entity`)."""

    var id: Int64
    """The entity's ID: the last 8 bytes of its UUID, little endian."""
    var data: Tree
    """The entity's NBT, including its `identifier`."""


@fieldwise_init
struct BlockEntity(Copyable):
    """A block entity as stored with a column (Go `chunk.BlockEntity`)."""

    var pos: Pos
    """The position of the block."""
    var data: Tree
    """The block entity's NBT."""


@fieldwise_init
struct ScheduledBlockUpdate(Copyable, Equatable, Writable):
    """A scheduled block update stored with a column (Go
    `chunk.ScheduledBlockUpdate`)."""

    var pos: Pos
    """The position of the block."""
    var block: UInt32
    """The runtime ID of the block the update is for."""
    var tick: Int64
    """The world tick at which the update is due."""


@fieldwise_init
struct Column(Copyable):
    """A chunk and the data stored with it (Go `chunk.Column`)."""

    var chunk: Chunk
    """The blocks and biomes."""
    var entities: List[Entity]
    """The entities in the chunk."""
    var block_entities: List[BlockEntity]
    """The block entities in the chunk."""
    var tick: Int64
    """The world tick when the column was stored; scheduled updates are
    relative to it."""
    var scheduled_blocks: List[ScheduledBlockUpdate]
    """The block updates scheduled in the chunk."""

    def __init__(out self, var chunk: Chunk):
        """Creates a column holding only a chunk.

        Args:
            chunk: The chunk.
        """
        self.chunk = chunk^
        self.entities = List[Entity]()
        self.block_entities = List[BlockEntity]()
        self.tick = 0
        self.scheduled_blocks = List[ScheduledBlockUpdate]()
