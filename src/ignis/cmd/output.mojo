"""Command output: success messages and errors (Dragonfly
`server/cmd/output.go`).

Go stores `[]error` and `[]fmt.Stringer` and lets the session check whether
each value is a translation. Ignis stores `Message` values that carry both
forms: the fallback text (Go's `String()`/`Error()`) and, for translations,
the resolved translation string and its parameters (Go's `Resolve` and
`Params`), which is what the session puts in a `CommandOutputMessage`.

The `MESSAGE_*` translations are Dragonfly's, with `text.Colourf` already
applied to their format strings; `interop/cmd` checks every one of them
against Dragonfly's output.
"""


struct Message(Copyable, Defaultable, Equatable, Writable):
    """A message or error added to an `Output`: plain text, or a translation
    with parameters."""

    var text: String
    """The text as Go's `String()`/`Error()` formats it: for a translation,
    the coloured fallback with the parameters filled in."""
    var translated: Bool
    """Whether this is a translation the client resolves itself."""
    var translation: String
    """The resolved translation string (Go `Resolve`), such as
    `§r§c%commands.generic.usage§r`; empty for plain text."""
    var params: List[String]
    """The translation parameters (Go `Params`); empty for plain text."""

    def __init__(out self):
        """Creates an empty plain message."""
        self.text = String()
        self.translated = False
        self.translation = String()
        self.params = List[String]()

    @implicit
    def __init__(out self, var text: String):
        """Creates a plain text message.

        Args:
            text: The text.
        """
        self.text = text^
        self.translated = False
        self.translation = String()
        self.params = List[String]()

    def __init__(
        out self,
        *,
        var text: String,
        var translation: String,
        var params: List[String],
    ):
        """Creates a translated message.

        Args:
            text: The fallback text with the parameters filled in.
            translation: The resolved translation string.
            params: The translation parameters.
        """
        self.text = text^
        self.translated = True
        self.translation = translation^
        self.params = params^

    def __eq__(self, other: Self) -> Bool:
        """Compares every field.

        Args:
            other: The other message.

        Returns:
            True if both messages are identical.
        """
        return (
            self.text == other.text
            and self.translated == other.translated
            and self.translation == other.translation
            and self.params == other.params
        )

    def write_to(self, mut writer: Some[Writer]):
        """Writes the text, as Go's `String()`.

        Args:
            writer: The destination.
        """
        writer.write(self.text)


@fieldwise_init
struct Translation(ImplicitlyCopyable):
    """A translation with a fixed number of parameters (the part of
    Dragonfly's `chat.Translation` that commands use).

    `resolved` and `fallback` are Go's `text.Colourf(format, key)` and
    `text.Colourf(format, fallback)`; `%v` in the fallback marks where the
    parameters go.
    """

    var resolved: StaticString
    """The coloured translation key."""
    var params: Int
    """How many parameters `f` takes."""
    var fallback: StaticString
    """The coloured fallback text with one `%v` per parameter."""

    def f(self, *args: String) -> Message:
        """Fills in the parameters (Go `Translation.F`).

        Go panics on a wrong number of parameters; that is a programming
        error here too and aborts in debug builds.

        Args:
            args: Exactly `params` parameters.

        Returns:
            The translated message.
        """
        var params = List[String](capacity=len(args))
        for a in args:
            params.append(a)
        return _translate(self, params^)


def _sprintf_v(format: StringSlice, params: List[String]) -> String:
    """Replaces each `%v` in `format` with the next parameter, as Go's
    `fmt.Sprintf` does for the formats used here.

    Args:
        format: The format with `%v` verbs.
        params: The values, in order.

    Returns:
        The formatted string.
    """
    var out = String()
    var bytes = format.as_bytes()
    var start = 0
    var next = 0
    var i = 0
    while i + 1 < len(bytes):
        if bytes[i] == UInt8(ord("%")) and bytes[i + 1] == UInt8(ord("v")):
            out += String(format[byte=start:i])
            if next < len(params):
                out += params[next]
            else:
                out += "%!v(MISSING)"
            next += 1
            i += 2
            start = i
            continue
        i += 1
    out += String(format[byte=start:])
    return out^


