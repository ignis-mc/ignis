"""Modal forms, ported from Dragonfly `server/player/form/modal.go`."""

from std.builtin.rebind import downcast
from std.reflection import reflect

from ...internal.gojson import JsonObject
from .element import Button
from .form import FormType, _exported, format
from .number import parse_bool_response
from .submit import Closer, ModalSubmittable, Submitter


def yes_button() -> Button:
    """Returns the default 'yes' button (Go `YesButton`)."""
    return Button("gui.yes")


def no_button() -> Button:
    """Returns the default 'no' button (Go `NoButton`)."""
    return Button("gui.no")


struct Modal[R: ModalSubmittable](FormType):
    """A form with a body and two buttons (Go `form.Modal`); the struct has
    exactly two `Button` fields."""

    var _title: String
    var _body: String
    var _submittable: Self.R

    def __init__(out self, var submittable: Self.R, title: String):
        """Creates a modal form (Go `NewModal`)."""
        comptime Rf = reflect[Self.R]
        comptime types = Rf.field_types()
        comptime count = _button_count[Self.R]()
        comptime assert count == 2, (
            "modal form must have exactly two exported fields of the type"
            " form.Button"
        )
        comptime for i in range(Rf.field_count()):
            comptime if _exported[Self.R, i]():
                comptime assert (
                    types[i] == Button
                ), "both exported fields must be of the type form.Button"
        self._title = format(title)
        self._body = String()
        self._submittable = submittable^

    def with_body(self, body: String) -> Self:
        """Returns a copy with the body set (Go `WithBody`)."""
        var m = Self(self._submittable.copy(), String())
        m._title = self._title
        m._body = format(body)
        return m^

    def title(self) -> String:
        """Returns the title (Go `Title`)."""
        return self._title

    def body(self) -> String:
        """Returns the body (Go `Body`)."""
        return self._body

    def buttons(self) -> List[Button]:
        """Returns the two buttons (Go `Buttons`)."""
        var out = List[Button]()
        comptime Rf = reflect[Self.R]
        comptime for i in range(Rf.field_count()):
            comptime if _exported[Self.R, i]():
                out.append(
                    rebind[Button](Rf.field_ref[i](self._submittable)).copy()
                )
        return out^

    def marshal_json(self) -> String:
        """Returns the modal's JSON (Go `MarshalJSON`)."""
        var b = self.buttons()
        var m = JsonObject()
        m.string("type", "modal")
        m.string("title", self._title)
        m.string("content", self._body)
        m.string("button1", b[0].text)
        m.string("button2", b[1].text)
        return m.encode()

    def submit_json[
        S: Submitter
    ](self, data: Optional[String], mut submitter: S, mut tx: S.Tx) raises:
        """Submits `true` for the first button, `false` for the second (Go
        `SubmitJSON`)."""
        var r = self._submittable.copy()
        if not data:
            comptime if conforms_to(Self.R, Closer):
                rebind[downcast[Self.R, Closer]](r).close(submitter, tx)
            return
        var value = parse_bool_response(data.value())
        var b = self.buttons()
        r.submit(submitter, b[0 if value else 1], tx)


def _button_count[R: AnyType]() -> Int:
    var n = 0
    comptime for i in range(reflect[R].field_count()):
        comptime if _exported[R, i]():
            n += 1
    return n


def new_modal[
    R: ModalSubmittable
](var submittable: R, title: String) -> Modal[R]:
    """Creates a modal form (Go `form.NewModal`)."""
    return Modal[R](submittable^, title)
