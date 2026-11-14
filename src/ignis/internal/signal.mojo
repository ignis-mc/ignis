"""Termination signals as a pollable descriptor, through raw Linux system
calls (nethernet's `syscall6`; no libc, no FFI).

Go's `signal.Notify(c, SIGINT, SIGTERM)` (Dragonfly `CloseOnProgramEnd`)
delivers signals on a channel. Here the signals are blocked and read from a
`signalfd`, which the server's event loop polls with its sockets.

A process-directed signal goes to any thread that does not block it, and
the Mojo runtime starts its worker threads before `main`, so blocking in
`main` alone is not enough: `block_in_every_thread` blocks the signals and
re-executes the program once, so that the runtime's threads inherit the
mask.
"""

from nethernet.os._sys.linux import syscall6
from std.sys.info import CompilationTarget

comptime _X86 = CompilationTarget.is_x86()

comptime _SYS_READ = 0 if _X86 else 63
comptime _SYS_CLOSE = 3 if _X86 else 57
comptime _SYS_RT_SIGPROCMASK = 14 if _X86 else 135
comptime _SYS_GETPID = 39 if _X86 else 172
comptime _SYS_GETTID = 186 if _X86 else 178
comptime _SYS_TGKILL = 234 if _X86 else 131
comptime _SYS_SIGNALFD4 = 289 if _X86 else 74
comptime _SYS_RT_SIGACTION = 13 if _X86 else 134
comptime _SYS_EXECVE = 59 if _X86 else 221
comptime _SYS_OPENAT = 257 if _X86 else 56
comptime _AT_FDCWD = -100
comptime _O_RDONLY_CLOEXEC = 0o2000000

comptime _SIG_BLOCK = 0
comptime _SIG_UNBLOCK = 1
comptime _SFD_NONBLOCK = 0o4000
comptime _SFD_CLOEXEC = 0o2000000
comptime _EAGAIN = 11
comptime _EINTR = 4
comptime _SIGINFO_SIZE = 128

comptime SIGINT = 2
"""Interrupt (Ctrl+C)."""
comptime SIGTERM = 15
"""Termination request (`kill`, service managers)."""


struct SignalFD(Movable):
    """Blocks a set of signals and receives them through a descriptor."""

    var _fd: Int
    var _mask: UInt64

    def __init__(out self, signals: List[Int]) raises:
        """Blocks `signals` and opens a non-blocking `signalfd` for them."""
        var mask = UInt64(0)
        for s in signals:
            mask |= UInt64(1) << UInt64(s - 1)
        var rc = syscall6(
            _SYS_RT_SIGPROCMASK, _SIG_BLOCK, Int(Pointer(to=mask)), 0, 8, 0, 0
        )
        if rc < 0:
            raise Error(t"rt_sigprocmask: errno {-rc}")
        var fd = syscall6(
            _SYS_SIGNALFD4,
            -1,
            Int(Pointer(to=mask)),
            8,
            _SFD_NONBLOCK | _SFD_CLOEXEC,
            0,
            0,
        )
        if fd < 0:
            _ = syscall6(
                _SYS_RT_SIGPROCMASK,
                _SIG_UNBLOCK,
                Int(Pointer(to=mask)),
                0,
                8,
                0,
                0,
            )
            raise Error(t"signalfd4: errno {-fd}")
        self._fd = fd
        self._mask = mask

    def __deinit__(deinit self):
        """Closes the descriptor and unblocks the signals."""
        _ = syscall6(_SYS_CLOSE, self._fd, 0, 0, 0, 0, 0)
        var mask = self._mask
        _ = syscall6(
            _SYS_RT_SIGPROCMASK, _SIG_UNBLOCK, Int(Pointer(to=mask)), 0, 8, 0, 0
        )
        _ = mask

    def fd(self) -> Int:
        """Returns the descriptor to poll for readability."""
        return self._fd

    def read(mut self) raises -> Optional[Int]:
        """Returns the next pending signal, or None if there is none."""
        var buf = List[UInt8](length=_SIGINFO_SIZE, fill=0)
        while True:
            var n = syscall6(
                _SYS_READ, self._fd, Int(buf.unsafe_ptr()), len(buf), 0, 0, 0
            )
            _ = len(buf)
            if n == -_EINTR:
                continue
            if n == -_EAGAIN:
                return None
            if n < 0:
                raise Error(t"read signalfd: errno {-n}")
            if n < 4:
                return None
            # struct signalfd_siginfo starts with u32 ssi_signo.
            var signo = (
                Int(buf[0])
                | (Int(buf[1]) << 8)
                | (Int(buf[2]) << 16)
                | (Int(buf[3]) << 24)
            )
            return signo


