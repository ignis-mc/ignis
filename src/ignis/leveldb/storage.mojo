"""File naming and the CURRENT pointer, ported from goleveldb
`storage/file_storage.go`.

Files are `MANIFEST-NNNNNN`, `NNNNNN.log` (journals), `NNNNNN.ldb` (tables;
`NNNNNN.sst` is read too) and `NNNNNN.tmp`, with numbers zero-padded to at
least six digits. `CURRENT` names the live manifest followed by a newline;
it is replaced by writing `CURRENT.<num>` and renaming it over `CURRENT`,
keeping the old contents in `CURRENT.bak`.
"""

from ..internal.fs import (
    exists,
    join,
    list_dir,
    read_file,
    rename,
    sync_dir,
    write_file,
)

comptime TYPE_MANIFEST = 1
"""A MANIFEST file."""
comptime TYPE_JOURNAL = 2
"""A journal (`.log`) file."""
comptime TYPE_TABLE = 4
"""A table (`.ldb` or `.sst`) file."""
comptime TYPE_TEMP = 8
"""A temporary (`.tmp`) file."""


@fieldwise_init
struct FileDesc(Copyable, Equatable, ImplicitlyCopyable, Movable):
    """A file type and number (Go `storage.FileDesc`)."""

    var type: Int
    """One of the `TYPE_*` constants."""
    var num: Int
    """The file number."""


def _pad6(n: Int) -> String:
    var s = String(n)
    while s.byte_length() < 6:
        s = "0" + s
    return s^


def file_name(fd: FileDesc) -> String:
    """Returns the file name for a descriptor (Go `fsGenName`).

    Args:
        fd: The descriptor.

    Returns:
        The name, such as `000005.ldb`.
    """
    if fd.type == TYPE_MANIFEST:
        return String("MANIFEST-", _pad6(fd.num))
    if fd.type == TYPE_JOURNAL:
        return String(_pad6(fd.num), ".log")
    if fd.type == TYPE_TABLE:
        return String(_pad6(fd.num), ".ldb")
    return String(_pad6(fd.num), ".tmp")


def _parse_num(b: Span[UInt8, _]) -> Optional[Int]:
    if len(b) == 0 or len(b) > 18:
        return None
    var n = 0
    for c in b:
        if c < UInt8(ord("0")) or c > UInt8(ord("9")):
            return None
        n = n * 10 + Int(c - UInt8(ord("0")))
    return n


def parse_file_name(name: StringSlice) -> Optional[FileDesc]:
    """Parses a LevelDB file name (Go `fsParseName`).

    Args:
        name: The file name.

    Returns:
        The descriptor, or None for other files.
    """
    var b = name.as_bytes()
    if name.startswith("MANIFEST-"):
        if case .Some(n) = _parse_num(b[9:]):
            return FileDesc(TYPE_MANIFEST, n)
        return None
    var dot = -1
    for i in range(len(b)):
        if b[i] == UInt8(ord(".")):
            dot = i
            break
    if dot <= 0:
        return None
    var num = _parse_num(b[:dot])
    if not num:
        return None
    var ext = String(from_utf8_lossy=b[dot + 1 :])
    if ext == "log":
        return FileDesc(TYPE_JOURNAL, num.value())
    if ext == "ldb" or ext == "sst":
        return FileDesc(TYPE_TABLE, num.value())
    if ext == "tmp":
        return FileDesc(TYPE_TEMP, num.value())
    return None


def table_path(dir: StringSlice, num: Int) raises -> String:
    """Returns the path of table `num`, preferring `.ldb` and falling back to
    an existing `.sst` (Go `fsHasOldName`).

    Args:
        dir: The database directory.
        num: The file number.

    Returns:
        The path.

    Raises:
        If the path is invalid.
    """
    var p = join(dir, file_name(FileDesc(TYPE_TABLE, num)))
    if exists(p):
        return p^
    var old = join(dir, String(_pad6(num), ".sst"))
    if exists(old):
        return old^
    return p^


def list_files(dir: StringSlice) raises -> List[Tuple[FileDesc, String]]:
    """Lists the LevelDB files in a directory.

    Args:
        dir: The directory.

    Returns:
        Each descriptor with its file name.

    Raises:
        If the directory cannot be read.
    """
    var out = List[Tuple[FileDesc, String]]()
    for name in list_dir(dir):
        if case .Some(fd) = parse_file_name(name):
            out.append((fd, name))
    return out^


def _try_current(dir: StringSlice, name: StringSlice) -> Optional[FileDesc]:
    try:
        var b = read_file(join(dir, name))
        if len(b) < 1 or b[len(b) - 1] != UInt8(ord("\n")):
            return None
        var target = String(from_utf8_lossy=Span(b)[: len(b) - 1])
        var fd = parse_file_name(target)
        if not fd or fd.value().type != TYPE_MANIFEST:
            return None
        if not exists(join(dir, target)):
            return None
        return fd
    except:
        return None


def get_meta(dir: StringSlice) raises -> Optional[FileDesc]:
    """Finds the live manifest (Go `fileStorage.GetMeta`): pending
    `CURRENT.<num>` files in descending order, then `CURRENT`, then
    `CURRENT.bak`, skipping corrupt ones and ones naming a missing file.

    Args:
        dir: The database directory.

    Returns:
        The manifest descriptor, or None if no valid pointer exists.

    Raises:
        If the directory cannot be read.
    """
    var pending = List[Int]()
    for name in list_dir(dir):
        if name.startswith("CURRENT.") and name != "CURRENT.bak":
            if case .Some(n) = _parse_num(name.as_bytes()[8:]):
                pending.append(n)
    # Descending order; the list is short.
    for i in range(len(pending)):
        for j in range(i + 1, len(pending)):
            if pending[j] > pending[i]:
                var t = pending[i]
                pending[i] = pending[j]
                pending[j] = t
    for n in pending:
        if case .Some(fd) = _try_current(dir, String("CURRENT.", n)):
            return fd
    if case .Some(fd) = _try_current(dir, "CURRENT"):
        return fd
    return _try_current(dir, "CURRENT.bak")


def set_meta(dir: StringSlice, fd: FileDesc) raises:
    """Points `CURRENT` at a manifest durably (Go `fileStorage.setMeta`).

    Args:
        dir: The database directory.
        fd: The manifest.

    Raises:
        If a file cannot be written or renamed.
    """
    var content = file_name(fd) + "\n"
    var current = join(dir, "CURRENT")
    if exists(current):
        var old = read_file(current)
        if String(from_utf8_lossy=Span(old)) == content:
            return
        write_file(current + ".bak", Span(old), sync=True)
    var tmp = String(current, ".", fd.num)
    write_file(tmp, content.as_bytes(), sync=True)
    rename(tmp, current)
    sync_dir(dir)
