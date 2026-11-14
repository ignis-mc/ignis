"""The packets of the player UI, ported from Dragonfly `server/session/text.go`
and the form and dialogue parts of `server/session/player.go`,
`handler_modal_form_response.go` and `handler_npc_request.go`.

`SessionUI` is the state Go keeps on the session for them (the current
scoreboard and its lines, the last form ID, the entity of the open
dialogue). Each function returns the encoded packets in the order Go writes
them; `Session` writes them out. The forms and dialogues themselves are
kept by the server, which owns the submitter type (`server.ui`), so the
session only reports responses (`FormResponse`, `NPCAction`).
"""

from minecraft.protocol.entity_metadata import (
    ENTITY_DATA_KEY_HAS_NPC,
    ENTITY_DATA_KEY_NPC_DATA,
    EntityMetadata,
)
from minecraft.protocol.packet.boss_event import (
    BOSS_EVENT_HIDE,
    BOSS_EVENT_SHOW,
    BossEvent,
)
from minecraft.protocol.packet.client_bound_close_form import (
    ClientBoundCloseForm,
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
    NPC_REQUEST_ACTION_EXECUTE_CLOSING_COMMANDS,
    NPCRequest,
)
from minecraft.protocol.packet.packet import encode_packet
from minecraft.protocol.packet.remove_objective import RemoveObjective
from minecraft.protocol.packet.set_actor_data import SetActorData
from minecraft.protocol.packet.set_display_objective import (
    SCOREBOARD_SORT_ORDER_ASCENDING,
    SCOREBOARD_SORT_ORDER_DESCENDING,
    SetDisplayObjective,
)
from minecraft.protocol.packet.set_score import SetScore
from minecraft.protocol.packet.set_title import (
    TITLE_ACTION_SET_ACTION_BAR,
    TITLE_ACTION_SET_DURATIONS,
    TITLE_ACTION_SET_SUBTITLE,
    TITLE_ACTION_SET_TITLE,
    SetTitle,
)
from minecraft.protocol.packet.text import (
    TEXT_TYPE_ANNOUNCEMENT,
    TEXT_TYPE_JUKEBOX_POPUP,
    TEXT_TYPE_POPUP,
    TEXT_TYPE_RAW,
    TEXT_TYPE_TIP,
    TEXT_TYPE_TRANSLATION,
    Text,
)
from minecraft.protocol.packet.toast_request import ToastRequest
from minecraft.protocol.scoreboard import (
    SCOREBOARD_IDENTITY_FAKE_PLAYER,
    SCOREBOARD_IDENTITY_REMOVE,
    ScoreboardEntry,
)

from ..internal.gojson import JsonObject
from ..mgl64 import Vec3
from ..player.chat import Translation
from ..player.dialogue import DisplaySettings
from ..player.scoreboard import Scoreboard
from ..player.title import Title

comptime SELF_ENTITY_RUNTIME_ID: UInt64 = 1
"""The runtime ID of the session's own player (Go `selfEntityRuntimeID`)."""

comptime TICK_MS = 50
"""Go's `tickLength` in milliseconds."""

comptime MAX_FORMS = 10
"""Above this many open forms Go drops one when sending another."""


@fieldwise_init
struct FormResponse(Copyable):
    """A `ModalFormResponse` as Go's handler reads it: the form ID, and the
    response text, None if the form was closed (no data or empty data)."""

    var id: UInt32
    """The form ID."""
    var data: Optional[String]
    """The response JSON, or None."""
    var has_data: Bool
    """Whether the packet held response data at all (Go `exists`); a
    response to an unknown form is an error only with data."""


def form_response(pk: ModalFormResponse) -> FormResponse:
    """Reads a `ModalFormResponse` (Go `ModalFormResponseHandler.Handle`)."""
    if case .Some(ref b) = pk.response_data:
        if len(b) == 0:
            return FormResponse(pk.form_id, None, True)
        # Lossy decoding replaces invalid UTF-8 with U+FFFD, as Go's JSON
        # decoder does inside strings; outside strings it is a syntax error
        # either way.
        return FormResponse(pk.form_id, String(from_utf8_lossy=b), True)
    return FormResponse(pk.form_id, None, False)


@fieldwise_init
struct NPCAction(Copyable):
    """An `NPCRequest` that acts on the open dialogue: a button (`index`)
    or closing it."""

    var close: Bool
    """Whether the dialogue was closed."""
    var index: UInt
    """The button pressed, if not closed."""


def npc_action(pk: NPCRequest) -> Optional[NPCAction]:
    """Reads an `NPCRequest` (Go `NPCRequestHandler.Handle`)."""
    if pk.request_type == NPC_REQUEST_ACTION_EXECUTE_ACTION:
        return NPCAction(False, UInt(pk.action_type))
    if pk.request_type == NPC_REQUEST_ACTION_EXECUTE_CLOSING_COMMANDS:
        return NPCAction(True, 0)
    return None


