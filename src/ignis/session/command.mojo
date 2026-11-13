"""Command packets (Dragonfly `server/session/command.go`): the
`AvailableCommands` packet built from the registry and the `CommandOutput`
packet built from a command's output.

Dragonfly iterates the command map in Go's random order, so the order of
the commands, enums, enum values and suffixes in its packet changes from
run to run. Ignis visits the commands sorted by name; `interop/cmd` checks
the bytes against Dragonfly's packet for that order.
"""

from std.collections import Set

from minecraft.protocol.command import (
    COMMAND_ARG_ENUM,
    COMMAND_ARG_SOFT_ENUM,
    COMMAND_ARG_SUFFIXED,
    COMMAND_ARG_TYPE_FLOAT,
    COMMAND_ARG_TYPE_INT,
    COMMAND_ARG_TYPE_POSITION,
    COMMAND_ARG_TYPE_RAW_TEXT,
    COMMAND_ARG_TYPE_R_VALUE,
    COMMAND_ARG_TYPE_STRING,
    COMMAND_ARG_TYPE_TARGET,
    COMMAND_ARG_VALID,
    COMMAND_PERMISSION_LEVEL_ANY,
    Command as ProtocolCommand,
    CommandEnum,
    CommandOrigin,
    CommandOutputMessage,
    CommandOverload,
    CommandParameter,
    DynamicEnum,
)
from minecraft.protocol.packet.available_commands import AvailableCommands
from minecraft.protocol.packet.command_output import (
    COMMAND_OUTPUT_TYPE_ALL_OUTPUT,
    CommandOutput,
)

from ..cmd.command import Command, ParamInfo, ParamKind
from ..cmd.output import Message, Output
from ..cmd.source import Source


def command_output(output: Output, origin: CommandOrigin) -> CommandOutput:
    """Builds the packet that shows a command's output to the player (the
    packet Go's `Session.SendCommandOutput` writes).

    Args:
        output: The command output.
        origin: The origin of the `CommandRequest` being answered.

    Returns:
        The packet: success messages first, then errors.
    """
    var pk = CommandOutput()
    pk.command_origin = origin.copy()
    pk.output_type = COMMAND_OUTPUT_TYPE_ALL_OUTPUT
    pk.success_count = UInt32(output.message_count())
    for m in output.messages():
        pk.output_messages.append(_output_message(m, True))
    for e in output.errors():
        pk.output_messages.append(_output_message(e, False))
    return pk^


def _output_message(m: Message, success: Bool) -> CommandOutputMessage:
    var om = CommandOutputMessage()
    om.success = success
    if m.translated:
        om.message = m.translation
        om.parameters = m.params.copy()
    else:
        om.message = m.text
    return om^


@fieldwise_init
struct _CommandEnum(Copyable):
    """Go `commandEnum`."""

    var type: String
    var options: List[String]


