"""Termination signals as a pollable descriptor, through raw Linux system
calls (nethernet's `syscall6`; no libc, no FFI).

Go's `signal.Notify(c, SIGINT, SIGTERM)` (Dragonfly `CloseOnProgramEnd`)
delivers signals on a channel. Here the signals are blocked and read from a
`signalfd`, which the server's event loop polls with its sockets. Blocking
works because the process is single-threaded: a signal blocked in the only
thread stays pending until it is read.
"""

from nethernet.os._sys.linux import syscall6
from std.sys.info import CompilationTarget

comptime _X86 = CompilationTarget.is_x86()

comptime _SYS_READ = 0 if _X86 else 63
comptime _SYS_CLOSE = 3 if _X86 else 57
comptime _SYS_RT_SIGPROCMASK = 14 if _X86 else 135
comptime _SYS_GETPID = 39 if _X86 else 172
comptime _SYS_KILL = 62 if _X86 else 129
comptime _SYS_SIGNALFD4 = 289 if _X86 else 74

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


def raise_signal(sig: Int) raises:
    """Sends a signal to the current process (`kill(getpid(), sig)`)."""
    var pid = syscall6(_SYS_GETPID, 0, 0, 0, 0, 0, 0)
    var rc = syscall6(_SYS_KILL, pid, sig, 0, 0, 0, 0)
    if rc < 0:
        raise Error(t"kill: errno {-rc}")
