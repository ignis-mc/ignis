"""Registration of the vanilla blocks, ported from Dragonfly
`server/block/register.go`.

Go registers each block value with `world.RegisterBlock` from `init`. Here
each type lists its values in `all_states`, and `VanillaBlocks` lists the
types; `vanilla_block_registry` builds the registry a server uses.
"""

from ..world.block_registry import BasicBlockRegistry
from ..world.block_set import BlockSet
from .air import Air
from .basalt import Basalt
from .bedrock import Bedrock
from .blackstone import Blackstone
from .break_info import BreakInfo, Breakable
from .bricks import Bricks
from .calcite import Calcite
from .cobblestone import Cobblestone
from .deepslate import Deepslate
from .deepslate_bricks import DeepslateBricks
from .deepslate_tiles import DeepslateTiles
from .dirt import Dirt
from .end_bricks import EndBricks
from .end_stone import EndStone
from .grass import Grass
from .nether_bricks import NetherBricks
from .netherrack import Netherrack
from .polished_blackstone_brick import PolishedBlackstoneBrick
from .polished_tuff import PolishedTuff
from .smooth_basalt import SmoothBasalt
from .stone import Andesite, Diorite, Granite, Stone
from .stone_bricks import StoneBricks
from .tuff import Tuff
from .tuff_bricks import TuffBricks

comptime VanillaBlocks = BlockSet[
    Air,
    Andesite,
    Basalt,
    Bedrock,
    Blackstone,
    Bricks,
    Calcite,
    Cobblestone,
    Deepslate,
    DeepslateBricks,
    DeepslateTiles,
    Diorite,
    Dirt,
    EndBricks,
    EndStone,
    Granite,
    Grass,
    NetherBricks,
    Netherrack,
    PolishedBlackstoneBrick,
    PolishedTuff,
    SmoothBasalt,
    Stone,
    StoneBricks,
    Tuff,
    TuffBricks,
]
"""Every block type Ignis implements, sorted by name."""

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


def break_info(kind: UInt64, hash: UInt64) -> Optional[BreakInfo]:
    """Returns the break info of a block of any vanilla type (Go
    `b.(Breakable).BreakInfo()`).

    Args:
        kind: The `BASE_HASH` of the block's type.
        hash: The block's state hash.

    Returns:
        The break info, or None if the type is unknown or not `Breakable`.
    """
    comptime for i in range(len(VanillaBlocks.Ts)):
        comptime T = VanillaBlocks.Ts[i]
        comptime if conforms_to(T, Breakable):
            if kind == T.BASE_HASH:
                return _break_info[T](T.from_hash(hash))
    return None


def _break_info[T: Breakable](b: T) -> BreakInfo:
    return b.break_info()
