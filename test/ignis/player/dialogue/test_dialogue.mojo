from ignis.mgl64 import Vec3
from ignis.player import dialogue
from ignis.session.ui import npc_data
from std.testing import TestSuite, assert_equal, assert_raises
from support.ui_vectors import UIVectors


struct Talker(dialogue.Submitter):
    comptime Tx = List[String]

    var closed: Int

    def __init__(out self):
        self.closed = 0

    def close_dialogue(mut self):
        self.closed += 1


def _log[T: AnyType](mut tx: T) -> Pointer[List[String], MutUntrackedOrigin]:
    return rebind[Pointer[List[String], MutUntrackedOrigin]](Pointer(to=tx))


@fieldwise_init
struct Talk(dialogue.Closer, dialogue.Submittable):
    var hello: dialogue.Button
    var bye: dialogue.Button

    def submit[
        S: dialogue.Submitter
    ](mut self, mut submitter: S, pressed: dialogue.Button, mut tx: S.Tx):
        _log(tx)[].append(pressed.text)

    def close[S: dialogue.Submitter](mut self, mut submitter: S, mut tx: S.Tx):
        _log(tx)[].append("closed")


def test_dialogue_matches_dragonfly() raises:
    var v = UIVectors()
    var d = (
        dialogue.new(
            Talk(dialogue.Button("Hello"), dialogue.Button("<Bye>")), "NPC"
        )
        .with_body("Hi\n")
        .with_buttons([dialogue.Button("Extra")])
    )
    assert_equal(d.marshal_json(), v.str("dialogue.json"))
    assert_equal(d.title(), v.str("dialogue.title"))
    assert_equal(d.body(), v.str("dialogue.body"))
    var disp = dialogue.DisplaySettings(
        Vec3(1.5, 2, 0.5), Vec3(0.1, 1.62, -3), Vec3(10, 45, 0)
    )
    assert_equal(npc_data(disp, Vec3()), v.str("dialogue.display"))
    assert_equal(
        npc_data(dialogue.DisplaySettings(), Vec3()),
        v.str("dialogue.display_zero"),
    )
    with assert_raises():
        _ = d.with_buttons(
            [
                dialogue.Button("a"),
                dialogue.Button("b"),
                dialogue.Button("c"),
                dialogue.Button("d"),
            ]
        )


def test_any_dialogue_submits_and_closes() raises:
    var d = dialogue.AnyDialogue[Talker](
        dialogue.new(Talk(dialogue.Button("Hi"), dialogue.Button("Bye")), "N")
    )
    var t = Talker()
    var log = List[String]()
    d.submit(1, t, log)
    d.close(t, log)
    assert_equal(log[0], "Bye")
    assert_equal(log[1], "closed")
    with assert_raises():
        d.submit(2, t, log)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
