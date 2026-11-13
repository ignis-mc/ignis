"""The sample commands of `interop/cmd/main.go`, field for field, and a test
source. Shared by the command and session tests."""

from std.memory import bitcast

from ignis import cmd
from ignis.mgl64 import Vec3
from minecraft.protocol.uuid import UUID


struct TestTx(cmd.TargetProvider, Copyable, Defaultable):
    """Entities for target selectors; detached by default (Go nil tx)."""

    var is_attached: Bool
    var all: List[cmd.Target]

    def __init__(out self):
        self.is_attached = False
        self.all = List[cmd.Target]()

    def attached(self) -> Bool:
        return self.is_attached

    def entities(self) -> List[cmd.Target]:
        return self.all.copy()

    def players(self) -> List[cmd.Target]:
        var out = List[cmd.Target]()
        for t in self.all:
            if t.player:
                out.append(t.copy())
        return out^


struct TestSource(cmd.Source, Copyable):
    """The Go program's `source`: an operator or a plain user."""

    comptime Tx = TestTx
    var name: String
    var op: Bool
    var pos: Vec3
    var out: cmd.Output
    var outputs: Int

    def __init__(out self, var name: String, op: Bool):
        self.name = name^
        self.op = op
        self.pos = Vec3(1, 2, 3)
        self.out = cmd.Output()
        self.outputs = 0

    def position(self) -> Vec3:
        return self.pos

    def target(self) -> cmd.Target:
        return cmd.Target(uuid(0), self.name.copy(), self.pos, True)

    def send_command_output(mut self, o: cmd.Output):
        self.out = o.copy()
        self.outputs += 1


def uuid(n: Int) -> UUID:
    var u = UUID()
    u.bytes[15] = UInt8(n)
    return u


def is_op[S: cmd.Source](src: S) -> Bool:
    comptime if S == TestSource:
        return rebind[TestSource](src).op
    else:
        return False


def b(v: Bool) -> String:
    """Go's `%v` for a bool."""
    return "true" if v else "false"


def f64(f: Float64) -> String:
    """Go's `%016x` of the float bits."""
    return _hex(UInt64(bitcast[DType.uint64](f)), 16)


def f32(f: Float32) -> String:
    """Go's `%08x` of the float bits."""
    return _hex(UInt64(bitcast[DType.uint32](f)), 8)


def _hex(v: UInt64, width: Int) -> String:
    comptime DIGITS = "0123456789abcdef"
    var out = String()
    for i in range(width - 1, -1, -1):
        var d = Int((v >> UInt64(i * 4)) & 0xF)
        out += String(DIGITS[byte = d : d + 1])
    return out^


def opt_targets(t: cmd.Optional[List[cmd.Target]]) -> String:
    var v = t.load()
    if not v:
        return "unset"
    return String(len(v.value()))


@fieldwise_init
struct GameMode(cmd.Enum):
    var value: String

    def __init__(out self):
        self.value = ""

    def type(self) -> String:
        return "GameMode"

    def options[S: cmd.Source](self, src: S) -> List[String]:
        return ["survival", "creative", "adventure", "spectator"]

    def set_option(mut self, var option: String):
        self.value = option^


@fieldwise_init
struct Item(cmd.Enum):
    var value: String

    def __init__(out self):
        self.value = ""

    def type(self) -> String:
        return "Item"

    def options[S: cmd.Source](self, src: S) -> List[String]:
        if is_op(src):
            return ["apple", "bread", "diamond", "creative"]
        return ["apple", "bread"]

    def set_option(mut self, var option: String):
        self.value = option^


@fieldwise_init
struct Coord(cmd.Parameter):
    var value: String

    def __init__(out self):
        self.value = ""

    def parse(mut self, mut line: cmd.Line) raises cmd.Message:
        var arg = line.next()
        if not arg:
            raise line.usage_error()
        var s = arg.value()
        var digits = s.removeprefix("~")
        for c in digits.as_bytes():
            if c < UInt8(ord("0")) or c > UInt8(ord("9")):
                raise cmd.MESSAGE_NUMBER_INVALID.f(s)
        self.value = s^

    def type(self) -> String:
        return "coord"


struct GameModeSet(cmd.Runnable):
    var mode: GameMode
    var player: cmd.Optional[List[cmd.Target]]

    def __init__(out self):
        self.mode = GameMode()
        self.player = cmd.Optional[List[cmd.Target]]()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        o.print(t"gamemode set {self.mode.value} {opt_targets(self.player)}")


struct GameModeInt(cmd.Runnable):
    var mode: Int
    var player: cmd.Optional[List[cmd.Target]]

    def __init__(out self):
        self.mode = 0
        self.player = cmd.Optional[List[cmd.Target]]()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        o.print(t"gamemode int {self.mode} {opt_targets(self.player)}")


struct TpPos(cmd.Runnable):
    var destination: Vec3

    def __init__(out self):
        self.destination = Vec3()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        var d = self.destination
        o.print(t"tp pos {f64(d.x)} {f64(d.y)} {f64(d.z)}")


struct TpTargets(cmd.Runnable):
    var victim: List[cmd.Target]
    var destination: List[cmd.Target]

    def __init__(out self):
        self.victim = List[cmd.Target]()
        self.destination = List[cmd.Target]()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        o.print(t"tp targets {len(self.victim)} {len(self.destination)}")


struct Say(cmd.Runnable):
    var message: cmd.Varargs

    def __init__(out self):
        self.message = cmd.Varargs()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        o.print(t"say [{self.message}]")


struct XpLevels(cmd.Runnable):
    var amount: Int32
    var player: cmd.Optional[List[cmd.Target]]

    def __init__(out self):
        self.amount = 0
        self.player = cmd.Optional[List[cmd.Target]]()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        o.print(t"xp levels {self.amount} {opt_targets(self.player)}")

    @staticmethod
    def tag(field: StaticString) -> StaticString:
        if field == "amount":
            return "amount,L"
        return ""


