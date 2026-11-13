"""The journal (log) record format shared by `.log` files and the MANIFEST,
ported from goleveldb `journal/journal.go`.

A journal is a sequence of 32 KiB blocks. Each record is split into chunks
with a 7-byte header: masked CRC-32C of the type byte and data (4 bytes),
data length (2 bytes LE), chunk type (full, first, middle or last). A block
tail too short for a header is zero-filled.
"""

from .util import get_u32, masked_crc

comptime BLOCK_SIZE = 32 * 1024
"""The journal block size (Go `blockSize`)."""
comptime HEADER_SIZE = 7
"""The chunk header size (Go `headerSize`)."""
comptime FULL_CHUNK: UInt8 = 1
"""A chunk holding a whole record."""
comptime FIRST_CHUNK: UInt8 = 2
"""The first chunk of a split record."""
comptime MIDDLE_CHUNK: UInt8 = 3
"""A middle chunk of a split record."""
comptime LAST_CHUNK: UInt8 = 4
"""The last chunk of a split record."""


struct JournalWriter(Movable):
    """Frames records into journal chunks (Go `journal.Writer`).

    The writer only tracks the offset inside the current block; `append`
    returns the framed bytes for the caller to write to the file, so the
    framing is independent of I/O.
    """

    var _offset: Int
    """Bytes already used in the current block."""

    def __init__(out self, offset: Int = 0):
        """Creates a writer that continues a journal of `offset` bytes.

        Args:
            offset: The current length of the journal.
        """
        self._offset = offset % BLOCK_SIZE

    def append(mut self, record: Span[UInt8, _], mut out: List[UInt8]):
        """Frames one record and appends the bytes to `out`.

        Args:
            record: The record.
            out: The destination.
        """
        var pos = 0
        var first = True
        while True:
            var left = BLOCK_SIZE - self._offset
            if left < HEADER_SIZE:
                for _ in range(left):
                    out.append(0)
                self._offset = 0
                left = BLOCK_SIZE
            var avail = left - HEADER_SIZE
            var n = min(avail, len(record) - pos)
            var last = pos + n == len(record)
            var kind: UInt8
            if first and last:
                kind = FULL_CHUNK
            elif first:
                kind = FIRST_CHUNK
            elif last:
                kind = LAST_CHUNK
            else:
                kind = MIDDLE_CHUNK
            var body = List[UInt8](capacity=n + 1)
            body.append(kind)
            body.extend(record[pos : pos + n])
            var crc = masked_crc(Span(body))
            out.append(UInt8(crc & 0xFF))
            out.append(UInt8((crc >> 8) & 0xFF))
            out.append(UInt8((crc >> 16) & 0xFF))
            out.append(UInt8(crc >> 24))
            out.append(UInt8(n & 0xFF))
            out.append(UInt8(n >> 8))
            out.extend(Span(body))
            self._offset += HEADER_SIZE + n
            pos += n
            first = False
            if last:
                break


struct JournalReader(Movable):
    """Reads records from a whole journal (Go `journal.Reader` in
    non-strict mode).

    Corruption is skipped the way goleveldb skips it: a bad checksum, a
    zero header, an invalid chunk type or a chunk that overflows its block
    drops the rest of that block; an orphan middle or last chunk is
    skipped; a record cut off at the end of the file (an unclean stop) is
    dropped. `dropped` counts the bytes lost to corruption.
    """

    var _data: List[UInt8]
    var _pos: Int
    var dropped: Int
    """Bytes skipped because of corruption so far."""

    def __init__(out self, var data: List[UInt8]):
        """Creates a reader over journal bytes.

        Args:
            data: The whole journal file.
        """
        self._data = data^
        self._pos = 0
        self.dropped = 0

    def _drop_block(mut self, block_end: Int):
        self.dropped += block_end - self._pos
        self._pos = block_end

    def next(mut self) -> Optional[List[UInt8]]:
        """Returns the next intact record.

        Returns:
            The record, or None at the end of the journal.
        """
        var record = List[UInt8]()
        var in_record = False
        var n = len(self._data)
        while self._pos < n:
            var block_end = min((self._pos // BLOCK_SIZE + 1) * BLOCK_SIZE, n)
            if block_end - self._pos < HEADER_SIZE:
                # Block trailer (zero filled) or a header cut off at EOF.
                if block_end == n and n % BLOCK_SIZE != 0 and in_record:
                    self.dropped += len(record)
                self._pos = block_end
                continue
            var d = Span(self._data)
            var p = self._pos
            var crc = get_u32(d, p)
            var length = Int(d[p + 4]) | (Int(d[p + 5]) << 8)
            var kind = d[p + 6]
            if crc == 0 and length == 0 and kind == 0:
                self._drop_block(block_end)
                continue
            if kind < FULL_CHUNK or kind > LAST_CHUNK:
                self._drop_block(block_end)
                continue
            var start = p + HEADER_SIZE
            var end = start + length
            if end > block_end:
                self._drop_block(block_end)
                continue
            if masked_crc(d[p + 6 : end]) != crc:
                self._drop_block(block_end)
                continue
            self._pos = end
            if kind == FULL_CHUNK:
                if in_record:
                    self.dropped += len(record)
                return List[UInt8](d[start:end])
            if kind == FIRST_CHUNK:
                if in_record:
                    self.dropped += len(record)
                record = List[UInt8](d[start:end])
                in_record = True
                continue
            if not in_record:
                # Orphan middle or last chunk.
                self.dropped += HEADER_SIZE + length
                continue
            record.extend(d[start:end])
            if kind == LAST_CHUNK:
                return record^
        if in_record:
            self.dropped += len(record)
        return None
