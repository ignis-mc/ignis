"""Files and directories through raw Linux system calls.

The Mojo standard library has no rename, fsync, flock or directory sync,
which a crash-safe LevelDB needs, so this module issues the system calls
itself through nethernet's `syscall6` (the same primitive protocol's
`minecraft.auth.secret_file` uses). There is no libc and no FFI.

Every function that takes a path converts it to a NUL-terminated copy and
keeps that copy alive across the call. Buffers are borrowed (`Span`) so the
owner outlives the call.
"""

from nethernet.os._sys.linux import syscall6
from std.sys.info import CompilationTarget

comptime _X86 = CompilationTarget.is_x86()

comptime _SYS_READ = 0 if _X86 else 63
comptime _SYS_WRITE = 1 if _X86 else 64
comptime _SYS_CLOSE = 3 if _X86 else 57
comptime _SYS_LSEEK = 8 if _X86 else 62
comptime _SYS_PREAD64 = 17 if _X86 else 67
comptime _SYS_FLOCK = 73 if _X86 else 32
comptime _SYS_FSYNC = 74 if _X86 else 82
comptime _SYS_FTRUNCATE = 77 if _X86 else 46
comptime _SYS_GETDENTS64 = 217 if _X86 else 61
comptime _SYS_OPENAT = 257 if _X86 else 56
comptime _SYS_MKDIRAT = 258 if _X86 else 34
comptime _SYS_UNLINKAT = 263 if _X86 else 35
comptime _SYS_RENAMEAT2 = 316 if _X86 else 276
comptime _SYS_FACCESSAT = 269 if _X86 else 48

comptime _AT_FDCWD = -100
comptime _AT_REMOVEDIR = 0x200
comptime _O_RDONLY = 0
comptime _O_WRONLY = 1
comptime _O_RDWR = 2
comptime _O_CREAT = 0o100
comptime _O_TRUNC = 0o1000
comptime _O_APPEND = 0o2000
comptime _O_CLOEXEC = 0o2000000
comptime _O_DIRECTORY = 0o200000 if _X86 else 0o40000
comptime _LOCK_EX = 2
comptime _LOCK_NB = 4
comptime _LOCK_UN = 8
comptime _SEEK_END = 2

comptime ENOENT = 2
"""The errno of a missing file or directory."""
comptime EEXIST = 17
"""The errno of an existing file or directory."""
comptime _EINTR = 4


@fieldwise_init
struct FsError(Movable, Writable):
    """A failed file-system operation: what was attempted and the errno."""

    var op: String
    """The operation and path, such as `open db/CURRENT`."""
    var errno: Int
    """The positive Linux errno value."""

    def write_to(self, mut writer: Some[Writer]):
        """Writes `op: errno N`.

        Args:
            writer: The destination.
        """
        writer.write(self.op, ": errno ", self.errno)

    def not_found(self) -> Bool:
        """Reports whether the error is `ENOENT`.

        Returns:
            True if the file or directory does not exist.
        """
        return self.errno == ENOENT


def _c_path(path: StringSlice) raises -> List[UInt8]:
    var out = List[UInt8](capacity=path.byte_length() + 1)
    for b in path.as_bytes():
        if b == 0:
            raise Error("fs: NUL in path")
        out.append(b)
    out.append(0)
    return out^


def join(dir: StringSlice, name: StringSlice) -> String:
    """Joins a directory and a name with `/`.

    Args:
        dir: The directory; may be empty.
        name: The file name.

    Returns:
        The joined path.
    """
    if dir.byte_length() == 0:
        return String(name)
    if dir.endswith("/"):
        return String(dir) + String(name)
    return String(dir) + "/" + String(name)


