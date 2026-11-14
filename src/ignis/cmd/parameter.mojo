"""Parameter types (Dragonfly `server/cmd/parameter.go`).

A runnable's fields are its parameters. Supported field types, with the
name shown in the usage:

| Field type | Usage | Go |
| --- | --- | --- |
| `Int8` … `Int64`, `Int` | `int` | `int8` … `int64`, `int` |
| `UInt8` … `UInt64`, `UInt` | `uint` | `uint8` … `uint64`, `uint` |
| `Float32`, `Float64` | `float` | `float32`, `float64` |
| `String` | `string` | `string` |
| `Bool` | `bool` | `bool` |
| `Vec3` (`ignis.mgl64`) | `x y z` | `mgl64.Vec3` |
| `Varargs` | `text` | `cmd.Varargs` |
| `List[Target]` | `target` | `[]cmd.Target` |
| `SubCommand` | the parameter name | `cmd.SubCommand` |
| a `Parameter` | its `type()` | `cmd.Parameter` |
| an `Enum` | its `type()` | `cmd.Enum` |
| `Optional[T]` of any of these | as `T`, in brackets | `cmd.Optional[T]` |

Any other field type is a compile error (Go panics when the command runs).
"""

from std.collections.optional import Optional as _StdOptional

from .argument import Line
from .output import Message
from .source import Source


trait Parameter(Defaultable, Deinitable, Movable):
    """A custom parameter type (Go `cmd.Parameter`)."""

    def parse(mut self, mut line: Line) raises Message:
        """Reads the parameter from the line.

        As in Go, the parser consumes one more argument after `parse`
        returns, so read the last argument with `line.next()` without
        removing it (and remove any earlier ones with `line.remove_next()`).
        """
        ...

    def type(self) -> String:
        """Gets the type name shown in the usage and to the client."""
        ...


trait Enum(Defaultable, Deinitable, Movable):
    """A parameter limited to a set of options (Go `cmd.Enum`).

    Go requires enums to be string types and sets the string. Here the type
    receives the chosen option through `set_option`; typically it is a
    struct with one `String` field:

    ```mojo
    @fieldwise_init
    struct GameMode(cmd.Enum):
        var value: String

        def __init__(out self):
            self.value = ""

        def type(self) -> String:
            return "GameMode"

        def options[S: cmd.Source](self, src: S) -> List[String]:
            return ["survival", "creative"]

        def set_option(mut self, var option: String):
            self.value = option^
    ```
    """

    def type(self) -> String:
        """Gets the enum's type name. It identifies the enum to the client,
        so different enums need different names."""
        ...

    def options[S: Source](self, src: S) -> List[String]:
        """Lists the options, which may depend on the source."""
        ...

    def set_option(mut self, var option: String):
        """Stores the chosen option, spelled as `options` lists it."""
        ...


struct SubCommand(Copyable, Defaultable):
    """A fixed word that must be written: its name is the parameter name
    (Go `cmd.SubCommand`). Overloads that start with different subcommands
    make a command with subcommands."""

    def __init__(out self):
        """Creates the marker."""
        pass


@fieldwise_init
struct Varargs(Copyable, Defaultable, Equatable, Writable):
    """Every remaining argument, joined with spaces (Go `cmd.Varargs`)."""

    var value: String
    """The text."""

    def __init__(out self):
        """Creates empty text."""
        self.value = String()

    def __eq__(self, other: Self) -> Bool:
        """Compares the text."""
        return self.value == other.value

    def write_to(self, mut writer: Some[Writer]):
        """Writes the text."""
        writer.write(self.value)


trait _OptionalT(Defaultable, Deinitable, Movable):
    """Identifies `Optional` fields (Go `optionalT`)."""

    comptime Inner: Copyable & Defaultable & Deinitable
    """The wrapped parameter type."""

    def _with(mut self, var value: Self.Inner):
        """Stores a parsed value and marks the parameter as set."""
        ...


struct Optional[T: Copyable & Defaultable & Deinitable](
    Copyable, Defaultable, _OptionalT
):
    """Makes a parameter optional (Go `cmd.Optional[T]`).

    Optional parameters must come after every required one. Inside the
    package, refer to the standard library's `Optional` by its full path;
    users write `cmd.Optional[T]` after `from ignis import cmd`.
    """

    comptime Inner = Self.T
    """The wrapped parameter type."""

    var _val: Self.T
    var _set: Bool

    def __init__(out self):
        """Creates an unset parameter."""
        self._val = Self.T()
        self._set = False

    def __init__(out self, var value: Self.T):
        """Creates a set parameter."""
        self._val = value^
        self._set = True

    def load(self) -> _StdOptional[Self.T]:
        """Gets the value if the source filled it in (Go `Load`)."""
        if self._set:
            return self._val.copy()
        return None

    def load_or(self, var default: Self.T) -> Self.T:
        """Gets the value, or `default` if it was not filled in (Go
        `LoadOr`)."""
        if self._set:
            return self._val.copy()
        return default^

    def is_set(self) -> Bool:
        """Reports whether the source filled in the parameter."""
        return self._set

    def _with(mut self, var value: Self.T):
        """Stores a parsed value and marks the parameter as set."""
        self._val = value^
        self._set = True