def build_available_commands[
    S: Source
](
    commands: Dict[String, Command[S]],
    src: S,
    soft_enums: Set[String],
    mut runnable: Dict[String, List[Int]],
) -> AvailableCommands:
    """Builds the `AvailableCommands` packet for a source (Go
    `BuildAvailableCommands`).

    Parameters:
        S: The source type.

    Args:
        commands: The commands by alias, as `Registry.commands` returns
            them; each command is added once, under its name.
        src: The source; overloads it may not run are left out.
        soft_enums: The enum types sent as dynamic (soft) enums.
        runnable: Receives, per command name, the overloads the source may
            run (Go's second return value).

    Returns:
        The packet.
    """
    var pk = AvailableCommands()
    var enums = List[_CommandEnum]()
    var enum_indices = Dict[String, UInt32]()
    var dynamic_enums = List[_CommandEnum]()
    var dynamic_enum_indices = Dict[String, UInt32]()
    var suffix_indices = Dict[String, UInt32]()

    var aliases = List[String]()
    for k in commands.keys():
        aliases.append(k)
    sort(aliases)

    for alias in aliases:
        ref c = commands.get(alias).value()
        if c.name() != alias:
            continue
        var run = c.runnables(src)
        if len(run) == 0:
            continue
        runnable[alias] = run^

        var params = c.params(src)
        var overloads = List[CommandOverload](capacity=len(params))
        for _ in range(len(params)):
            overloads.append(CommandOverload())

        var aliases_index = UInt32.MAX
        var cmd_aliases = c.aliases()
        if len(cmd_aliases) > 0:
            # Go uses the size of the index map here, not of `enums`.
            aliases_index = UInt32(len(enum_indices))
            enum_indices[c.name() + "Aliases"] = aliases_index
            enums.append(_CommandEnum(c.name() + "Aliases", cmd_aliases^))

        for i in range(len(params)):
            for ref info in params[i]:
                var e = _CommandEnum(String(), List[String]())
                var t = _value_to_param_type(info, e)
                if info.suffix.byte_length() > 0:
                    var index: UInt32
                    if info.suffix in suffix_indices:
                        index = suffix_indices.get(info.suffix).value()
                    else:
                        index = UInt32(len(pk.suffixes))
                        suffix_indices[info.suffix] = index
                        pk.suffixes.append(info.suffix)
                    t = COMMAND_ARG_SUFFIXED | index
                else:
                    t |= COMMAND_ARG_VALID
                    if len(e.options) > 0 or e.type.byte_length() > 0:
                        if e.type not in soft_enums:
                            var index: UInt32
                            if e.type in enum_indices:
                                index = enum_indices.get(e.type).value()
                            else:
                                index = UInt32(len(enums))
                                enum_indices[e.type] = index
                                enums.append(e.copy())
                            t |= COMMAND_ARG_ENUM | index
                        else:
                            var index: UInt32
                            if e.type in dynamic_enum_indices:
                                index = dynamic_enum_indices.get(e.type).value()
                            else:
                                index = UInt32(len(dynamic_enums))
                                dynamic_enum_indices[e.type] = index
                                dynamic_enums.append(e.copy())
                            t |= COMMAND_ARG_SOFT_ENUM | index
                var p = CommandParameter()
                p.name = info.name
                p.type = t
                p.optional = info.optional
                p.options = 0
                overloads[i].parameters.append(p^)

        var pc = ProtocolCommand()
        pc.name = c.name()
        pc.description = c.description()
        pc.aliases_offset = aliases_index
        pc.permission_level = COMMAND_PERMISSION_LEVEL_ANY
        pc.overloads = overloads^
        pk.commands.append(pc^)

    for e in dynamic_enums:
        var de = DynamicEnum()
        de.type = e.type
        de.values = e.options.copy()
        pk.dynamic_enums.append(de^)

    var enum_value_indices = Dict[String, UInt32]()
    for e in enums:
        var pe = CommandEnum()
        pe.type = e.type
        for opt in e.options:
            var index: UInt32
            if opt in enum_value_indices:
                index = enum_value_indices.get(opt).value()
            else:
                index = UInt32(len(pk.enum_values))
                enum_value_indices[opt] = index
                pk.enum_values.append(opt)
            pe.value_indices.append(index)
        pk.enums.append(pe^)
    return pk^


def _value_to_param_type(info: ParamInfo, mut e: _CommandEnum) -> UInt32:
    """Go `valueToParamType`: the argument type of a parameter; for bools,
    subcommands and enums, `e` receives the enum it uses."""
    if info.kind == ParamKind.INT or info.kind == ParamKind.UINT:
        return COMMAND_ARG_TYPE_INT
    if info.kind == ParamKind.FLOAT:
        return COMMAND_ARG_TYPE_FLOAT
    if info.kind == ParamKind.STRING:
        return COMMAND_ARG_TYPE_STRING
    if info.kind == ParamKind.VARARGS:
        return COMMAND_ARG_TYPE_RAW_TEXT
    if info.kind == ParamKind.TARGET:
        return COMMAND_ARG_TYPE_TARGET
    if info.kind == ParamKind.BOOL:
        e = _CommandEnum("Boolean", ["true", "false"])
        return 0
    if info.kind == ParamKind.VEC3:
        return COMMAND_ARG_TYPE_POSITION
    if info.kind == ParamKind.SUB_COMMAND:
        e = _CommandEnum("SubCommand" + info.name, [info.name])
        return 0
    if info.kind == ParamKind.ENUM:
        e = _CommandEnum(info.type_name, info.options.copy())
        return 0
    return COMMAND_ARG_TYPE_R_VALUE
