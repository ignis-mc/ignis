"""Commands built from runnable structs (Dragonfly `server/cmd/command.go`).

See the package docstring for how a Go `Runnable` struct maps to Mojo.
"""

from std.builtin.rebind import downcast
from std.reflection import reflect

from .argument import Line, _parse_argument, split_args
from .output import MESSAGE_UNKNOWN, MESSAGE_USAGE, Message, Output
from .parameter import Enum, Parameter, SubCommand, Varargs, _OptionalT
from .source import Source
from .target import Target
from ..mgl64 import Vec3


trait Runnable(Defaultable, Deinitable, Movable):
    """A command overload: a struct whose fields are its parameters (Go
    `cmd.Runnable`).

    Before `run` is called, every parameter field holds the value parsed
    from the command line. Each execution starts from `Self()`, so fields
    that are not parameters (names starting with `_`, or tagged `"-"`) hold
    whatever `__init__` gives them.
    """

    def run[S: Source](mut self, mut src: S, mut o: Output, mut tx: S.Tx):
        """Runs the command (Go `Run`)."""
        ...

    @staticmethod
    def tag(field: StaticString) -> StaticString:
        """Gets the tag of a field, as Go's `cmd:"name,suffix"` struct tag.

        It is evaluated at compile time. Return `""` to use the field name,
        `"name"` or `"name,suffix"` to rename the parameter or add a suffix,
        and `"-"` to make the field not a parameter.
        """
        return ""


trait Allower:
    """Limits the sources that may run a runnable (Go `cmd.Allower`)."""

    def allow[S: Source](self, src: S) -> Bool:
        """Reports whether the source may run the runnable."""
        ...


trait ParamDescriber:
    """Lets a runnable describe its parameters itself instead of through
    its fields (Go `cmd.ParamDescriber`)."""

    def describe_params[S: Source](self, src: S) -> List[ParamInfo]:
        """Describes the parameters for a source."""
        ...


@fieldwise_init
struct ParamKind(Equatable, ImplicitlyCopyable, Writable):
    """What kind of value a parameter takes. It replaces the `Value any` of
    Go's `ParamInfo`, whose dynamic type the session switches on."""

    var value: UInt8
    """The kind."""

    comptime INT = ParamKind(0)
    """A signed integer."""
    comptime UINT = ParamKind(1)
    """An unsigned integer."""
    comptime FLOAT = ParamKind(2)
    """A float."""
    comptime STRING = ParamKind(3)
    """A string."""
    comptime VARARGS = ParamKind(4)
    """`Varargs`."""
    comptime BOOL = ParamKind(5)
    """A bool."""
    comptime VEC3 = ParamKind(6)
    """A `Vec3`."""
    comptime TARGET = ParamKind(7)
    """Targets."""
    comptime SUB_COMMAND = ParamKind(8)
    """A `SubCommand`."""
    comptime ENUM = ParamKind(9)
    """An `Enum`."""
    comptime PARAMETER = ParamKind(10)
    """A custom `Parameter`."""

    def __eq__(self, other: Self) -> Bool:
        """Compares kinds."""
        return self.value == other.value

    def write_to(self, mut writer: Some[Writer]):
        """Writes the kind number."""
        writer.write("ParamKind(", self.value, ")")


struct ParamInfo(Copyable, Defaultable):
    """One parameter of a runnable (Go `cmd.ParamInfo`)."""

    var name: String
    """The parameter name."""
    var kind: ParamKind
    """The kind of value (Go: the dynamic type of `Value`)."""
    var type_name: String
    """The type name shown in the usage; for enums and custom parameters,
    their `type()`."""
    var options: List[String]
    """The enum options for the source (enums only)."""
    var optional: Bool
    """Whether the parameter may be left out."""
    var suffix: String
    """The suffix from the tag."""

    def __init__(out self):
        """Creates an empty description."""
        self.name = String()
        self.kind = ParamKind.STRING
        self.type_name = String()
        self.options = List[String]()
        self.optional = False
        self.suffix = String()

    def __init__(
        out self,
        var name: String,
        kind: ParamKind,
        var type_name: String,
        var options: List[String],
        optional: Bool,
        var suffix: String,
    ):
        """Creates a description."""
        self.name = name^
        self.kind = kind
        self.type_name = type_name^
        self.options = options^
        self.optional = optional
        self.suffix = suffix^


# --- Field metadata (Go: struct tags and reflection) ---------------------


def _tag_name(tag: StaticString) -> StaticString:
    """The name part of a tag (before the comma)."""
    var i = tag.find(",")
    if i < 0:
        return tag
    return tag[byte=:i]


