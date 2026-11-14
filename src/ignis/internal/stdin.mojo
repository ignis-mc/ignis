"""Lines from a descriptor such as standard input, read without blocking the
event loop, through raw Linux system calls (nethernet's `syscall6`).

The server polls the descriptor with its sockets and calls `read_lines` only
when it is readable, so the one `read` it makes does not block.
"""

from nethernet.os._sys.linux import syscall6
from std.sys.info import CompilationTarget

comptime _X86 = CompilationTarget.is_x86()

comptime _SYS_READ = 0 if _X86 else 63
comptime _SYS_WRITE = 1 if _X86 else 64
comptime _SYS_CLOSE = 3 if _X86 else 57
comptime _SYS_PIPE2 = 293 if _X86 else 59
comptime _EAGAIN = 11
comptime _EINTR = 4
comptime _O_CLOEXEC = 0o2000000
comptime _MAX_LINE = 64 * 1024

comptime STDIN = 0
"""The descriptor of standard input."""


struct LineReader(Movable):
    """Splits what a descriptor delivers into lines."""

    var _fd: Int
    var _buf: List[UInt8]
    var _eof: Bool

    def __init__(out self, fd: Int = STDIN):
        """Reads from `fd`, which stays owned by the caller."""
        self._fd = fd
        self._buf = List[UInt8]()
        self._eof = False

    def fd(self) -> Int:
        """Returns the descriptor to poll for readability."""
        return self._fd

    def eof(self) -> Bool:
        """Reports whether the descriptor reached end of file (or failed)."""
        return self._eof

    def read_lines(mut self) -> List[String]:
        """Reads once and returns the complete lines received, without their
        line endings; a last line without a newline is returned at end of
        file. Invalid UTF-8 is replaced."""
        var out = List[String]()
        if self._eof:
            return out^
        var chunk = List[UInt8](length=4096, fill=0)
        var n: Int
        while True:
            n = syscall6(
                _SYS_READ,
                self._fd,
                Int(chunk.unsafe_ptr()),
                len(chunk),
                0,
                0,
                0,
            )
            if n != -_EINTR:
                break
        _ = len(chunk)
        if n == -_EAGAIN:
            return out^
        if n <= 0:
            self._eof = True
            if len(self._buf) > 0:
                out.append(_line(self._buf))
                self._buf.clear()
            return out^
        var start = 0
        for i in range(n):
            if chunk[i] == UInt8(ord("\n")):
                self._buf.extend(Span(chunk)[start:i])
                out.append(_line(self._buf))
                self._buf.clear()
                start = i + 1
        self._buf.extend(Span(chunk)[start:n])
        if len(self._buf) > _MAX_LINE:
            # A runaway line without a newline: drop it.
            self._buf.clear()
        return out^


def _line(b: List[UInt8]) -> String:
    var end = len(b)
    if end > 0 and b[end - 1] == UInt8(ord("\r")):
        end -= 1
    return String(from_utf8_lossy=Span(b)[:end])


def pipe() raises -> Tuple[Int, Int]:
    """Creates a pipe and returns its read and write descriptors (tests)."""
    var fds = List[Int32](length=2, fill=0)
    var rc = syscall6(_SYS_PIPE2, Int(fds.unsafe_ptr()), _O_CLOEXEC, 0, 0, 0, 0)
    _ = len(fds)
    if rc < 0:
        raise Error(t"pipe2: errno {-rc}")
    return (Int(fds[0]), Int(fds[1]))


def write_fd(fd: Int, data: Span[mut=False, UInt8, _]) raises:
    """Writes every byte to a descriptor (tests)."""
    var done = 0
    while done < len(data):
        var n = syscall6(
            _SYS_WRITE,
            fd,
            Int(data.unsafe_ptr()) + done,
            len(data) - done,
            0,
            0,
            0,
        )
        if n == -_EINTR:
            continue
        if n <= 0:
            raise Error(t"write: errno {-n}")
        done += n
    _ = len(data)


def close_fd(fd: Int):
    """Closes a descriptor (tests)."""
    _ = syscall6(_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
