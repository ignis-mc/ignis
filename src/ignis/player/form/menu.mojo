"""Menu forms, ported from Dragonfly `server/player/form/menu.go`."""

from std.builtin.rebind import downcast
from std.reflection import reflect

from ...internal.gojson import JsonObject
from ...internal.json import JsonDoc
from .element import Button, Divider, Header, Label, MenuElement
from .form import FormType, _exported, format
from .number import parse_uint_response
from .submit import Closer, MenuSubmittable, Submitter


@fieldwise_init
struct MenuItem(Copyable):
    """An element added to a menu after creation (one of Go's
    `[]MenuElement`)."""

    var kind: Int
    """0 button, 1 divider, 2 header, 3 label."""
    var text: String
    var image: String

    def marshal_json(self) -> String:
        """Returns the element's JSON."""
        if self.kind == 0:
            return Button(self.text, self.image).marshal_json()
        if self.kind == 1:
            return Divider().marshal_json()
        if self.kind == 2:
            return Header(self.text).marshal_json()
        return Label(self.text).marshal_json()


struct Menu[R: MenuSubmittable](FormType):
    """A form with a body and buttons, dividers, headers and labels below
    it (Go `form.Menu`)."""

    var _title: String
    var _body: String
    var _submittable: Self.R
    var _elements: List[MenuItem]

    def __init__(out self, var submittable: Self.R, title: String):
        """Creates a menu (Go `NewMenu`)."""
        comptime Rf = reflect[Self.R]
        comptime types = Rf.field_types()
        comptime for i in range(Rf.field_count()):
            comptime if _exported[Self.R, i]():
                comptime assert conforms_to(
                    types[i], MenuElement
                ), "all exported fields must implement form.MenuElement"
        self._title = format(title)
        self._body = String()
        self._submittable = submittable^
        self._elements = List[MenuItem]()

    def with_body(self, body: String) -> Self:
        """Returns a copy with the body set (Go `WithBody`)."""
        var m = self._clone()
        m._body = format(body)
        return m^

    def add_button(self, b: Button) -> Self:
        """Returns a copy with a button appended (Go `AddButton`)."""
        var m = self._clone()
        m._elements.append(MenuItem(0, b.text, b.image))
        return m^

    def add_divider(self) -> Self:
        """Returns a copy with a divider appended (Go `AddDivider`)."""
        var m = self._clone()
        m._elements.append(MenuItem(1, String(), String()))
        return m^

    def add_header(self, h: Header) -> Self:
        """Returns a copy with a header appended (Go `AddHeader`)."""
        var m = self._clone()
        m._elements.append(MenuItem(2, h.text, String()))
        return m^

    def add_label(self, l: Label) -> Self:
        """Returns a copy with a label appended (Go `AddLabel`)."""
        var m = self._clone()
        m._elements.append(MenuItem(3, l.text, String()))
        return m^

    def with_buttons(self, buttons: List[Button]) -> Self:
        """Returns a copy with buttons appended (Go `WithButtons`)."""
        var m = self._clone()
        for b in buttons:
            m._elements.append(MenuItem(0, b.text, b.image))
        return m^

    def _clone(self) -> Self:
        var m = Self(self._submittable.copy(), String())
        m._title = self._title
        m._body = self._body
        m._elements = self._elements.copy()
        return m^

    def title(self) -> String:
        """Returns the title (Go `Title`)."""
        return self._title

    def body(self) -> String:
        """Returns the body (Go `Body`)."""
        return self._body

    def buttons(self) -> List[Button]:
        """Returns the buttons of the struct's fields, then the buttons
        added (Go `Buttons`)."""
        var out = List[Button]()
        comptime Rf = reflect[Self.R]
        comptime types = Rf.field_types()
        comptime for i in range(Rf.field_count()):
            comptime if _exported[Self.R, i]():
                comptime D = downcast[types[i], MenuElement]
                var b = rebind[D](
                    Rf.field_ref[i](self._submittable)
                ).as_button()
                if b:
                    out.append(b.value().copy())
        for e in self._elements:
            if e.kind == 0:
                out.append(Button(e.text, e.image))
        return out^

    def marshal_json(self) -> String:
        """Returns the menu's JSON (Go `MarshalJSON`)."""
        var els = String("[")
        var n = 0
        comptime Rf = reflect[Self.R]
        comptime types = Rf.field_types()
        comptime for i in range(Rf.field_count()):
            comptime if _exported[Self.R, i]():
                comptime D = downcast[types[i], MenuElement]
                if n > 0:
                    els += ","
                els += rebind[D](
                    Rf.field_ref[i](self._submittable)
                ).marshal_json()
                n += 1
        for e in self._elements:
            if n > 0:
                els += ","
            els += e.marshal_json()
            n += 1
        els += "]"
        var m = JsonObject()
        m.string("type", "form")
        m.string("title", self._title)
        m.string("content", self._body)
        m.raw("elements", els^)
        return m.encode()

    def submit_json[
        S: Submitter
    ](self, data: Optional[String], mut submitter: S, mut tx: S.Tx) raises:
        """Submits the index of the pressed button (Go `SubmitJSON`)."""
        var r = self._submittable.copy()
        if not data:
            comptime if conforms_to(Self.R, Closer):
                rebind[downcast[Self.R, Closer]](r).close(submitter, tx)
            return
        var index = parse_uint_response(data.value())
        var buttons = self.buttons()
        if index >= UInt64(len(buttons)):
            raise Error(
                t"button index points to inexistent button: {index} (only"
                t" {len(buttons)} buttons present)"
            )
        r.submit(submitter, buttons[Int(index)], tx)


def new_menu[R: MenuSubmittable](var submittable: R, title: String) -> Menu[R]:
    """Creates a menu form (Go `form.NewMenu`)."""
    return Menu[R](submittable^, title)
