"""Forms and dialogues kept by the server, and the player methods that send
the player UI: Dragonfly's `Player.SendForm`, `SendDialogue`, `CloseForm`
and `CloseDialogue` with the form and dialogue state of
`session/handler_modal_form_response.go` and `handler_npc_request.go`.

Go's session keeps each player's open forms as `form.Form` interface
values; here a form's type is erased into a `form.Form[ServerSubmitter]`,
whose submit callbacks receive the server's submitter and `ServerTx`, so
the server, which owns both, keeps them. Sessions only number the forms and
report responses (`session.ui`).
"""

from minecraft.protocol.uuid import UUID

from ..mgl64 import Vec3
from ..player import dialogue, form
from ..player.player import EYE_HEIGHT
from ..session.session import player_metadata
from ..session.ui import FormResponse, MAX_FORMS, NPCAction, npc_data
from .command import ServerTx
from .server import Server


struct ServerSubmitter(dialogue.Submitter, form.Submitter, ImplicitlyCopyable):
    """The player submitting a form or dialogue (Go's `*player.Player` as a
    `form.Submitter`). Only valid while the server handles the response."""

    comptime Tx = ServerTx
    """Submittables receive the server (Go `*world.Tx`)."""

    var player: UUID
    """The player's UUID."""
    var _srv: Pointer[Server, MutUntrackedOrigin]

    def __init__(
        out self, player: UUID, srv: Pointer[Server, MutUntrackedOrigin]
    ):
        """Creates the submitter of a player."""
        self.player = player
        self._srv = srv

    def server(self) -> ref[MutUntrackedOrigin] Server:
        """Returns the server."""
        return self._srv[]

    def name(self) -> String:
        """Returns the player's name, or an empty string if they left."""
        if case .Some(i) = self._srv[].session_index(self.player):
            return self._srv[].sessions[i].player.name()
        return String()

    def message(mut self, message: String):
        """Sends the player a chat message (Go `Player.Message`)."""
        if case .Some(i) = self._srv[].session_index(self.player):
            self._srv[].sessions[i].send_message(message)

    def close_form(mut self):
        """Closes the player's open form (Go `CloseForm`)."""
        if case .Some(i) = self._srv[].session_index(self.player):
            self._srv[].sessions[i].close_form()

    def close_dialogue(mut self):
        """Closes the player's open dialogue (Go `CloseDialogue`)."""
        close_dialogue(self._srv[], self.player)


struct _PendingForm(Movable):
    var player: UUID
    var id: UInt32
    var form: form.Form[ServerSubmitter]

    def __init__(
        out self, player: UUID, id: UInt32, var f: form.Form[ServerSubmitter]
    ):
        self.player = player
        self.id = id
        self.form = f^


struct _OpenDialogue(Movable):
    var player: UUID
    var dialogue: dialogue.AnyDialogue[ServerSubmitter]

    def __init__(
        out self, player: UUID, var d: dialogue.AnyDialogue[ServerSubmitter]
    ):
        self.player = player
        self.dialogue = d^


struct ServerUI(Defaultable, Movable):
    """The forms and dialogues players have open."""

    var _forms: List[_PendingForm]
    var _dialogues: List[_OpenDialogue]

    def __init__(out self):
        """Creates the state with nothing open."""
        self._forms = List[_PendingForm]()
        self._dialogues = List[_OpenDialogue]()

    def open_forms(self, player: UUID) -> Int:
        """Returns how many forms a player has open."""
        var n = 0
        for i in range(len(self._forms)):
            if self._forms[i].player == player:
                n += 1
        return n

    def has_dialogue(self, player: UUID) -> Bool:
        """Reports whether a player has a dialogue open."""
        return self._dialogue_index(player) >= 0

    def forget(mut self, player: UUID):
        """Drops the forms and dialogue of a player who left."""
        var i = 0
        while i < len(self._forms):
            if self._forms[i].player == player:
                _ = self._forms.pop(i)
            else:
                i += 1
        var d = self._dialogue_index(player)
        if d >= 0:
            _ = self._dialogues.pop(d)

    def _add_form(
        mut self, player: UUID, id: UInt32, var f: form.Form[ServerSubmitter]
    ):
        # Go drops an open form once more than 10 are open; it picks one
        # from a map at random, Ignis the oldest.
        if self.open_forms(player) > MAX_FORMS:
            for i in range(len(self._forms)):
                if self._forms[i].player == player:
                    _ = self._forms.pop(i)
                    break
        self._forms.append(_PendingForm(player, id, f^))

    def _form_index(self, player: UUID, id: UInt32) -> Int:
        for i in range(len(self._forms)):
            if self._forms[i].player == player and self._forms[i].id == id:
                return i
        return -1

    def _dialogue_index(self, player: UUID) -> Int:
        for i in range(len(self._dialogues)):
            if self._dialogues[i].player == player:
                return i
        return -1