struct SessionUI(Defaultable, Movable):
    """The UI state Go keeps on the session."""

    var current_scoreboard: String
    """The name of the scoreboard shown (Go `currentScoreboard`)."""
    var current_lines: List[String]
    """Its lines (Go `currentLines`)."""
    var current_form_id: UInt32
    """The ID of the last form sent (Go `currentID`)."""
    var dialogue_entity: UInt64
    """The runtime ID of the entity of the open dialogue, 0 if none (Go
    `NPCRequestHandler.entityRuntimeID`)."""

    def __init__(out self):
        """Creates the state of a new session."""
        self.current_scoreboard = String()
        self.current_lines = List[String]()
        self.current_form_id = 0
        self.dialogue_entity = 0


def _text(text_type: UInt8, message: String) raises -> List[UInt8]:
    var pk = Text()
    pk.text_type = text_type
    pk.message = message.copy()
    return encode_packet(pk)


def message_packet(message: String) raises -> List[UInt8]:
    """Go `SendMessage`."""
    return _text(TEXT_TYPE_RAW, message)


def tip_packet(message: String) raises -> List[UInt8]:
    """Go `SendTip`."""
    return _text(TEXT_TYPE_TIP, message)


def announcement_packet(message: String) raises -> List[UInt8]:
    """Go `SendAnnouncement`."""
    return _text(TEXT_TYPE_ANNOUNCEMENT, message)


def popup_packet(message: String) raises -> List[UInt8]:
    """Go `SendPopup`."""
    return _text(TEXT_TYPE_POPUP, message)


def jukebox_popup_packet(message: String) raises -> List[UInt8]:
    """Go `SendJukeboxPopup`."""
    return _text(TEXT_TYPE_JUKEBOX_POPUP, message)


def translation_packet(
    t: Translation, locale: String, args: List[String]
) raises -> List[UInt8]:
    """Go `SendTranslation`."""
    var tr = t.f(args.copy())
    var pk = Text()
    pk.text_type = TEXT_TYPE_TRANSLATION
    pk.needs_translation = True
    pk.message = tr.resolve(locale)
    pk.parameters = tr.parameters(locale)
    return encode_packet(pk)


def toast_packet(title: String, message: String) raises -> List[UInt8]:
    """Go `SendToast`."""
    var pk = ToastRequest()
    pk.title = title.copy()
    pk.message = message.copy()
    return encode_packet(pk)


def _colour_code(k: Int) -> String:
    # Go `colours`: the code filled in for empty scoreboard lines.
    var codes = "123456789abcdef"
    return String(codes[byte = k : k + 1])


def remove_scoreboard_packets(mut ui: SessionUI) raises -> List[List[UInt8]]:
    """Go `RemoveScoreboard`."""
    var pk = RemoveObjective()
    pk.objective_name = ui.current_scoreboard.copy()
    ui.current_scoreboard = String()
    ui.current_lines = List[String]()
    return [encode_packet(pk)]


def scoreboard_packets(
    mut ui: SessionUI, sb: Scoreboard
) raises -> List[List[UInt8]]:
    """Go `SendScoreboard`: a new objective if the name changed (removing
    the old one), otherwise the old lines removed; then the lines."""
    var out = List[List[UInt8]]()
    var lines = sb.lines()
    if ui.current_scoreboard != sb.name():
        out.extend(remove_scoreboard_packets(ui))
        var pk = SetDisplayObjective()
        pk.display_slot = "sidebar"
        pk.objective_name = sb.name()
        pk.display_name = sb.name()
        pk.criteria_name = "dummy"
        pk.sort_order = (
            SCOREBOARD_SORT_ORDER_DESCENDING if sb.descending() else SCOREBOARD_SORT_ORDER_ASCENDING
        )
        out.append(encode_packet(pk))
        ui.current_scoreboard = sb.name()
        ui.current_lines = lines.copy()
    else:
        var pk = SetScore()
        for i in range(len(ui.current_lines)):
            var e = ScoreboardEntry()
            e.identity_type = SCOREBOARD_IDENTITY_REMOVE
            e.entry_id = Int64(i)
            e.objective_name = ui.current_scoreboard.copy()
            e.score = Int32(i)
            pk.entries.append(e^)
        if len(pk.entries) > 0:
            out.append(encode_packet(pk))
    var pk = SetScore()
    for k in range(len(lines)):
        var line = lines[k].copy()
        if line.byte_length() == 0:
            line = "§" + _colour_code(k)
        var e = ScoreboardEntry()
        e.entry_id = Int64(k)
        e.objective_name = sb.name()
        e.score = Int32(k)
        e.identity_type = SCOREBOARD_IDENTITY_FAKE_PLAYER
        e.display_name = line^
        pk.entries.append(e^)
    if len(pk.entries) > 0:
        out.append(encode_packet(pk))
    return out^


