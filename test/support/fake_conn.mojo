"""A `session.Conn` that records what a session writes."""

from ignis.session.conn import Conn
from minecraft.protocol.login.data import ClientData, IdentityData
from minecraft.protocol.packet.packet import Packet, PacketData


struct FakeConn(Conn):
    """Records every written packet; `closed` makes writes fail."""

    var identity: IdentityData
    var client: ClientData
    var radius: Int
    var written: List[PacketData]
    var flushes: Int
    var closed: Bool

    def __init__(out self, name: String, radius: Int = 8):
        self.identity = IdentityData()
        self.identity.display_name = name.copy()
        self.identity.identity = "c0ffee00-0000-4000-8000-000000000001"
        self.client = ClientData()
        self.radius = radius
        self.written = List[PacketData]()
        self.flushes = 0
        self.closed = False

    def identity_data(self) -> IdentityData:
        return self.identity.copy()

    def client_data(self) -> ClientData:
        return self.client.copy()

    def client_cache_enabled(self) -> Bool:
        return False

    def chunk_radius(self) -> Int:
        return self.radius

    def latency_ms(self) -> Int:
        return 0

    def write(mut self, var packet: List[UInt8]) raises:
        if self.closed:
            raise Error("write packet: closed")
        self.written.append(PacketData.parse(Span(packet)))

    def flush(mut self) raises:
        if self.closed:
            raise Error("flush: closed")
        self.flushes += 1

    def ids(self) -> List[UInt32]:
        var out = List[UInt32]()
        for p in self.written:
            out.append(p.id())
        return out^

    def count(self, id: UInt32) -> Int:
        var n = 0
        for p in self.written:
            if p.id() == id:
                n += 1
        return n

    def all[P: Packet](self) raises -> List[P]:
        var out = List[P]()
        for p in self.written:
            if p.id() == P.ID:
                out.append(p.decode[P]())
        return out^

    def last[P: Packet](self) raises -> P:
        var i = len(self.written) - 1
        while i >= 0:
            if self.written[i].id() == P.ID:
                return self.written[i].decode[P]()
            i -= 1
        raise Error(t"no packet {P.ID} written")

    def clear(mut self):
        self.written.clear()
