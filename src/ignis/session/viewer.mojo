"""The world viewer of a session: the `world.Viewer` methods of Dragonfly's
`session.Session` (`ViewChunk` in `chunk.go`, `ViewTime` and
`ViewTimeCycle` in `world.go`).

The world owns its loaders' viewers (`docs/architecture.md`), so the session
cannot be its own viewer as in Go. Its `SessionViewer` shares a
`PacketQueue` with it through an `ArcPointer`: what the world shows the
viewer is encoded into the queue, and the session sends the queue in order
with its own packets.
"""

from std.memory import ArcPointer

from minecraft.protocol.game_rule import GameRule, GameRuleValue
from minecraft.protocol.packet.game_rules_changed import GameRulesChanged
from minecraft.protocol.packet.packet import Packet, encode_packet
from minecraft.protocol.packet.set_time import SetTime

from ..world.chunk.chunk import Chunk
from ..world.dimension import Dimension
from ..world.position import ChunkPos
from ..world.viewer import Viewer
from .chunk import network_chunk


struct PacketQueue(Defaultable, Movable):
    """Encoded packets waiting to be written to a session's connection."""

    var packets: List[List[UInt8]]
    """The packets, header included, oldest first."""
    var error: Optional[String]
    """The first encoding error, if any."""

    def __init__(out self):
        """Creates an empty queue."""
        self.packets = List[List[UInt8]]()
        self.error = None

    def push[P: Packet](mut self, mut pk: P):
        """Encodes and queues a packet."""
        try:
            self.packets.append(encode_packet(pk))
        except e:
            if not self.error:
                self.error = String(e)


struct SessionViewer(Viewer):
    """Shows a session what its chunk loader's world does."""

    var queue: ArcPointer[PacketQueue]
    """The queue shared with the session."""

    def __init__(out self, queue: ArcPointer[PacketQueue]):
        """Creates a viewer writing into a session's queue."""
        self.queue = queue

    def view_chunk(mut self, pos: ChunkPos, dim: Dimension, c: Chunk):
        """Sends a chunk's biomes; the client then requests its sub-chunks
        (Go `ViewChunk` and `sendNetworkChunk`)."""
        var pk = network_chunk(pos, Int32(dim.id), c)
        self.queue[].push(pk)

    def view_time(mut self, t: Int):
        """Sends the time of day (Go `ViewTime`)."""
        var pk = SetTime()
        pk.time = Int32(t)
        self.queue[].push(pk)

    def view_time_cycle(mut self, do_day_light_cycle: Bool):
        """Starts or stops the client's day cycle (Go `ViewTimeCycle`)."""
        var pk = GameRulesChanged()
        pk.game_rules.append(
            GameRule(
                "dodaylightcycle",
                False,
                GameRuleValue(do_day_light_cycle),
            )
        )
        self.queue[].push(pk)
