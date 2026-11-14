"""Submittables and a submitter shared by the form and session tests."""

from ignis.internal.gojson import format_float
from ignis.player import form


struct Recorder(form.Submitter):
    """A submitter whose Tx is a log of what was submitted."""

    comptime Tx = List[String]

    var closed: Int

    def __init__(out self):
        self.closed = 0

    def close_form(mut self):
        self.closed += 1


def tx_log[T: AnyType](mut tx: T) -> Pointer[List[String], MutUntrackedOrigin]:
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
        tx_log(tx)[].append(
            String(
                t"{self.name.value()}|{_b(self.agree.value())}"
                t"|{format_float(self.volume.value())}|{self.colour.value()}"
                t"|{self.size.value()}|{self._note}"
            )
        )

    def close[S: form.Submitter](mut self, mut submitter: S, mut tx: S.Tx):
        tx_log(tx)[].append("closed")


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