def _srv_ptr(mut srv: Server) -> Pointer[Server, MutUntrackedOrigin]:
    return Pointer(to=srv).unsafe_origin_cast[MutUntrackedOrigin]()


def send_form[
    F: form.FormType
](mut srv: Server, player: UUID, var f: F) -> Bool:
    """Sends a form to a player (Go `Player.SendForm`); False if the player
    is not online."""
    var i = srv.session_index(player)
    if not i:
        return False
    var json = f.marshal_json()
    var id = srv.sessions[i.value()].send_form_json(json)
    srv.ui._add_form(player, id, form.Form[ServerSubmitter](f^))
    return True


def handle_form_response(
    mut srv: Server, player: UUID, resp: FormResponse
) raises:
    """Submits a form response (Go `ModalFormResponseHandler.Handle`): an
    unknown form ID is ignored without data and an error with it."""
    var i = srv.ui._form_index(player, resp.id)
    if i < 0:
        if not resp.has_data:
            return
        raise Error(t"no form with ID {resp.id} currently opened")
    var pending = srv.ui._forms.pop(i)
    var submitter = ServerSubmitter(player, _srv_ptr(srv))
    var tx = ServerTx(_srv_ptr(srv))
    try:
        pending.form.submit_json(resp.data, submitter, tx)
    except e:
        raise Error(t"error submitting form data: {e}")


def send_dialogue[
    R: dialogue.Submittable
](
    mut srv: Server, player: UUID, var d: dialogue.Dialogue[R], entity: UUID
) raises -> Bool:
    """Opens a dialogue for a player on a player entity, the player itself
    included (Go `Player.SendDialogue`); False if either is not online."""
    var i = srv.session_index(player)
    var e = srv.session_index(entity)
    if not i or not e:
        return False
    ref target = srv.sessions[e.value()].player
    var rid = srv.sessions[i.value()].entity_runtime_id(target)
    if not rid:
        return False
    var metadata = player_metadata(target)
    # Players are offset by their eye height (Go `entityOffset`).
    var data = npc_data(d.display(), Vec3(0, EYE_HEIGHT, 0))
    srv.sessions[i.value()].send_dialogue(
        rid.value(), metadata^, data, d.title(), d.body(), d.marshal_json()
    )
    var idx = srv.ui._dialogue_index(player)
    if idx >= 0:
        _ = srv.ui._dialogues.pop(idx)
    srv.ui._dialogues.append(
        _OpenDialogue(player, dialogue.AnyDialogue[ServerSubmitter](d^))
    )
    return True


def close_dialogue(mut srv: Server, player: UUID):
    """Closes a player's dialogue (Go `Player.CloseDialogue`)."""
    if case .Some(i) = srv.session_index(player):
        srv.sessions[i].close_dialogue()


def handle_npc_action(mut srv: Server, player: UUID, a: NPCAction) raises:
    """Submits a dialogue button or closes the dialogue (Go
    `NPCRequestHandler.Handle`)."""
    var i = srv.ui._dialogue_index(player)
    if i < 0:
        return
    # Taken out while it runs: the submittable may open another dialogue.
    # Go keeps the dialogue after a button or a close from the client.
    var open = srv.ui._dialogues.pop(i)
    var submitter = ServerSubmitter(player, _srv_ptr(srv))
    var tx = ServerTx(_srv_ptr(srv))
    var err: Optional[String] = None
    if a.close:
        open.dialogue.close(submitter, tx)
    else:
        try:
            open.dialogue.submit(a.index, submitter, tx)
        except e:
            err = String(e)
    if srv.ui._dialogue_index(player) < 0:
        srv.ui._dialogues.append(open^)
    if case .Some(msg) = err:
        raise Error(t"error submitting dialogue: {msg}")