def _tag_suffix(tag: StaticString) -> StaticString:
    """The suffix part of a tag (after the comma)."""
    var i = tag.find(",")
    if i < 0:
        return ""
    return tag[byte = i + 1 :]


def _param_name[R: Runnable, i: Int]() -> StaticString:
    """Go `name`: the tag name, or the field name."""
    comptime field = reflect[R].field_names()[i]
    comptime name = _tag_name(R.tag(field))
    comptime if name == "":
        return field
    else:
        return name


def _exported[R: Runnable, i: Int]() -> Bool:
    """Go `exportedFields`: fields not starting with `_` and not tagged
    `"-"`."""
    comptime field = reflect[R].field_names()[i]
    return not field.startswith("_") and _tag_name(R.tag(field)) != "-"


def _is_optional[T: AnyType]() -> Bool:
    return conforms_to(T, _OptionalT)


def _kind[T: AnyType]() -> ParamKind:
    """The kind of a (non-optional) parameter type."""
    comptime if (
        T == Int8 or T == Int16 or T == Int32 or T == Int64 or T == Int
    ):
        return ParamKind.INT
    elif (T == UInt8 or T == UInt16 or T == UInt32 or T == UInt64 or T == UInt):
        return ParamKind.UINT
    elif T == Float32 or T == Float64:
        return ParamKind.FLOAT
    elif T == String:
        return ParamKind.STRING
    elif T == Varargs:
        return ParamKind.VARARGS
    elif T == Bool:
        return ParamKind.BOOL
    elif T == Vec3:
        return ParamKind.VEC3
    elif T == List[Target]:
        return ParamKind.TARGET
    elif T == SubCommand:
        return ParamKind.SUB_COMMAND
    elif conforms_to(T, Enum):
        return ParamKind.ENUM
    else:
        return ParamKind.PARAMETER


def _type_name[T: AnyType](name: StringSlice) -> String:
    """Go `typeNameOf`: the readable type of a (non-optional) parameter."""
    comptime kind = _kind[T]()
    comptime if kind == ParamKind.INT:
        return "int"
    elif kind == ParamKind.UINT:
        return "uint"
    elif kind == ParamKind.FLOAT:
        return "float"
    elif kind == ParamKind.STRING:
        return "string"
    elif kind == ParamKind.VARARGS:
        return "text"
    elif kind == ParamKind.BOOL:
        return "bool"
    elif kind == ParamKind.VEC3:
        return "x y z"
    elif kind == ParamKind.TARGET:
        return "target"
    elif kind == ParamKind.SUB_COMMAND:
        return String(name)
    elif conforms_to(T, Parameter):
        return downcast[T, Parameter]().type()
    elif conforms_to(T, Enum):
        return downcast[T, Enum]().type()
    else:
        return "value"


def _options[T: AnyType, S: Source](src: S) -> List[String]:
    """The enum options of a parameter type for a source."""
    comptime if conforms_to(T, Enum):
        return downcast[T, Enum]().options(src)
    else:
        return List[String]()


def _field_info[
    T: AnyType, S: Source
](name: StringSlice, suffix: StringSlice, optional: Bool, src: S) -> ParamInfo:
    """Describes one parameter field of type `T` (unwrapped)."""
    return ParamInfo(
        String(name),
        _kind[T](),
        _type_name[T](name),
        _options[T](src),
        optional,
        String(suffix),
    )


def _verify[R: Runnable]():
    """Go `verifySignature`, at compile time: optional parameters only at
    the end."""
    comptime Rf = reflect[R]
    comptime types = Rf.field_types()
    comptime for i in range(Rf.field_count()):
        comptime if _exported[R, i]():
            comptime if not _is_optional[types[i]]():
                comptime for j in range(i):
                    comptime if _exported[R, j]():
                        comptime assert not _is_optional[types[j]](), (
                            "command must only have optional parameters at"
                            " the end"
                        )


def _usage[R: Runnable](command_name: String) -> String:
    """Go `parseUsage`: `/name <param: type> [optional: type]suffix ...`."""
    comptime Rf = reflect[R]
    comptime types = Rf.field_types()
    comptime names = Rf.field_names()
    var out = "/" + command_name
    comptime for i in range(Rf.field_count()):
        comptime if _exported[R, i]():
            comptime T = types[i]
            comptime name = _param_name[R, i]()
            comptime suffix = _tag_suffix(R.tag(names[i]))
            var type_name: String
            comptime if _is_optional[T]():
                type_name = _type_name[downcast[T, _OptionalT].Inner](name)
            else:
                type_name = _type_name[T](name)
            out += " "
            comptime if T == SubCommand:
                out += type_name
            elif _is_optional[T]():
                out += "[" + String(name) + ": " + type_name + "]" + suffix
            else:
                out += "<" + String(name) + ": " + type_name + ">" + suffix
    return out^