struct File(Movable):
    """An open file descriptor, closed when the value is destroyed."""

    var _fd: Int
    var _path: String

    def __init__(out self, fd: Int, var path: String):
        """Wraps an open descriptor.

        Args:
            fd: The descriptor; owned from now on.
            path: The path, for error messages.
        """
        self._fd = fd
        self._path = path^

    def __deinit__(deinit self):
        """Closes the descriptor."""
        if self._fd >= 0:
            _ = syscall6(_SYS_CLOSE, self._fd, 0, 0, 0, 0, 0)

    def path(self) -> String:
        """Returns the path the file was opened at.

        Returns:
            The path.
        """
        return self._path

    def _err(self, op: StringSlice, rc: Int) -> Error:
        return Error(String(FsError(String(op, " ", self._path), -rc)))

    def write_all(mut self, data: Span[mut=False, UInt8, _]) raises:
        """Writes every byte at the current offset.

        Args:
            data: The bytes.

        Raises:
            If the kernel reports an error.
        """
        var done = 0
        while done < len(data):
            var n = syscall6(
                _SYS_WRITE,
                self._fd,
                Int(data.unsafe_ptr()) + done,
                len(data) - done,
                0,
                0,
                0,
            )
            if n == -_EINTR:
                continue
            if n <= 0:
                raise self._err("write", n if n < 0 else -5)
            done += n
        _ = len(data)

    def read_at(self, mut buf: List[UInt8], offset: Int, n: Int) raises -> Int:
        """Reads up to `n` bytes at an offset, replacing the buffer contents.

        Args:
            buf: The destination; resized to the bytes read.
            offset: The file offset.
            n: The number of bytes wanted.

        Returns:
            The number of bytes read; less than `n` only at end of file.

        Raises:
            If the kernel reports an error.
        """
        buf.resize(n, 0)
        var done = 0
        while done < n:
            var r = syscall6(
                _SYS_PREAD64,
                self._fd,
                Int(buf.unsafe_ptr()) + done,
                n - done,
                offset + done,
                0,
                0,
            )
            if r == -_EINTR:
                continue
            if r < 0:
                raise self._err("read", r)
            if r == 0:
                break
            done += r
        buf.resize(done, 0)
        return done

    def size(self) raises -> Int:
        """Returns the size of the file.

        Returns:
            The size in bytes.

        Raises:
            If the kernel reports an error.
        """
        var cur = syscall6(_SYS_LSEEK, self._fd, 0, 1, 0, 0, 0)
        var end = syscall6(_SYS_LSEEK, self._fd, 0, _SEEK_END, 0, 0, 0)
        if cur < 0 or end < 0:
            raise self._err("seek", end if end < 0 else cur)
        _ = syscall6(_SYS_LSEEK, self._fd, cur, 0, 0, 0, 0)
        return end

    def read_all(self) raises -> List[UInt8]:
        """Reads the whole file.

        Returns:
            The contents.

        Raises:
            If the kernel reports an error.
        """
        var out = List[UInt8]()
        _ = self.read_at(out, 0, self.size())
        return out^

    def sync(self) raises:
        """Flushes the file's data and metadata to disk (`fsync`).

        Raises:
            If the kernel reports an error.
        """
        var rc = syscall6(_SYS_FSYNC, self._fd, 0, 0, 0, 0, 0)
        if rc < 0:
            raise self._err("fsync", rc)

    def truncate(self, size: Int) raises:
        """Truncates or extends the file.

        Args:
            size: The new size.

        Raises:
            If the kernel reports an error.
        """
        var rc = syscall6(_SYS_FTRUNCATE, self._fd, size, 0, 0, 0, 0)
        if rc < 0:
            raise self._err("truncate", rc)

    def try_lock(self) raises:
        """Takes an exclusive advisory lock (`flock`) without waiting.

        Raises:
            If another process holds the lock.
        """
        var rc = syscall6(_SYS_FLOCK, self._fd, _LOCK_EX | _LOCK_NB, 0, 0, 0, 0)
        if rc < 0:
            raise self._err("lock", rc)


def _open(path: StringSlice, flags: Int) raises -> File:
    var c = _c_path(path)
    var fd = syscall6(
        _SYS_OPENAT,
        _AT_FDCWD,
        Int(c.unsafe_ptr()),
        flags | _O_CLOEXEC,
        0o644,
        0,
        0,
    )
    _ = len(c)
    if fd < 0:
        raise Error(String(FsError(String("open ", path), -fd)))
    return File(fd, String(path))


def open_read(path: StringSlice) raises -> File:
    """Opens an existing file for reading.

    Args:
        path: The path.

    Returns:
        The file.

    Raises:
        If the file cannot be opened; the message contains `errno 2` if it
        does not exist.
    """
    return _open(path, _O_RDONLY)


def create(path: StringSlice) raises -> File:
    """Creates or truncates a file for writing.

    Args:
        path: The path.

    Returns:
        The file, empty.

    Raises:
        If the file cannot be created.
    """
    return _open(path, _O_WRONLY | _O_CREAT | _O_TRUNC)


def open_append(path: StringSlice) raises -> File:
    """Opens or creates a file for appending.

    Args:
        path: The path.

    Returns:
        The file; writes go to its end.

    Raises:
        If the file cannot be opened.
    """
    return _open(path, _O_WRONLY | _O_CREAT | _O_APPEND)


def open_rw(path: StringSlice) raises -> File:
    """Opens or creates a file for reading and writing, without truncating.

    Args:
        path: The path.

    Returns:
        The file.

    Raises:
        If the file cannot be opened.
    """
    return _open(path, _O_RDWR | _O_CREAT)


def read_file(path: StringSlice) raises -> List[UInt8]:
    """Reads a whole file.

    Args:
        path: The path.

    Returns:
        The contents.

    Raises:
        If the file cannot be read.
    """
    return open_read(path).read_all()


