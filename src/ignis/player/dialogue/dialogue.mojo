"""Dialogues, ported from Dragonfly `server/player/dialogue/dialogue.go`.

Go builds a dialogue's buttons from a struct through reflection; here
`std.reflection` walks it at compile time, and a field that is not a
`Button`, or more than six buttons in the struct, is a compile error.
`with_buttons` raises past six buttons (Go panics). `AnyDialogue[S]` owns
a dialogue of any submittable type, as `form.Form[S]` does for forms.
"""

from std.memory import Layout, alloc
from std.builtin.rebind import downcast
from std.reflection import reflect

from .button import Button
from .display import DisplaySettings
from .submit import Closer, Submittable, Submitter


def _format(s: String) -> String:
    if s.endswith("\n"):
        return String(s[byte = : s.byte_length() - 1])
    return s


def _exported[R: AnyType, i: Int]() -> Bool:
    return not reflect[R].field_names()[i].startswith("_")


def _field_buttons[R: AnyType]() -> Int:
    var n = 0
    comptime for i in range(reflect[R].field_count()):
        comptime if _exported[R, i]():
            n += 1
    return n


struct Dialogue[R: Submittable](Movable):
    """An NPC dialogue: a title, a body and up to six buttons (Go
    `dialogue.Dialogue`)."""

    var _title: String
    var _body: String
    var _submittable: Self.R
    var _buttons: List[Button]
    var _display: DisplaySettings

    def __init__(out self, var submittable: Self.R, title: String):
        """Creates a dialogue (Go `New`)."""
        comptime Rf = reflect[Self.R]
        comptime types = Rf.field_types()
        comptime for i in range(Rf.field_count()):
            comptime if _exported[Self.R, i]():
                comptime assert (
                    types[i] == Button
                ), "all exported fields must be of the type dialogue.Button"
        comptime assert (
            _field_buttons[Self.R]() <= 6
        ), "maximum of 6 buttons allowed"
        self._title = _format(title)
        self._body = String()
        self._submittable = submittable^
        self._buttons = List[Button]()
        self._display = DisplaySettings()

    def _clone(self) -> Self:
        var d = Self(self._submittable.copy(), String())
        d._title = self._title
        d._body = self._body
        d._buttons = self._buttons.copy()
        d._display = self._display.copy()
        return d^

    def with_body(self, body: String) -> Self:
        """Returns a copy with the body set (Go `WithBody`)."""
        var d = self._clone()
        d._body = _format(body)
        return d^

    def with_display(self, display: DisplaySettings) -> Self:
        """Returns a copy with display settings (Go `WithDisplay`)."""
        var d = self._clone()
        d._display = display.copy()
        return d^

    def with_buttons(self, buttons: List[Button]) raises -> Self:
        """Returns a copy with buttons appended (Go `WithButtons`)."""
        var d = self._clone()
        d._buttons.extend(buttons.copy())
        if _field_buttons[Self.R]() + len(d._buttons) > 6:
            raise Error("maximum of 6 buttons allowed")
        return d^

    def title(self) -> String:
        """Returns the title, shown as the NPC's name (Go `Title`)."""
        return self._title

    def body(self) -> String:
        """Returns the body (Go `Body`)."""
        return self._body

    def display(self) -> DisplaySettings:
        """Returns the display settings (Go `Display`)."""
        return self._display.copy()

    def buttons(self) -> List[Button]:
        """Returns the struct's buttons, then those added (Go `Buttons`)."""
        var out = List[Button]()
        comptime Rf = reflect[Self.R]
        comptime for i in range(Rf.field_count()):
            comptime if _exported[Self.R, i]():
                out.append(
                    rebind[Button](Rf.field_ref[i](self._submittable)).copy()
                )
        out.extend(self._buttons.copy())
        return out^

    def marshal_json(self) -> String:
        """Returns the buttons' JSON array (Go `MarshalJSON`)."""
        var out = String("[")
        var b = self.buttons()
        for i in range(len(b)):
            if i > 0:
                out += ","
            out += b[i].marshal_json()
        out += "]"
        return out^

    def submit[
        S: Submitter
    ](self, index: UInt, mut submitter: S, mut tx: S.Tx) raises:
        """Submits the button at an index (Go `Submit`)."""
        var b = self.buttons()
        if index >= UInt(len(b)):
            raise Error(
                t"button index points to inexistent button: {index} (only"
                t" {len(b)} buttons present)"
            )
        var r = self._submittable.copy()
        r.submit(submitter, b[Int(index)], tx)

    def close[S: Submitter](self, mut submitter: S, mut tx: S.Tx):
        """Calls the submittable's `close` if it has one (Go `Close`)."""
        comptime if conforms_to(Self.R, Closer):
            var r = self._submittable.copy()
            rebind[downcast[Self.R, Closer]](r).close(submitter, tx)


def new[R: Submittable](var submittable: R, title: String) -> Dialogue[R]:
    """Creates a dialogue (Go `dialogue.New`)."""
    return Dialogue[R](submittable^, title)


comptime _Ptr = Pointer[UInt8, MutUntrackedOrigin]


def _drop[R: Submittable](p: _Ptr):
    var q = p.unsafe_bitcast[Dialogue[R]]()
    _ = q.unsafe_take_pointee()
    q.unsafe_free()


def _submit[
    R: Submittable, S: Submitter
](p: _Ptr, index: UInt, mut submitter: S, mut tx: S.Tx) raises:
    p.unsafe_bitcast[Dialogue[R]]()[].submit(index, submitter, tx)


def _close[
    R: Submittable, S: Submitter
](p: _Ptr, mut submitter: S, mut tx: S.Tx):
    p.unsafe_bitcast[Dialogue[R]]()[].close(submitter, tx)


struct AnyDialogue[S: Submitter](Movable):
    """A dialogue of any submittable type, owned (Go's `dialogue.Dialogue`
    held by the session)."""

    var _p: _Ptr
    var _drop: def(_Ptr) thin -> None
    var _submit: def(_Ptr, UInt, mut Self.S, mut Self.S.Tx) thin raises -> None
    var _close: def(_Ptr, mut Self.S, mut Self.S.Tx) thin -> None

    def __init__[R: Submittable](out self, var d: Dialogue[R]):
        """Takes ownership of a dialogue."""
        var a = alloc(Layout[Dialogue[R]](count=1))
        var p = rebind[Pointer[Dialogue[R], MutUntrackedOrigin]](a.unsafe_ptr())
        p.unsafe_write(d^)
        _ = a^.unsafe_leak()
        self._p = p.unsafe_bitcast[UInt8]()
        self._drop = _drop[R]
        self._submit = _submit[R, Self.S]
        self._close = _close[R, Self.S]

    def submit(
        self, index: UInt, mut submitter: Self.S, mut tx: Self.S.Tx
    ) raises:
        """Submits the button at an index."""
        self._submit(self._p, index, submitter, tx)

    def close(self, mut submitter: Self.S, mut tx: Self.S.Tx):
        """Closes the dialogue."""
        self._close(self._p, submitter, tx)

    def __deinit__(deinit self):
        self._drop(self._p)