def _params[R: Runnable, S: Source](src: S) -> List[ParamInfo]:
    """The parameters of `R` for a source (one entry of Go's `Params`)."""
    comptime if conforms_to(R, ParamDescriber):
        var r = R()
        var out = rebind[downcast[R, ParamDescriber]](r).describe_params(src)
        _ = r^
        return out^
    else:
        comptime Rf = reflect[R]
        comptime types = Rf.field_types()
        comptime names = Rf.field_names()
        var out = List[ParamInfo]()
        comptime for i in range(Rf.field_count()):
            comptime if _exported[R, i]():
                comptime T = types[i]
                comptime name = _param_name[R, i]()
                comptime suffix = _tag_suffix(R.tag(names[i]))
                comptime if _is_optional[T]():
                    out.append(
                        _field_info[downcast[T, _OptionalT].Inner](
                            name, suffix, True, src
                        )
                    )
                else:
                    out.append(_field_info[T](name, suffix, False, src))
        return out^


def _allow[R: Runnable, S: Source](src: S) -> Bool:
    """Go: `r.(Allower).Allow(src)`, or True if `R` is not an `Allower`."""
    comptime if conforms_to(R, Allower):
        var r = R()
        var ok = rebind[downcast[R, Allower]](r).allow(src)
        _ = r^
        return ok
    else:
        return True


struct _Attempt(Movable):
    """The result of trying one overload (Go: the `(*Line, error)` of
    `executeRunnable`)."""

    var ok: Bool
    """The overload ran."""
    var has_line: Bool
    """Parsing started (Go: the line is not nil)."""
    var line: Line
    """The line where parsing stopped."""
    var err: Message
    """Why the overload did not run."""

    def __init__(out self):
        self.ok = True
        self.has_line = False
        self.line = Line()
        self.err = Message()

    def __init__(out self, var err: Message):
        self.ok = False
        self.has_line = False
        self.line = Line()
        self.err = err^

    def __init__(out self, var line: Line, var err: Message):
        self.ok = False
        self.has_line = True
        self.line = line^
        self.err = err^


def _execute_runnable[
    R: Runnable, S: Source
](
    name: String,
    usage: String,
    args: String,
    mut src: S,
    mut o: Output,
    mut tx: S.Tx,
) -> _Attempt:
    """Go `Command.executeRunnable`: parses `args` into a fresh `R` and runs
    it."""
    var r = R()
    comptime if conforms_to(R, Allower):
        if not rebind[downcast[R, Allower]](r).allow(src):
            return _Attempt(MESSAGE_UNKNOWN.f(name))
    var frags = List[String]()
    if args.byte_length() > 0:
        var record = split_args(args)
        if not record:
            return _Attempt(MESSAGE_USAGE.f(usage))
        frags = record.take()
    var line = Line(frags^, ["/" + name], usage.copy())

    comptime Rf = reflect[R]
    comptime types = Rf.field_types()
    comptime for i in range(Rf.field_count()):
        comptime if _exported[R, i]():
            comptime T = types[i]
            comptime pname = _param_name[R, i]()
            try:
                comptime if _is_optional[T]():
                    comptime D = downcast[T, _OptionalT]
                    var val = D.Inner()
                    if _parse_argument(line, val, True, pname, src, tx):
                        rebind[D](Rf.field_ref[i](r))._with(val^)
                else:
                    _ = _parse_argument(
                        line, Rf.field_ref[i](r), False, pname, src, tx
                    )
            except e:
                return _Attempt(line^, e^)
    if line.len() != 0:
        var err = line.usage_error()
        return _Attempt(line^, err^)
    r.run(src, o, tx)
    return _Attempt()


struct _Overload[S: Source](ImplicitlyCopyable):
    """One runnable type of a command, erased to function pointers (Go: a
    `reflect.Value` of the runnable)."""

    comptime ExecuteFn = def(
        String, String, String, mut Self.S, mut Output, mut Self.S.Tx
    ) thin -> _Attempt
    comptime AllowFn = def(Self.S) thin -> Bool
    comptime ParamsFn = def(Self.S) thin -> List[ParamInfo]

    var execute: Self.ExecuteFn
    var allow: Self.AllowFn
    var params: Self.ParamsFn

    def __init__(
        out self,
        execute: Self.ExecuteFn,
        allow: Self.AllowFn,
        params: Self.ParamsFn,
    ):
        self.execute = execute
        self.allow = allow
        self.params = params