comptime MESSAGE_SYNTAX = Translation(
    "§r§c%commands.generic.syntax§r",
    3,
    '§r§cSyntax error: unexpected value: at "%v>>%v<<%v"§r',
)
"""`commands.generic.syntax`: the parsed part, the bad argument and the
rest of the line."""
comptime MESSAGE_USAGE = Translation(
    "§r§c%commands.generic.usage§r", 1, "§r§cUsage: %v§r"
)
"""`commands.generic.usage`: the command usage."""
comptime MESSAGE_UNKNOWN = Translation(
    "§r§c%commands.generic.unknown§r",
    1,
    (
        '§r§cUnknown command: "%v": Please check that the command exists'
        " and that you have permission to use it.§r"
    ),
)
"""`commands.generic.unknown`: the command name."""
comptime MESSAGE_NO_TARGETS = Translation(
    "§r§c%commands.generic.noTargetMatch§r",
    0,
    "§r§cNo targets matched selector§r",
)
"""`commands.generic.noTargetMatch`."""
comptime MESSAGE_NUMBER_INVALID = Translation(
    "§r§c> %commands.generic.num.invalid§r",
    1,
    "§r§c> '%v' is not a valid number§r",
)
"""`commands.generic.num.invalid`: the argument."""
comptime MESSAGE_BOOLEAN_INVALID = Translation(
    "§r§c> %commands.generic.boolean.invalid§r",
    1,
    "§r§c> '%v' is not true or false§r",
)
"""`commands.generic.boolean.invalid`: the argument."""
comptime MESSAGE_PLAYER_NOT_FOUND = Translation(
    "§r§c> %commands.generic.player.notFound§r",
    0,
    "§r§c> That player cannot be found§r",
)
"""`commands.generic.player.notFound`."""
comptime MESSAGE_PARAMETER_INVALID = Translation(
    "§r§c> %commands.generic.parameter.invalid§r",
    1,
    "§r§c> '%v' is not a valid parameter§r",
)
"""`commands.generic.parameter.invalid`: the argument."""


struct Output(Copyable, Defaultable):
    """The output of a command execution: success messages and errors, sent
    to the source afterwards (Go `cmd.Output`)."""

    var _errors: List[Message]
    var _messages: List[Message]

    def __init__(out self):
        """Creates an empty output."""
        self._errors = List[Message]()
        self._messages = List[Message]()

    def error[W: Writable](mut self, value: W):
        """Adds an error (Go `Error` and `Errorf`).

        A `Message` is added as it is, keeping its translation; any other
        value is formatted as plain text, so t-strings work:
        `o.error(t"{n} is too big")`.

        Parameters:
            W: The value type.

        Args:
            value: The error.
        """
        self._errors.append(_message(value))

    def errort(mut self, t: Translation, *args: String):
        """Adds a translated error (Go `Errort`).

        Args:
            t: The translation.
            args: Its parameters.
        """
        var params = List[String](capacity=len(args))
        for a in args:
            params.append(a)
        self._errors.append(_translate(t, params^))

    def print[W: Writable](mut self, value: W):
        """Adds a success message (Go `Print` and `Printf`).

        Parameters:
            W: The value type.

        Args:
            value: The message; a `Message` keeps its translation.
        """
        self._messages.append(_message(value))

    def printt(mut self, t: Translation, *args: String):
        """Adds a translated success message (Go `Printt`).

        Args:
            t: The translation.
            args: Its parameters.
        """
        var params = List[String](capacity=len(args))
        for a in args:
            params.append(a)
        self._messages.append(_translate(t, params^))

    def errors(self) -> ref[self._errors] List[Message]:
        """Gets the errors (Go `Errors`).

        Returns:
            Every error, in the order added.
        """
        return self._errors

    def error_count(self) -> Int:
        """Counts the errors (Go `ErrorCount`).

        Returns:
            The number of errors.
        """
        return len(self._errors)

    def messages(self) -> ref[self._messages] List[Message]:
        """Gets the success messages (Go `Messages`).

        Returns:
            Every message, in the order added.
        """
        return self._messages

    def message_count(self) -> Int:
        """Counts the success messages (Go `MessageCount`).

        Returns:
            The number of messages.
        """
        return len(self._messages)


def _message[W: Writable](value: W) -> Message:
    """Converts a value to a `Message`, keeping a `Message` as it is.

    Parameters:
        W: The value type.

    Args:
        value: The value.

    Returns:
        The message.
    """
    comptime if W == Message:
        return rebind[Message](value).copy()
    else:
        return Message(String(value))


def _translate(t: Translation, var params: List[String]) -> Message:
    """Fills in a translation from a list of parameters.

    Args:
        t: The translation.
        params: Its parameters.

    Returns:
        The translated message.
    """
    debug_assert(len(params) == t.params, "wrong translation arity")
    return Message(
        text=_sprintf_v(t.fallback, params),
        translation=String(t.resolved),
        params=params^,
    )
