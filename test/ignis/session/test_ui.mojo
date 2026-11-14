from ignis.mgl64 import Vec3
from ignis.player import dialogue, form
from ignis.player.bossbar import BossBar, Colour
from ignis.player.chat import message_join
from ignis.player.scoreboard import Scoreboard
from ignis.player.title import Title
from ignis.session.ui import (
    SessionUI,
    announcement_packet,
    boss_bar_packets,
    close_dialogue_packets,
    close_form_packet,
    dialogue_packets,
    form_packet,
    jukebox_popup_packet,
    message_packet,
    popup_packet,
    remove_scoreboard_packets,
    scoreboard_packets,
    tip_packet,
    title_packets,
    toast_packet,
    translation_packet,
)
from minecraft.protocol.entity_metadata import new_entity_metadata
from minecraft.protocol.packet.npc_dialogue import NPCDialogue
from std.testing import TestSuite, assert_equal
from support.ui_vectors import UIVectors
from support.form_support import survey


def _join(pks: List[List[UInt8]]) -> List[UInt8]:
    # The Go program writes each packet with a 2-byte big-endian length.
    var out = List[UInt8]()
    for p in pks:
        out.append(UInt8(len(p) >> 8))
        out.append(UInt8(len(p) & 0xFF))
        out.extend(p.copy())
    return out^


def _check(v: UIVectors, key: String, pks: List[List[UInt8]]) raises:
    var got = _join(pks)
    var want = v.bytes(key)
    if got != want:
        raise Error(t"{key}: got {len(got)} bytes, want {len(want)}")


def test_text_packets_match_dragonfly() raises:
    var v = UIVectors()
    _check(v, "packet.message", [message_packet("hi §aall")])
    _check(
        v,
        "packet.translation",
        [translation_packet(message_join(), "en_US", ["Steve"])],
    )
    _check(
        v,
        "packet.tips",
        [
            tip_packet("tip"),
            popup_packet("popup"),
            jukebox_popup_packet("jukebox"),
            announcement_packet("announce"),
        ],
    )
    _check(v, "packet.toast", [toast_packet("Title", "Message")])


def test_scoreboard_packets_match_dragonfly() raises:
    var v = UIVectors()
    var ui = SessionUI()
    var sb = Scoreboard("Test")
    _ = sb.write_string("a\nb\n")
    _check(v, "packet.scoreboard.1", scoreboard_packets(ui, sb))
    var sb2 = Scoreboard("Test")
    sb2.set(1, "c")
    sb2.set_descending()
    _check(v, "packet.scoreboard.2", scoreboard_packets(ui, sb2))
    var sb3 = Scoreboard("Other")
    _ = sb3.write_string("x")
    sb3.remove_padding()
    _check(v, "packet.scoreboard.3", scoreboard_packets(ui, sb3))
    _check(v, "packet.scoreboard.remove", remove_scoreboard_packets(ui))


def test_boss_bar_and_title_packets_match_dragonfly() raises:
    var v = UIVectors()
    var bar = (
        BossBar("Boss fight")
        .with_health_percentage(0.25)
        .with_colour(Colour.RED)
    )
    _check(
        v,
        "packet.bossbar",
        boss_bar_packets(
            bar.text(), bar.colour().uint8(), bar.health_percentage()
        ),
    )
    var full = (
        Title("Hello")
        .with_subtitle("Sub")
        .with_action_text("Act")
        .with_duration_ms(3000)
        .with_fade_in_duration_ms(1000)
        .with_fade_out_duration_ms(130)
    )
    _check(v, "packet.title.full", title_packets(full))
    _check(
        v,
        "packet.title.action",
        title_packets(Title().with_action_text("only action")),
    )
    _check(
        v, "packet.title.sub", title_packets(Title().with_subtitle("sub only"))
    )


@fieldwise_init
struct Talk(dialogue.Submittable):
    var hello: dialogue.Button
    var bye: dialogue.Button

    def submit[
        S: dialogue.Submitter
    ](mut self, mut submitter: S, pressed: dialogue.Button, mut tx: S.Tx):
        pass


def test_form_and_dialogue_packets_match_dragonfly() raises:
    var v = UIVectors()
    var ui = SessionUI()
    var f = form.new(survey(), "Survey")
    var pks = List[List[UInt8]]()
    pks.append(form_packet(ui, f.marshal_json()))
    pks.append(close_form_packet())
    assert_equal(ui.current_form_id, 1)
    _check(v, "packet.form", pks)
    var d = dialogue.new(
        Talk(dialogue.Button("Hello"), dialogue.Button("Bye")), "NPC"
    ).with_body("Hi")
    var all = dialogue_packets(
        ui,
        5,
        new_entity_metadata(),
        "{}",
        d.title(),
        d.body(),
        d.marshal_json(),
    )
    # Go's vectors hold the NPCDialogue packets, not the entity metadata.
    var dpk = List[List[UInt8]]()
    dpk.append(all[1].copy())
    dpk.extend(close_dialogue_packets(ui))
    _check(v, "packet.dialogue", dpk)
    assert_equal(len(close_dialogue_packets(ui)), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
