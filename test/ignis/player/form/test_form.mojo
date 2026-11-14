from ignis.internal.gojson import format_float
from ignis.player import form
from std.testing import TestSuite, assert_equal, assert_raises, assert_true
from support.ui_vectors import UIVectors


struct Recorder(form.Submitter):
    comptime Tx = List[String]

    var closed: Int

    def __init__(out self):
        self.closed = 0

    def close_form(mut self):
        self.closed += 1


def _log[T: AnyType](mut tx: T) -> Pointer[List[String], MutUntrackedOrigin]:
    # The tests' Tx is a List[String].
    return rebind[Pointer[List[String], MutUntrackedOrigin]](Pointer(to=tx))


def _b(v: Bool) -> String:
    return "true" if v else "false"


@fieldwise_init
struct Survey(form.Closer, form.Submittable):
    var header: form.Header
    var name: form.Input
    var agree: form.Toggle
    var volume: form.Slider
    var colour: form.Dropdown
    var size: form.StepSlider
    var _note: String

    def submit[S: form.Submitter](mut self, mut submitter: S, mut tx: S.Tx):
        _log(tx)[].append(
            String(
                t"{self.name.value()}|{_b(self.agree.value())}"
                t"|{format_float(self.volume.value())}|{self.colour.value()}"
                t"|{self.size.value()}|{self._note}"
            )
        )

    def close[S: form.Submitter](mut self, mut submitter: S, mut tx: S.Tx):
        _log(tx)[].append("closed")


def survey() -> Survey:
    return Survey(
        form.Header("Questions"),
        form.Input("Name", "Steve", "your name"),
        form.Toggle("Agree", True),
        form.Slider("Volume", 0, 10, 0.5, 2.5),
        form.Dropdown("Colour", ["red", "green"], 1),
        form.StepSlider("Size", ["S", "M", "L"], 0),
        "n",
    )


@fieldwise_init
struct Tooltips(form.Submittable):
    var div: form.Divider
    var label: form.Label
    var name: form.Input
    var agree: form.Toggle
    var volume: form.Slider
    var colour: form.Dropdown
    var size: form.StepSlider

    def submit[S: form.Submitter](mut self, mut submitter: S, mut tx: S.Tx):
        pass


@fieldwise_init
struct Menu(form.Closer, form.MenuSubmittable):
    var profile: form.Button
    var settings: form.Button

    def submit[
        S: form.Submitter
    ](mut self, mut submitter: S, pressed: form.Button, mut tx: S.Tx):
        _log(tx)[].append("pressed " + pressed.text)

    def close[S: form.Submitter](mut self, mut submitter: S, mut tx: S.Tx):
        _log(tx)[].append("closed")


@fieldwise_init
struct Modal(form.ModalSubmittable):
    var yes: form.Button
    var no: form.Button

    def submit[
        S: form.Submitter
    ](mut self, mut submitter: S, pressed: form.Button, mut tx: S.Tx):
        _log(tx)[].append("pressed " + pressed.text)


def _check_submits[
    F: form.FormType
](f: F, v: UIVectors, prefix: String, count: Int) raises:
    var s = Recorder()
    var i = 0
    while v.has(String(t"{prefix}.{i}.in")):
        var raw = v.bytes(String(t"{prefix}.{i}.in"))
        var want = v.str(String(t"{prefix}.{i}.out"))
        var data: Optional[String] = None
        # Responses are turned into strings the way the session does it.
        var text = String(from_utf8_lossy=raw)
        if text != "<nil>":
            data = text
        var log = List[String]()
        var got: String
        try:
            f.submit_json(data, s, log)
            got = String(";").join(log)
        except:
            got = "error"
        if got != want:
            raise Error(t"{prefix}.{i} ({text}): got {got}, want {want}")
        i += 1
    assert_equal(i, count)


def test_custom_forms_match_dragonfly() raises:
    var v = UIVectors()
    var f = form.new(survey(), "Survey\n")
    assert_equal(f.title(), "Survey")
    assert_equal(f.marshal_json(), v.str("form.survey.json"))
    var t = form.new(
        Tooltips(
            form.Divider(),
            form.Label('<b>&"  §aé'),
            form.Input().with_tooltip("tip1"),
            form.Toggle("t", False).with_tooltip("tip2"),
            form.Slider("s", -1.5, 1e21, 1e-7, 0.1).with_tooltip("tip3"),
            form.Dropdown("d", [], 0).with_tooltip("tip4"),
            form.StepSlider("ss", ["<a>"], 0).with_tooltip("tip5"),
        ),
        "Tips and 5",
    )
    assert_equal(t.marshal_json(), v.str("form.tooltips.json"))
    _check_submits(f, v, "form.survey.submit", 25)


def test_menu_and_modal_match_dragonfly() raises:
    var v = UIVectors()
    var m = (
        form.new_menu(
            Menu(
                form.Button("Profile", "textures/ui/icon"),
                form.Button("Settings", "https://example.com/s.png"),
            ),
            "Menu",
        )
        .with_body("Pick one")
        .add_divider()
        .add_header(form.Header("More"))
        .add_label(form.Label("Text"))
        .add_button(form.Button("Extra", "http:x"))
    )
    assert_equal(m.marshal_json(), v.str("form.menu.json"))
    assert_equal(len(m.buttons()), 3)
    _check_submits(m, v, "form.menu.submit", 13)
    var md = form.new_modal(
        Modal(form.yes_button(), form.no_button()), "Modal"
    ).with_body("Sure?\n")
    assert_equal(md.marshal_json(), v.str("form.modal.json"))
    _check_submits(md, v, "form.modal.submit", 8)


def test_form_owns_any_form_type() raises:
    var forms = List[form.Form[Recorder]]()
    forms.append(form.Form[Recorder](form.new(survey(), "Survey")))
    forms.append(
        form.Form[Recorder](
            form.new_modal(Modal(form.yes_button(), form.no_button()), "M")
        )
    )
    var s = Recorder()
    var log = List[String]()
    forms[1].submit_json(String("true"), s, log)
    forms[0].submit_json(None, s, log)
    assert_equal(log[0], "pressed gui.yes")
    assert_equal(log[1], "closed")
    assert_true(forms[0].marshal_json().startswith('{"content":['))
    with assert_raises():
        forms[1].submit_json(String("1"), s, log)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