def write_file(
    path: StringSlice, data: Span[mut=False, UInt8, _], sync: Bool
) raises:
    """Creates or replaces a file with the bytes given.

    Args:
        path: The path.
        data: The contents.
        sync: Whether to `fsync` before closing.

    Raises:
        If the file cannot be written.
    """
    var f = create(path)
    f.write_all(data)
    if sync:
        f.sync()


def exists(path: StringSlice) raises -> Bool:
    """Reports whether a path exists.

    Args:
        path: The path.

    Returns:
        True if the path exists.

    Raises:
        If the path is invalid.
    """
    var c = _c_path(path)
    var rc = syscall6(
        _SYS_FACCESSAT, _AT_FDCWD, Int(c.unsafe_ptr()), 0, 0, 0, 0
    )
    _ = len(c)
    return rc == 0


def rename(old: StringSlice, new: StringSlice) raises:
    """Renames a file, replacing `new` atomically if it exists.

    Args:
        old: The current path.
        new: The new path.

    Raises:
        If the rename fails.
    """
    var a = _c_path(old)
    var b = _c_path(new)
    var rc = syscall6(
        _SYS_RENAMEAT2,
        _AT_FDCWD,
        Int(a.unsafe_ptr()),
        _AT_FDCWD,
        Int(b.unsafe_ptr()),
        0,
        0,
    )
    _ = len(a)
    _ = len(b)
    if rc < 0:
        raise Error(String(FsError(String("rename ", old, " ", new), -rc)))


def remove(path: StringSlice) raises:
    """Removes a file.

    Args:
        path: The path.

    Raises:
        If the file cannot be removed.
    """
    var c = _c_path(path)
    var rc = syscall6(_SYS_UNLINKAT, _AT_FDCWD, Int(c.unsafe_ptr()), 0, 0, 0, 0)
    _ = len(c)
    if rc < 0:
        raise Error(String(FsError(String("remove ", path), -rc)))


def remove_dir(path: StringSlice) raises:
    """Removes an empty directory.

    Args:
        path: The path.

    Raises:
        If the directory cannot be removed.
    """
    var c = _c_path(path)
    var rc = syscall6(
        _SYS_UNLINKAT, _AT_FDCWD, Int(c.unsafe_ptr()), _AT_REMOVEDIR, 0, 0, 0
    )
    _ = len(c)
    if rc < 0:
        raise Error(String(FsError(String("rmdir ", path), -rc)))


def make_dir(path: StringSlice) raises -> Bool:
    """Creates a directory (mode 0777 minus the umask).

    Args:
        path: The path; its parent must exist.

    Returns:
        True if it was created, False if it already existed.

    Raises:
        If the directory cannot be created.
    """
    var c = _c_path(path)
    var rc = syscall6(
        _SYS_MKDIRAT, _AT_FDCWD, Int(c.unsafe_ptr()), 0o777, 0, 0, 0
    )
    _ = len(c)
    if rc == -EEXIST:
        return False
    if rc < 0:
        raise Error(String(FsError(String("mkdir ", path), -rc)))
    return True


def make_dir_all(path: StringSlice) raises:
    """Creates a directory and every missing parent (Go `os.MkdirAll`).

    Args:
        path: The path.

    Raises:
        If a directory cannot be created.
    """
    var bytes = path.as_bytes()
    for i in range(1, len(bytes)):
        if bytes[i] == UInt8(ord("/")):
            _ = make_dir(StringSlice(unsafe_from_utf8=bytes[:i]))
    _ = make_dir(path)


def list_dir(path: StringSlice) raises -> List[String]:
    """Lists the names in a directory, without `.` and `..`.

    Args:
        path: The directory.

    Returns:
        The names in kernel order.

    Raises:
        If the directory cannot be read.
    """
    var dir = _open(path, _O_RDONLY | _O_DIRECTORY)
    var names = List[String]()
    var buf = List[UInt8](length=8192, fill=0)
    while True:
        var n = syscall6(
            _SYS_GETDENTS64, dir._fd, Int(buf.unsafe_ptr()), len(buf), 0, 0, 0
        )
        if n == -_EINTR:
            continue
        if n < 0:
            raise Error(String(FsError(String("readdir ", path), -n)))
        if n == 0:
            break
        var off = 0
        while off < n:
            # struct linux_dirent64: ino u64, off i64, reclen u16, type u8,
            # name (NUL-terminated).
            var reclen = Int(buf[off + 16]) | (Int(buf[off + 17]) << 8)
            var start = off + 19
            var end = start
            while end < off + reclen and buf[end] != 0:
                end += 1
            var name = String(from_utf8_lossy=Span(buf)[start:end])
            if name != "." and name != "..":
                names.append(name^)
            off += reclen
    _ = dir._fd
    return names^


def sync_dir(path: StringSlice) raises:
    """Flushes a directory's entries to disk, making renames durable.

    Args:
        path: The directory.

    Raises:
        If the directory cannot be opened or synced.
    """
    _open(path, _O_RDONLY | _O_DIRECTORY).sync()