struct XpPoints(cmd.Runnable):
    var amount: Int32
    var player: cmd.Optional[List[cmd.Target]]

    def __init__(out self):
        self.amount = 0
        self.player = cmd.Optional[List[cmd.Target]]()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        o.print(t"xp points {self.amount} {opt_targets(self.player)}")


struct ConfigSet(cmd.Runnable):
    var set: cmd.SubCommand
    var key: String
    var value: Float64

    def __init__(out self):
        self.set = cmd.SubCommand()
        self.key = ""
        self.value = 0

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        o.print(t"config set [{self.key}] {f64(self.value)}")


struct ConfigGet(cmd.Runnable):
    var get: cmd.SubCommand
    var key: String

    def __init__(out self):
        self.get = cmd.SubCommand()
        self.key = ""

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        o.print(t"config get [{self.key}]")


struct ConfigToggle(cmd.Runnable):
    var toggle: cmd.SubCommand
    var key: String
    var on: cmd.Optional[Bool]

    def __init__(out self):
        self.toggle = cmd.SubCommand()
        self.key = ""
        self.on = cmd.Optional[Bool]()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        var on = self.on.load_or(False)
        o.print(t"config toggle [{self.key}] {b(on)} {b(self.on.is_set())}")


struct Give(cmd.Runnable):
    var player: List[cmd.Target]
    var item: Item
    var amount: cmd.Optional[UInt8]
    var data: cmd.Optional[Int16]

    def __init__(out self):
        self.player = List[cmd.Target]()
        self.item = Item()
        self.amount = cmd.Optional[UInt8]()
        self.data = cmd.Optional[Int16]()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        var n = len(self.player)
        var amount = self.amount.load_or(1)
        var data = self.data.load_or(-1)
        o.print(t"give {n} {self.item.value} {amount} {data}")


struct Num(cmd.Runnable):
    var i8: Int8
    var u16: UInt16
    var i64: Int64
    var f32: Float32
    var u: UInt

    def __init__(out self):
        self.i8 = 0
        self.u16 = 0
        self.i64 = 0
        self.f32 = 0
        self.u = 0

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        o.print(t"num {self.i8} {self.u16} {self.i64} {f32(self.f32)} {self.u}")


struct Secret(cmd.Allower, cmd.Runnable):
    def __init__(out self):
        pass

    def allow[S: cmd.Source](self, src: S) -> Bool:
        return is_op(src)

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        o.print("secret")


struct Mark(cmd.Runnable):
    var pos: Coord
    var note: cmd.Optional[cmd.Varargs]

    def __init__(out self):
        self.pos = Coord()
        self.note = cmd.Optional[cmd.Varargs]()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        var note = self.note.load_or(cmd.Varargs("none"))
        o.print(t"mark [{self.pos.value}] [{note}]")


struct Flag(cmd.Runnable):
    var on: Bool

    def __init__(out self):
        self.on = False

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        o.print(t"flag {b(self.on)}")


def sample_commands() -> List[cmd.Command[TestSource]]:
    """The Go program's `commands`, in the same order."""
    var out = List[cmd.Command[TestSource]]()
    out.append(
        cmd.new[TestSource, GameModeSet, GameModeInt](
            "gamemode", "Sets a player's game mode.", ["gm", "GMode"]
        )
    )
    out.append(
        cmd.new[TestSource, TpPos, TpTargets](
            "tp", "Teleports entities.", ["teleport"]
        )
    )
    out.append(cmd.new[TestSource, Say]("say", "Broadcasts a message.", []))
    out.append(
        cmd.new[TestSource, XpLevels, XpPoints]("xp", "Adds experience.", [])
    )
    out.append(
        cmd.new[TestSource, ConfigSet, ConfigGet, ConfigToggle](
            "config", "Changes a setting.", []
        )
    )
    out.append(cmd.new[TestSource, Give]("give", "Gives an item.", []))
    out.append(cmd.new[TestSource, Num]("num", "Parses numbers.", []))
    out.append(
        cmd.new[TestSource, Secret]("SECRET", "Operators only.", ["hidden"])
    )
    out.append(cmd.new[TestSource, Mark]("mark", "Marks a coordinate.", []))
    out.append(cmd.new[TestSource, Flag]("flag", "Parses a bool.", []))
    return out^


def sample_registry() -> cmd.Registry[TestSource]:
    var r = cmd.Registry[TestSource]()
    for c in sample_commands():
        r.register(c)
    return r^


def unescape(s: StringSlice) -> String:
    """Reverses the Go program's `esc`."""
    var out = String()
    var bytes = s.as_bytes()
    var start = 0
    var i = 0
    while i < len(bytes):
        if bytes[i] == UInt8(ord("\\")) and i + 1 < len(bytes):
            out += String(s[byte=start:i])
            var c = bytes[i + 1]
            if c == UInt8(ord("n")):
                out += "\n"
            elif c == UInt8(ord("t")):
                out += "\t"
            elif c == UInt8(ord("r")):
                out += "\r"
            else:
                out += "\\"
            i += 2
            start = i
            continue
        i += 1
    out += String(s[byte=start:])
    return out^


def read_vectors() raises -> List[List[String]]:
    """Reads `test/data/cmd/vectors.txt` as unescaped tab-separated rows."""
    var text = open("test/data/cmd/vectors.txt", "r").read()
    var rows = List[List[String]]()
    for line in text.split("\n"):
        if line.byte_length() == 0:
            continue
        var row = List[String]()
        for f in line.split("\t"):
            row.append(unescape(f))
        rows.append(row^)
    return rows^