def remove_boss_bar_packet() raises -> List[UInt8]:
    """Go `RemoveBossBar`."""
    var pk = BossEvent()
    pk.boss_entity_unique_id = Int64(SELF_ENTITY_RUNTIME_ID)
    pk.event_type = BOSS_EVENT_HIDE
    return encode_packet(pk)


def boss_bar_packets(
    text: String, colour: UInt8, health_percentage: Float64
) raises -> List[List[UInt8]]:
    """Go `SendBossBar`: the old bar hidden, the new one shown."""
    var pk = BossEvent()
    pk.boss_entity_unique_id = Int64(SELF_ENTITY_RUNTIME_ID)
    pk.event_type = BOSS_EVENT_SHOW
    pk.boss_bar_title = text.copy()
    pk.health_percentage = Float32(health_percentage)
    pk.colour = colour
    return [remove_boss_bar_packet(), encode_packet(pk)]


def _set_title(action: Int32, text: String) raises -> List[UInt8]:
    var pk = SetTitle()
    pk.action_type = action
    pk.text = text.copy()
    return encode_packet(pk)


def title_durations_packet(
    fade_in_ms: Int, remain_ms: Int, fade_out_ms: Int
) raises -> List[UInt8]:
    """Go `SetTitleDurations`: durations in ticks, rounded down."""
    var pk = SetTitle()
    pk.action_type = TITLE_ACTION_SET_DURATIONS
    pk.fade_in_duration = Int32(fade_in_ms // TICK_MS)
    pk.remain_duration = Int32(remain_ms // TICK_MS)
    pk.fade_out_duration = Int32(fade_out_ms // TICK_MS)
    return encode_packet(pk)


def title_packets(t: Title) raises -> List[List[UInt8]]:
    """Go `Player.SendTitle`: the durations, then the title (and subtitle)
    if either is set, then the action bar text if set."""
    var out = List[List[UInt8]]()
    out.append(
        title_durations_packet(
            t.fade_in_duration_ms(), t.duration_ms(), t.fade_out_duration_ms()
        )
    )
    if t.text().byte_length() > 0 or t.subtitle().byte_length() > 0:
        out.append(_set_title(TITLE_ACTION_SET_TITLE, t.text()))
        if t.subtitle().byte_length() > 0:
            out.append(_set_title(TITLE_ACTION_SET_SUBTITLE, t.subtitle()))
    if t.action_text().byte_length() > 0:
        out.append(_set_title(TITLE_ACTION_SET_ACTION_BAR, t.action_text()))
    return out^


def form_packet(mut ui: SessionUI, json: String) raises -> List[UInt8]:
    """Go `SendForm`: the next form ID and the form's JSON. Returns the
    packet; the ID is `ui.current_form_id`."""
    ui.current_form_id += 1
    var pk = ModalFormRequest()
    pk.form_id = ui.current_form_id
    pk.form_data = List[UInt8](json.as_bytes())
    return encode_packet(pk)


def close_form_packet() raises -> List[UInt8]:
    """Go `CloseForm`."""
    var pk = ClientBoundCloseForm()
    return encode_packet(pk)


def npc_data(display: DisplaySettings, entity_offset: Vec3) -> String:
    """The NPC data metadata of a dialogue's entity (Go
    `{"portrait_offsets": disp}` with the entity's network offset added)."""
    var d = display.copy()
    d.entity_offset = d.entity_offset.add(entity_offset)
    var m = JsonObject()
    m.raw("portrait_offsets", d.marshal_json())
    return m.encode()


def dialogue_packets(
    mut ui: SessionUI,
    entity_runtime_id: UInt64,
    var metadata: EntityMetadata,
    npc_data_json: String,
    title: String,
    body: String,
    actions_json: String,
) raises -> List[List[UInt8]]:
    """Go `SendDialogue`: the entity's metadata with the NPC flag and data,
    then the dialogue."""
    ui.dialogue_entity = entity_runtime_id
    metadata.set(ENTITY_DATA_KEY_HAS_NPC, UInt8(1))
    metadata.set(ENTITY_DATA_KEY_NPC_DATA, npc_data_json.copy())
    var data = SetActorData()
    data.entity_runtime_id = entity_runtime_id
    data.entity_metadata = metadata^
    var pk = NPCDialogue()
    pk.entity_unique_id = entity_runtime_id
    pk.action_type = NPC_DIALOGUE_ACTION_OPEN
    pk.dialogue = body.copy()
    pk.scene_name = "default"
    pk.npc_name = title.copy()
    pk.action_json = actions_json.copy()
    return [encode_packet(data), encode_packet(pk)]


def close_dialogue_packets(mut ui: SessionUI) raises -> List[List[UInt8]]:
    """Go `CloseDialogue`: nothing if no dialogue is open."""
    if ui.dialogue_entity == 0:
        return List[List[UInt8]]()
    var pk = NPCDialogue()
    pk.entity_unique_id = ui.dialogue_entity
    pk.action_type = NPC_DIALOGUE_ACTION_CLOSE
    ui.dialogue_entity = 0
    return [encode_packet(pk)]
