"""Commands, ported from Dragonfly's `server/cmd`.

A command is declared as in Dragonfly: a struct whose fields are its
parameters, with a `run` method. Go fills the fields through runtime
reflection; Ignis does the same at compile time with `std.reflection`, so
the parser for each overload is generated from the struct's field list.

```mojo
from ignis import cmd


struct Teleport(cmd.Runnable):
    var victim: List[cmd.Target]
    var destination: Vec3
    var reason: cmd.Optional[cmd.Varargs]

    def __init__(out self):
        self.victim = List[cmd.Target]()
        self.destination = Vec3()
        self.reason = cmd.Optional[cmd.Varargs]()

    def run[S: cmd.Source](
        mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx
    ):
        o.print(t"teleported {len(self.victim)} entities")

    @staticmethod
    def tag(field: StaticString) -> StaticString:
        return "dest" if field == "destination" else ""   # `cmd:"dest"`


var tp = cmd.new[Source, Teleport, TeleportTo]("tp", "Teleports.", ["teleport"])
registry.register(tp)
registry.by_alias("teleport").value().execute("Steve 1 2 3", src, tx)
```

How Go's mechanisms map:

| Dragonfly | Ignis |
| --- | --- |
| struct fields → parameters | the same, via `reflect[R].field_names/field_types/field_ref` |
| unexported fields, `cmd:"-"` | fields starting with `_`, or tag `"-"` |
| `cmd:"name,suffix"` tag | `R.tag(field)`, a static method run at compile time |
| `cmd.New(name, desc, aliases, A{}, B{})` | `cmd.new[S, A, B](name, desc, aliases)` |
| a copy of the value passed to `New` per run | `R()` per run (`Runnable` is `Defaultable`) |
| `Run(src, o, tx)` | `run[S: Source](mut self, mut src, mut o, mut tx: S.Tx)` |
| `Allower`, `ParamDescriber` | traits checked with `conforms_to` |
| `cmd.Optional[T]`, `Varargs`, `SubCommand`, `[]Target` | `cmd.Optional[T]`, `Varargs`, `SubCommand`, `List[Target]` |
| `Parameter`, `Enum` interfaces | traits; an enum receives its option via `set_option` |
| `Source` interface + `*world.Tx` | `Source` trait with an associated `Tx: TargetProvider` |
| global `Register` / `ByAlias` / `Commands` | a `Registry[S]` value owned by the server |
| unsupported field type: panic at run time | compile error |

A `Command[S]` stores each overload as three function pointers generated
for its runnable type (execute, allow, describe parameters), which is how
it holds overloads of different types without trait objects. `S` is the
server's one source type (a player, a console, or a type that wraps both);
`run` stays generic over it so runnables do not depend on it.

Modules: `command` (Go `command.go`), `argument` (`argument.go`),
`parameter` (`parameter.go`), `output` (`output.go`), `source`
(`source.go`), `target` (`target.go`), `register` (`register.go`). The
`AvailableCommands` packet is built in `ignis.session.command`.
"""

from .argument import Line
from .command import (
    Allower,
    Command,
    ParamDescriber,
    ParamInfo,
    ParamKind,
    Runnable,
    new,
)
from .output import (
    MESSAGE_BOOLEAN_INVALID,
    MESSAGE_NO_TARGETS,
    MESSAGE_NUMBER_INVALID,
    MESSAGE_PARAMETER_INVALID,
    MESSAGE_PLAYER_NOT_FOUND,
    MESSAGE_SYNTAX,
    MESSAGE_UNKNOWN,
    MESSAGE_USAGE,
    Message,
    Output,
    Translation,
)
from .parameter import Enum, Optional, Parameter, SubCommand, Varargs
from .register import Registry
from .source import Source
from .target import NoTargets, Target, TargetProvider
