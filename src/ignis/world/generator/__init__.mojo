"""World generators: the `Generator` trait from Dragonfly
`server/world/generator.go`, and the `server/world/generator` package.

Mojo cannot have a module and a package with the same name, so Go's
`world/generator.go` lives in this package's `__init__` and Go's
`world.Generator` is `ignis.world.generator.Generator`.

Go's `lockedGenerator` serialises concurrent `GenerateChunk` calls; Ignis
generates on its one loop thread and has no need for it.
"""

from ...block.cube.pos import Pos
from ..chunk.chunk import Chunk
from ..dimension import Dimension
from ..position import ChunkPos


trait Generator:
    """Generates chunks the world's provider does not have."""

    def generate_chunk(self, pos: ChunkPos, mut chunk: Chunk):
        """Sets the blocks of a newly created chunk.

        Args:
            pos: The position of the chunk.
            chunk: The empty chunk to fill.
        """
        ...

    def default_spawn(self, dim: Dimension) -> Pos:
        """Returns the default spawn position for worlds using the generator.

        Args:
            dim: The dimension of the world.

        Returns:
            The spawn position.
        """
        ...


@fieldwise_init
struct NopGenerator(Generator, ImplicitlyCopyable):
    """Generates empty chunks (a void world); the default generator."""

    def generate_chunk(self, pos: ChunkPos, mut chunk: Chunk):
        """Leaves the chunk empty.

        Args:
            pos: The position of the chunk.
            chunk: The chunk.
        """
        pass

    def default_spawn(self, dim: Dimension) -> Pos:
        """Returns the origin.

        Args:
            dim: The dimension of the world.

        Returns:
            (0, 0, 0).
        """
        return Pos(0, 0, 0)
