"""Checks the player UI end to end: runs `/ui` commands, answers the forms
and the dialogue the server sends, and checks what the server read (it
echoes submitted values in chat) and the scoreboard, boss bar, title and
toast packets.

    mojo run -I src -I third_party/protocol/src -I third_party/nethernet/src \\
        interop/bots/ui_bot.mojo http://127.0.0.1:19190
"""

from minecraft.conn import Conn
from minecraft.dial import Dialer
from minecraft.protocol.packet.boss_event import BOSS_EVENT_SHOW, BossEvent
from minecraft.protocol.packet.command_request import CommandRequest
from minecraft.protocol.packet.id import (
    ID_BOSS_EVENT,
    ID_MODAL_FORM_REQUEST,
    ID_NPC_DIALOGUE,
    ID_SET_DISPLAY_OBJECTIVE,
    ID_SET_SCORE,
    ID_SET_TITLE,
    ID_TEXT,
    ID_TOAST_REQUEST,
)
from minecraft.protocol.packet.modal_form_request import ModalFormRequest
from minecraft.protocol.packet.modal_form_response import ModalFormResponse
from minecraft.protocol.packet.npc_dialogue import (
    NPC_DIALOGUE_ACTION_CLOSE,
    NPC_DIALOGUE_ACTION_OPEN,
    NPCDialogue,
)
from minecraft.protocol.packet.npc_request import (
    NPC_REQUEST_ACTION_EXECUTE_ACTION,
    NPCRequest,
)
from minecraft.protocol.packet.set_display_objective import (
    SetDisplayObjective,
)
from minecraft.protocol.packet.set_score import SetScore
from minecraft.protocol.packet.set_title import (
    TITLE_ACTION_SET_SUBTITLE,
    TITLE_ACTION_SET_TITLE,
    SetTitle,
)
from minecraft.protocol.packet.text import Text
from minecraft.protocol.packet.toast_request import ToastRequest
from minecraft.protocol.packet.packet import PacketData
from nethernet.os.time import monotonic_ms
from std.sys import argv


def check(ok: Bool, name: String) raises:
    """Prints PASS or raises FAIL."""
    if not ok:
        raise Error(t"FAIL {name}")
    print("PASS", name)


def command(mut conn: Conn, line: String) raises:
    var req = CommandRequest()
    req.command_line = line.copy()
    conn.write_packet(req)


def wait_for(mut conn: Conn, id: UInt32, ms: Int = 10000) raises -> PacketData:
    """Reads packets until one with the ID arrives."""
    var deadline = monotonic_ms() + ms
    while monotonic_ms() < deadline:
        var next = conn.read_packet(10)
        if next and next.value().id() == id:
            return next.take()
    raise Error(t"FAIL no packet {id} within {ms} ms")


def wait_text(mut conn: Conn, want: String) raises:
    """Reads packets until a Text holding `want` arrives."""
    var deadline = monotonic_ms() + 10000
    while monotonic_ms() < deadline:
        var next = conn.read_packet(10)
        if next and next.value().id() == ID_TEXT:
            var t = next.value().decode[Text](conn.shield_id, False)
            if want in t.message:
                check(True, String(t"chat says {repr(t.message)}"))
                return
    raise Error(t"FAIL no chat message holding {repr(want)}")


def respond(mut conn: Conn, id: UInt32, data: Optional[String]) raises:
    var pk = ModalFormResponse()
    pk.form_id = id
    if case .Some(d) = data:
        pk.response_data = List[UInt8](d.as_bytes())
    else:
        pk.cancel_reason = UInt8(0)
    conn.write_packet(pk)


