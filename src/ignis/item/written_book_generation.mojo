"""`WrittenBookGeneration`, ported from Dragonfly
`server/item/written_book_generation.go`."""

from ..internal.enum import enum_name


struct WrittenBookGeneration(Equatable, ImplicitlyCopyable, Writable):
    """How many times a written book was copied (Go `WrittenBookGeneration`)."""

    var _v: UInt8

    comptime ORIGINAL = WrittenBookGeneration(0)
    """Go `OriginalGeneration()`."""
    comptime COPY = WrittenBookGeneration(1)
    """Go `CopyGeneration()`."""
    comptime COPY_OF_COPY = WrittenBookGeneration(2)
    """Go `CopyOfCopyGeneration()`."""

    def __init__(out self, v: Int):
        """Creates the generation with value `v` (0 to 2)."""
        self._v = UInt8(v)

    def __init__(out self):
        """Creates the original generation (Go's zero value)."""
        self._v = 0

    def __eq__(self, other: Self) -> Bool:
        """Compares two generations."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the generation as a byte (Go `Uint8`)."""
        return self._v

    def write_to(self, mut writer: Some[Writer]):
        """Writes the generation's name (Go `String`)."""
        writer.write(
            enum_name("original,copy of original,copy of copy", Int(self._v))
        )