struct Command[S: Source](Copyable):
    """A named command with one or more runnable overloads (Go
    `cmd.Command`). Create one with `new`."""

    var _v: List[_Overload[Self.S]]
    var _name: String
    var _description: String
    var _usage: String
    var _aliases: List[String]

    def __init__(
        out self,
        var name: String,
        var description: String,
        var aliases: List[String],
    ):
        """Creates a command without overloads; `new` adds them."""
        self._v = List[_Overload[Self.S]]()
        self._name = name^
        self._description = description^
        self._usage = String()
        self._aliases = aliases^

    def name(self) -> String:
        """Gets the name: lower case, used to run the command and shown in
        `/help` (Go `Name`)."""
        return self._name

    def description(self) -> String:
        """Gets the description shown in `/help` (Go `Description`)."""
        return self._description

    def usage(self) -> String:
        """Gets the usage, one line per overload (Go `Usage`)."""
        return self._usage

    def aliases(self) -> List[String]:
        """Gets the aliases, lower case; when there are any, the name is
        among them (Go `Aliases`)."""
        return self._aliases.copy()

    def execute(self, args: String, mut source: Self.S, mut tx: Self.S.Tx):
        """Parses `args` (the line after the command name) and runs the
        first overload that accepts them (Go `Execute`).

        If none does, the error of the overload that got furthest is
        reported, preceded by a syntax error pointing at the argument where
        it stopped. Either way the output is sent to the source.
        """
        var output = Output()
        var least_erroneous = Optional[Message]()
        var least_args_left = Optional[Line]()
        for i in range(len(self._v)):
            var attempt = self._v[i].execute(
                self._name, self._usage, args, source, output, tx
            )
            if attempt.ok:
                source.send_command_output(output)
                return
            if not attempt.has_line:
                if not least_erroneous:
                    least_erroneous = attempt.err.copy()
                continue
            if (
                not least_args_left
                or attempt.line.len() <= least_args_left.value().len()
            ):
                least_erroneous = attempt.err.copy()
                least_args_left = attempt.line.copy()
        if least_args_left:
            output.error(least_args_left.value().syntax_error())
        # Go adds `<nil>` when the command has no overloads at all.
        if least_erroneous:
            output.error(least_erroneous.value())
        source.send_command_output(output)

    def params(self, src: Self.S) -> List[List[ParamInfo]]:
        """Describes the parameters of every overload the source may run
        (Go `Params`)."""
        var out = List[List[ParamInfo]]()
        for i in range(len(self._v)):
            if not self._v[i].allow(src):
                continue
            out.append(self._v[i].params(src))
        return out^

    def runnables(self, src: Self.S) -> List[Int]:
        """Lists the overloads the source may run (Go `Runnables`, which
        maps their indices to the runnables)."""
        var out = List[Int]()
        for i in range(len(self._v)):
            if self._v[i].allow(src):
                out.append(i)
        return out^

    def _add[R: Runnable](mut self):
        _verify[R]()
        if len(self._v) > 0:
            self._usage += "\n"
        self._usage += _usage[R](self._name)
        self._v.append(
            _Overload[Self.S](
                _execute_runnable[R, Self.S],
                _allow[R, Self.S],
                _params[R, Self.S],
            )
        )


def new[
    S: Source, *Rs: Runnable
](name: String, description: String, aliases: List[String]) -> Command[S]:
    """Creates a command from runnable types (Go `cmd.New`).

    The name and aliases are lowered; if there are aliases, the name is
    added to them. Each type in `Rs` is an overload, tried in order. A
    runnable with a non-optional parameter after an optional one, or with
    a field type that is not a parameter type, does not compile (Go
    panics).

    ```mojo
    var c = cmd.new[MySource, TeleportToPos, TeleportToTarget](
        "tp", "Teleports entities.", ["teleport"]
    )
    ```
    """
    var lower_name = name.lower()
    var lowered = List[String](capacity=len(aliases) + 1)
    var has_name = False
    for a in aliases:
        var l = a.lower()
        if l == lower_name:
            has_name = True
        lowered.append(l^)
    if len(lowered) > 0 and not has_name:
        lowered.append(lower_name)
    var c = Command[S](lower_name, description.copy(), lowered^)
    comptime for i in range(len(Rs)):
        c._add[Rs[i]]()
    return c^
