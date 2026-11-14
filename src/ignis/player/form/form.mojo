"""Custom forms and the form interface, ported from Dragonfly
`server/player/form/form.go`.

Go builds a custom form from a struct through runtime reflection; here
`std.reflection` walks the fields at compile time, so a field that is not an
`Element` is a compile error rather than a panic. Go's `Form` interface
value becomes `Form[S]`, which owns any form type (`FormType`) behind a heap
box and function pointers generated for it, the way `cmd.Command` holds its
overloads; `S` is the server's submitter type.

Responses arrive as strings decoded with `String(from_utf8_lossy=...)`,
which replaces invalid UTF-8 with U+FFFD as Go's JSON decoder does inside
strings. One difference: a custom form's response must be a single JSON
value, where Go's `Decoder` ignores what follows the first value.
"""

from std.memory import Layout, alloc
from std.builtin.rebind import downcast
from std.reflection import reflect

from ...internal.gojson import JsonObject
from ...internal.json import JSON_ARRAY, JSON_NULL, JsonDoc
from .element import Element
from .submit import Closer, Submittable, Submitter


def format(s: String) -> String:
    """Go `format(a)` for one string: `fmt.Sprintln` without its newline,
    which also drops one newline the text ends with."""
    if s.endswith("\n"):
        return String(s[byte = : s.byte_length() - 1])
    return s


trait FormType(Deinitable, Movable):
    """A form that can be sent: custom, menu or modal (Go `form.Form`)."""

    def marshal_json(self) -> String:
        """Returns the form's JSON (Go `MarshalJSON`)."""
        ...

    def submit_json[
        S: Submitter
    ](self, data: Optional[String], mut submitter: S, mut tx: S.Tx) raises:
        """Submits a response (None if the form was closed), raising if it
        is not valid for the form (Go `SubmitJSON`)."""
        ...


def _exported[R: AnyType, i: Int]() -> Bool:
    return not reflect[R].field_names()[i].startswith("_")


struct Custom[R: Submittable](FormType):
    """A form with fields to fill out (Go `form.Custom`)."""

    var _title: String
    var _submittable: Self.R

    def __init__(out self, var submittable: Self.R, title: String):
        """Creates a custom form (Go `form.New`)."""
        comptime Rf = reflect[Self.R]
        comptime types = Rf.field_types()
        comptime for i in range(Rf.field_count()):
            comptime if _exported[Self.R, i]():
                comptime assert conforms_to(
                    types[i], Element
                ), "all exported fields must implement form.Element"
        self._title = format(title)
        self._submittable = submittable^

    def title(self) -> String:
        """Returns the title (Go `Title`)."""
        return self._title

    def submittable(self) -> ref[self._submittable] Self.R:
        """Returns the submittable the form was created with."""
        return self._submittable

    def elements_json(self) -> List[String]:
        """Returns the JSON of every element field, in order (Go
        `Elements`)."""
        var out = List[String]()
        comptime Rf = reflect[Self.R]
        comptime types = Rf.field_types()
        comptime for i in range(Rf.field_count()):
            comptime if _exported[Self.R, i]():
                comptime D = downcast[types[i], Element]
                out.append(
                    rebind[D](Rf.field_ref[i](self._submittable)).marshal_json()
                )
        return out^

    def marshal_json(self) -> String:
        """Returns the form's JSON (Go `MarshalJSON`)."""
        var m = JsonObject()
        m.string("type", "custom_form")
        m.string("title", self._title)
        var content = String("[")
        var els = self.elements_json()
        for i in range(len(els)):
            if i > 0:
                content += ","
            content += els[i]
        content += "]"
        m.raw("content", content^)
        return m.encode()

    def submit_json[
        S: Submitter
    ](self, data: Optional[String], mut submitter: S, mut tx: S.Tx) raises:
        """Fills the fields out from a JSON array of values and calls
        `submit`, or calls `close` if the form was closed (Go
        `SubmitJSON`)."""
        var r = self._submittable.copy()
        if not data:
            comptime if conforms_to(Self.R, Closer):
                rebind[downcast[Self.R, Closer]](r).close(submitter, tx)
            return
        var doc: JsonDoc
        try:
            doc = JsonDoc(data.value().as_bytes())
        except e:
            raise Error(t"error decoding JSON data to slice: {e}")
        var values = List[Int]()
        if doc.kind(doc.root()) == JSON_ARRAY:
            values = doc.children(doc.root())
        elif doc.kind(doc.root()) != JSON_NULL:
            raise Error(
                "error decoding JSON data to slice: json: cannot unmarshal"
                " into Go value of type []interface {}"
            )
        var next = 0
        comptime Rf = reflect[Self.R]
        comptime types = Rf.field_types()
        comptime for i in range(Rf.field_count()):
            comptime if _exported[Self.R, i]():
                comptime D = downcast[types[i], Element]
                if next >= len(values):
                    raise Error(
                        "form JSON data array does not have enough values"
                    )
                ref field = rebind[D](Rf.field_ref[i](r))
                if not field.readonly():
                    try:
                        field.parse_value(doc, values[next])
                    except e:
                        raise Error(t"error parsing form response value: {e}")
                next += 1
        r.submit(submitter, tx)


def new[R: Submittable](var submittable: R, title: String) -> Custom[R]:
    """Creates a custom form from a submittable struct (Go `form.New`)."""
    return Custom[R](submittable^, title)


comptime _Ptr = Pointer[UInt8, MutUntrackedOrigin]


def _drop[F: FormType](p: _Ptr):
    var q = p.unsafe_bitcast[F]()
    _ = q.unsafe_take_pointee()
    q.unsafe_free()


def _json[F: FormType](p: _Ptr) -> String:
    return p.unsafe_bitcast[F]()[].marshal_json()


def _submit[
    F: FormType, S: Submitter
](p: _Ptr, data: Optional[String], mut submitter: S, mut tx: S.Tx) raises:
    p.unsafe_bitcast[F]()[].submit_json(data, submitter, tx)


struct Form[S: Submitter](Movable):
    """Any form, owned (Go's `form.Form` interface value)."""

    comptime _SubmitFn = def(
        _Ptr, Optional[String], mut Self.S, mut Self.S.Tx
    ) thin raises -> None

    var _p: _Ptr
    var _drop: def(_Ptr) thin -> None
    var _json: def(_Ptr) thin -> String
    var _submit: Self._SubmitFn

    def __init__[F: FormType](out self, var f: F):
        """Takes ownership of a form."""
        var a = alloc(Layout[F](count=1))
        var p = rebind[Pointer[F, MutUntrackedOrigin]](a.unsafe_ptr())
        p.unsafe_write(f^)
        _ = a^.unsafe_leak()
        self._p = p.unsafe_bitcast[UInt8]()
        self._drop = _drop[F]
        self._json = _json[F]
        self._submit = _submit[F, Self.S]

    def marshal_json(self) -> String:
        """Returns the form's JSON."""
        return self._json(self._p)

    def submit_json(
        self, data: Optional[String], mut submitter: Self.S, mut tx: Self.S.Tx
    ) raises:
        """Submits a response (None if the form was closed)."""
        self._submit(self._p, data, submitter, tx)

    def __deinit__(deinit self):
        self._drop(self._p)
