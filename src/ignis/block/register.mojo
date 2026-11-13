"""Registration of the vanilla blocks, ported from Dragonfly
`server/block/register.go`.

Go registers each block value with `world.RegisterBlock` from `init`. Here
each type lists its values in `all_states`, and `VanillaBlocks` lists the
types; `vanilla_block_registry` builds the registry a server uses.
"""

from ..world.block_registry import BasicBlockRegistry
from ..world.block_set import BlockSet
from .air import Air
from .bedrock import Bedrock
from .dirt import Dirt
from .grass import Grass
from .stone import Stone

comptime VanillaBlocks = BlockSet[Air, Bedrock, Dirt, Grass, Stone]
"""Every block type Ignis implements, in Go's `register.go` order."""

comptime BLOCK_STATES_PATH = "resources/block_states.nbt"
"""Where `block_states.nbt` lives, relative to the repository root."""


def vanilla_block_registry(
    path: String = BLOCK_STATES_PATH,
) raises -> BasicBlockRegistry:
    """Builds the finalized vanilla registry (Go `DefaultBlockRegistry`
    after `Finalize`).

    Args:
        path: The path of `block_states.nbt`.

    Returns:
        The registry.

    Raises:
        If the file cannot be read or a block does not match a state.
    """
    var br = BasicBlockRegistry.load(path)
    VanillaBlocks.register_all(br)
    br.finalize()
    return br^