def main() raises:
    var args = argv()
    var dialer = Dialer()
    dialer.identity_data.display_name = "UIBot"
    var conn = dialer.dial(String(args[1]))
    print("JOINED")

    # A custom form with every element type, answered.
    command(conn, "/ui form")
    var req = wait_for(conn, ID_MODAL_FORM_REQUEST).decode[ModalFormRequest](
        conn.shield_id, False
    )
    var json = String(from_utf8=Span(req.form_data))
    print("FORM", req.form_id, json)
    check('"type":"custom_form"' in json, "custom form JSON")
    check('"type":"step_slider"' in json, "custom form has a step slider")
    respond(conn, req.form_id, String('[null,null,"Bot",false,7.5,2,0,null]'))
    wait_text(conn, "form: name=Bot agree=false volume=7.5 colour=blue size=S")

    # The same form closed.
    command(conn, "/ui form")
    req = wait_for(conn, ID_MODAL_FORM_REQUEST).decode[ModalFormRequest](
        conn.shield_id, False
    )
    respond(conn, req.form_id, None)
    wait_text(conn, "form: closed")

    # A menu whose button opens a modal.
    command(conn, "/ui menu")
    req = wait_for(conn, ID_MODAL_FORM_REQUEST).decode[ModalFormRequest](
        conn.shield_id, False
    )
    check('"type":"form"' in String(from_utf8=Span(req.form_data)), "menu JSON")
    respond(conn, req.form_id, String("1"))
    wait_text(conn, "menu: pressed Modal")
    req = wait_for(conn, ID_MODAL_FORM_REQUEST).decode[ModalFormRequest](
        conn.shield_id, False
    )
    check(
        '"type":"modal"' in String(from_utf8=Span(req.form_data)), "modal JSON"
    )
    respond(conn, req.form_id, String("true"))
    wait_text(conn, "modal: pressed gui.yes")

    # Scoreboard, boss bar, title and toast.
    command(conn, "/ui scoreboard")
    var obj = wait_for(conn, ID_SET_DISPLAY_OBJECTIVE).decode[
        SetDisplayObjective
    ](conn.shield_id, False)
    check(obj.display_slot == "sidebar", "scoreboard objective on the sidebar")
    var score = wait_for(conn, ID_SET_SCORE).decode[SetScore](
        conn.shield_id, False
    )
    check(len(score.entries) == 4, "scoreboard has 4 lines")
    command(conn, "/ui bossbar")
    var shown = False
    var deadline = monotonic_ms() + 10000
    while not shown and monotonic_ms() < deadline:
        var be = wait_for(conn, ID_BOSS_EVENT).decode[BossEvent](
            conn.shield_id, False
        )
        if be.event_type == BOSS_EVENT_SHOW:
            shown = True
            check(be.health_percentage == 0.6, "boss bar at 60%")
    check(shown, "boss bar shown")
    command(conn, "/ui title")
    var got_title = False
    var got_sub = False
    while not (got_title and got_sub):
        var st = wait_for(conn, ID_SET_TITLE).decode[SetTitle](
            conn.shield_id, False
        )
        if st.action_type == TITLE_ACTION_SET_TITLE:
            got_title = st.text == "§6Ignis"
        elif st.action_type == TITLE_ACTION_SET_SUBTITLE:
            got_sub = True
    check(True, "title and subtitle")
    command(conn, "/ui toast")
    var toast = wait_for(conn, ID_TOAST_REQUEST).decode[ToastRequest](
        conn.shield_id, False
    )
    check(toast.title == "Ignis", "toast")

    # An NPC dialogue on the bot itself, answered with its second button.
    command(conn, "/ui dialogue")
    var d = wait_for(conn, ID_NPC_DIALOGUE).decode[NPCDialogue](
        conn.shield_id, False
    )
    check(d.action_type == NPC_DIALOGUE_ACTION_OPEN, "dialogue opens")
    print("DIALOGUE", d.npc_name, d.action_json)
    var npc = NPCRequest()
    npc.entity_runtime_id = d.entity_unique_id
    npc.request_type = NPC_REQUEST_ACTION_EXECUTE_ACTION
    npc.action_type = 1
    npc.scene_name = "default"
    conn.write_packet(npc)
    wait_text(conn, "dialogue: pressed Bye")
    var closed = wait_for(conn, ID_NPC_DIALOGUE).decode[NPCDialogue](
        conn.shield_id, False
    )
    check(closed.action_type == NPC_DIALOGUE_ACTION_CLOSE, "dialogue closes")
    conn.close()