def _mask_of(signals: List[Int]) -> UInt64:
    var mask = UInt64(0)
    for s in signals:
        mask |= UInt64(1) << UInt64(s - 1)
    return mask


def blocked(signals: List[Int]) raises -> Bool:
    """Reports whether every one of `signals` is blocked in this thread."""
    var mask = _mask_of(signals)
    var old = UInt64(0)
    var rc = syscall6(
        _SYS_RT_SIGPROCMASK, _SIG_BLOCK, 0, Int(Pointer(to=old)), 8, 0, 0
    )
    if rc < 0:
        raise Error(t"rt_sigprocmask: errno {-rc}")
    return old & mask == mask


def block_in_every_thread(signals: List[Int]) raises:
    """Makes every thread block `signals`: returns at once if they are
    already blocked, else resets an inherited "ignore" to the default (as
    Go's `signal.Notify` does), blocks them and re-executes
    `/proc/self/exe` with the same arguments and environment. Returns only
    if they were blocked; raises if the re-execution failed."""
    if blocked(signals):
        return
    var dfl = List[UInt64](length=4, fill=0)
    for s in signals:
        _ = syscall6(_SYS_RT_SIGACTION, s, Int(dfl.unsafe_ptr()), 0, 8, 0, 0)
    _ = len(dfl)
    var mask = _mask_of(signals)
    var rc = syscall6(
        _SYS_RT_SIGPROCMASK, _SIG_BLOCK, Int(Pointer(to=mask)), 0, 8, 0, 0
    )
    _ = mask
    if rc < 0:
        raise Error(t"rt_sigprocmask: errno {-rc}")
    var cmdline = _read_proc("/proc/self/cmdline\0")
    var environ = _read_proc("/proc/self/environ\0")
    var argv = _pointers(cmdline)
    var envp = _pointers(environ)
    var path = List[UInt8]("/proc/self/exe\0".as_bytes())
    rc = syscall6(
        _SYS_EXECVE,
        Int(path.unsafe_ptr()),
        Int(argv.unsafe_ptr()),
        Int(envp.unsafe_ptr()),
        0,
        0,
        0,
    )
    _ = len(path)
    _ = len(argv)
    _ = len(envp)
    _ = len(cmdline)
    _ = len(environ)
    raise Error(t"execve /proc/self/exe: errno {-rc}")


def _read_proc(path: StringSlice) raises -> List[UInt8]:
    # /proc files report size 0, so read until end of file.
    var c = List[UInt8](path.as_bytes())
    var fd = syscall6(
        _SYS_OPENAT, _AT_FDCWD, Int(c.unsafe_ptr()), _O_RDONLY_CLOEXEC, 0, 0, 0
    )
    _ = len(c)
    if fd < 0:
        raise Error(t"open {path}: errno {-fd}")
    var out = List[UInt8]()
    var buf = List[UInt8](length=4096, fill=0)
    while True:
        var n = syscall6(
            _SYS_READ, fd, Int(buf.unsafe_ptr()), len(buf), 0, 0, 0
        )
        if n == -_EINTR:
            continue
        if n <= 0:
            break
        out.extend(Span(buf)[:n])
    _ = len(buf)
    _ = syscall6(_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
    return out^


def _pointers(mut strings: List[UInt8]) -> List[Int]:
    # NUL-separated strings to a NULL-terminated array of pointers into them.
    if len(strings) > 0 and strings[len(strings) - 1] != 0:
        strings.append(0)
    var out = List[Int]()
    var base = Int(strings.unsafe_ptr())
    var start = 0
    for i in range(len(strings)):
        if strings[i] == 0:
            out.append(base + start)
            start = i + 1
    out.append(0)
    return out^


def raise_signal(sig: Int) raises:
    """Sends a signal to the calling thread (`tgkill`), for tests: a
    process-directed `kill` may go to a runtime thread that does not block
    it."""
    var pid = syscall6(_SYS_GETPID, 0, 0, 0, 0, 0, 0)
    var tid = syscall6(_SYS_GETTID, 0, 0, 0, 0, 0, 0)
    var rc = syscall6(_SYS_TGKILL, pid, tid, sig, 0, 0, 0)
    if rc < 0:
        raise Error(t"tgkill: errno {-rc}")
