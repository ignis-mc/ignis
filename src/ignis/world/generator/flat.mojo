"""The flat generator, ported from Dragonfly
`server/world/generator/flat.go`.

Go's `NewFlat` takes a `[]world.Block`; a list of blocks of different types
is a list of runtime IDs here, so `Flat` takes the layers as runtime IDs
(Go `NewFlatWithRegistry` resolves them the same way).

Dragonfly v0.11.6 fills biomes only up to `y = min + max` (y 255 in the
Overworld), leaving the sub-chunks above as ocean (biome 0). Ignis fills
the whole range; the blocks are the same.
"""

from ...block.cube.pos import Pos
from ..biome import Biome
from ..chunk.chunk import Chunk
from ..dimension import Dimension
from . import Generator
from ..position import ChunkPos


struct Flat(Copyable, Generator):
    """Generates flat worlds with no decoration, filled with one biome."""

    var _biome: UInt32
    var _layers: List[UInt32]

    def __init__[B: Biome](out self, biome: B, var layers: List[UInt32]):
        """Creates a flat generator (Go `NewFlatWithRegistry`).

        Parameters:
            B: The biome type.

        Args:
            biome: The biome of every block.
            layers: The runtime IDs of the layers, top first: the last one
                is the bottom of the world.
        """
        self._biome = UInt32(biome.encode_biome())
        self._layers = layers^

    def generate_chunk(self, pos: ChunkPos, mut chunk: Chunk):
        """Places the layers at the bottom of the chunk and sets the biome
        everywhere.

        Args:
            pos: The position of the chunk.
            chunk: The empty chunk to fill.
        """
        var min_y = Int16(chunk.range().min())
        var max_y = Int16(chunk.range().max())
        var n = Int16(len(self._layers))
        for x in range(16):
            for z in range(16):
                var y = min_y
                while y <= max_y:
                    var rel = y - min_y
                    if rel < n:
                        chunk.set_block(
                            UInt8(x),
                            y,
                            UInt8(z),
                            0,
                            self._layers[Int(n - rel - 1)],
                        )
                    chunk.set_biome(UInt8(x), y, UInt8(z), self._biome)
                    y += 1

    def default_spawn(self, dim: Dimension) -> Pos:
        """Returns the position just above the top layer at the origin.

        Args:
            dim: The dimension of the world.

        Returns:
            (0, min + layers + 1, 0).
        """
        return Pos(0, dim.range().min() + len(self._layers) + 1, 0)
