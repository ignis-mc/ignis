"""The connection a session reads from and writes to: Go's `session.Conn`
interface from Dragonfly `server/session/session.go`.

`NetConn` adapts the protocol submodule's server `Conn` (gophertunnel's
`*minecraft.Conn`, which implements Go's interface directly). Mojo cannot
add a trait to a type from another package, hence the wrapper. Packets are
written already encoded so that the trait has no generic methods and a test
can record them (`test/support/fake_conn.mojo`).
"""

from minecraft.conn import Conn as MinecraftConn
from minecraft.protocol.login.data import ClientData, IdentityData


trait Conn(Deinitable, Movable):
    """What a `Session` needs from its connection (Go `session.Conn`)."""

    def identity_data(self) -> IdentityData:
        """Returns the identity the client logged in with (Go
        `IdentityData`)."""
        ...

    def client_data(self) -> ClientData:
        """Returns the client data, such as the skin (Go `ClientData`)."""
        ...

    def client_cache_enabled(self) -> Bool:
        """Reports whether the client has the blob cache enabled (Go
        `ClientCacheEnabled`)."""
        ...

    def chunk_radius(self) -> Int:
        """Returns the chunk radius the client requested (Go
        `ChunkRadius`)."""
        ...

    def latency_ms(self) -> Int:
        """Returns the latency of the connection (Go `Latency`)."""
        ...

    def write(mut self, var packet: List[UInt8]) raises:
        """Queues one encoded packet, header included (Go `WritePacket`)."""
        ...

    def flush(mut self) raises:
        """Sends every queued packet (Go `Flush`)."""
        ...


struct NetConn(Conn):
    """A `Conn` over a connection accepted by the protocol `Listener`."""

    var conn: MinecraftConn
    """The wrapped connection; the server polls it directly."""

    def __init__(out self, var conn: MinecraftConn):
        """Wraps a spawned connection."""
        self.conn = conn^

    def identity_data(self) -> IdentityData:
        """Returns the identity the client logged in with."""
        return self.conn.identity_data.copy()

    def client_data(self) -> ClientData:
        """Returns the client data."""
        return self.conn.client_data.copy()

    def client_cache_enabled(self) -> Bool:
        """Reports whether the client has the blob cache enabled."""
        return self.conn.client_cache_enabled()

    def chunk_radius(self) -> Int:
        """Returns the chunk radius the client requested."""
        return self.conn.chunk_radius()

    def latency_ms(self) -> Int:
        """Returns the latency of the connection."""
        return self.conn.latency_ms()

    def write(mut self, var packet: List[UInt8]) raises:
        """Queues one encoded packet."""
        self.conn.write(packet^)

    def flush(mut self) raises:
        """Sends every queued packet."""
        self.conn.flush()

    def into_inner(deinit self) -> MinecraftConn:
        """Unwraps the connection, such as to keep polling it while it
        closes."""
        return self.conn^
