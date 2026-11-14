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
        """Writes `op: errno N`."""
        writer.write(self.op, ": errno ", self.errno)

    def not_found(self) -> Bool:
        """Reports whether the error is `ENOENT`."""
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
    """Joins a directory and a name with `/`."""
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
        """Wraps an open descriptor."""
        self._fd = fd
        self._path = path^

    def __deinit__(deinit self):
        """Closes the descriptor."""
        if self._fd >= 0:
            _ = syscall6(_SYS_CLOSE, self._fd, 0, 0, 0, 0, 0)

    def path(self) -> String:
        """Returns the path the file was opened at."""
        return self._path

    def _err(self, op: StringSlice, rc: Int) -> Error:
        return Error(String(FsError(String(op, " ", self._path), -rc)))

    def write_all(mut self, data: Span[mut=False, UInt8, _]) raises:
        """Writes every byte at the current offset."""
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
        """Reads up to `n` bytes at an offset, replacing the buffer contents."""
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
        """Returns the size of the file."""
        var cur = syscall6(_SYS_LSEEK, self._fd, 0, 1, 0, 0, 0)
        var end = syscall6(_SYS_LSEEK, self._fd, 0, _SEEK_END, 0, 0, 0)
        if cur < 0 or end < 0:
            raise self._err("seek", end if end < 0 else cur)
        _ = syscall6(_SYS_LSEEK, self._fd, cur, 0, 0, 0, 0)
        return end

    def read_all(self) raises -> List[UInt8]:
        """Reads the whole file, until `read` reports its end."""
        var out = List[UInt8]()
        var buf = List[UInt8]()
        while True:
            var n = self.read_at(buf, len(out), 1 << 16)
            if n == 0:
                break
            out.extend(Span(buf))
        return out^

    def sync(self) raises:
        """Flushes the file's data and metadata to disk (`fsync`)."""
        var rc = syscall6(_SYS_FSYNC, self._fd, 0, 0, 0, 0, 0)
        if rc < 0:
            raise self._err("fsync", rc)

    def truncate(self, size: Int) raises:
        """Truncates or extends the file."""
        var rc = syscall6(_SYS_FTRUNCATE, self._fd, size, 0, 0, 0, 0)
        if rc < 0:
            raise self._err("truncate", rc)

    def try_lock(self) raises:
        """Takes an exclusive advisory lock (`flock`) without waiting."""
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
    """Opens an existing file for reading."""
    return _open(path, _O_RDONLY)


def create(path: StringSlice) raises -> File:
    """Creates or truncates a file for writing."""
    return _open(path, _O_WRONLY | _O_CREAT | _O_TRUNC)


def open_append(path: StringSlice) raises -> File:
    """Opens or creates a file for appending."""
    return _open(path, _O_WRONLY | _O_CREAT | _O_APPEND)


def open_rw(path: StringSlice) raises -> File:
    """Opens or creates a file for reading and writing, without truncating."""
    return _open(path, _O_RDWR | _O_CREAT)


def read_file(path: StringSlice) raises -> List[UInt8]:
    """Reads a whole file."""
    return open_read(path).read_all()


def write_file(
    path: StringSlice, data: Span[mut=False, UInt8, _], sync: Bool
) raises:
    """Creates or replaces a file with the bytes given."""
    var f = create(path)
    f.write_all(data)
    if sync:
        f.sync()


def exists(path: StringSlice) raises -> Bool:
    """Reports whether a path exists."""
    var c = _c_path(path)
    var rc = syscall6(
        _SYS_FACCESSAT, _AT_FDCWD, Int(c.unsafe_ptr()), 0, 0, 0, 0
    )
    _ = len(c)
    return rc == 0


def rename(old: StringSlice, new: StringSlice) raises:
    """Renames a file, replacing `new` atomically if it exists."""
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
    """Removes a file."""
    var c = _c_path(path)
    var rc = syscall6(_SYS_UNLINKAT, _AT_FDCWD, Int(c.unsafe_ptr()), 0, 0, 0, 0)
    _ = len(c)
    if rc < 0:
        raise Error(String(FsError(String("remove ", path), -rc)))


def remove_dir(path: StringSlice) raises:
    """Removes an empty directory."""
    var c = _c_path(path)
    var rc = syscall6(
        _SYS_UNLINKAT, _AT_FDCWD, Int(c.unsafe_ptr()), _AT_REMOVEDIR, 0, 0, 0
    )
    _ = len(c)
    if rc < 0:
        raise Error(String(FsError(String("rmdir ", path), -rc)))


def make_dir(path: StringSlice) raises -> Bool:
    """Creates a directory (mode 0777 minus the umask)."""
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
    """Creates a directory and every missing parent (Go `os.MkdirAll`)."""
    var bytes = path.as_bytes()
    for i in range(1, len(bytes)):
        if bytes[i] == UInt8(ord("/")):
            _ = make_dir(StringSlice(unsafe_from_utf8=bytes[:i]))
    _ = make_dir(path)


def list_dir(path: StringSlice) raises -> List[String]:
    """Lists the names in a directory, without `.` and `..`."""
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
    """Flushes a directory's entries to disk, making renames durable."""
    _open(path, _O_RDONLY | _O_DIRECTORY).sync()


def is_dir(path: StringSlice) raises -> Bool:
    """Reports whether a path is a directory."""
    var c = _c_path(path)
    var fd = syscall6(
        _SYS_OPENAT,
        _AT_FDCWD,
        Int(c.unsafe_ptr()),
        _O_RDONLY | _O_DIRECTORY | _O_CLOEXEC,
        0,
        0,
        0,
    )
    _ = len(c)
    if fd < 0:
        return False
    _ = syscall6(_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
    return True
