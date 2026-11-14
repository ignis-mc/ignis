"""`/ui`: shows each part of the player UI, for trying it out and for the
end-to-end tests. Dragonfly has no such command.

`/ui menu` opens a menu whose buttons open the rest; `/ui form`, `modal`,
`scoreboard`, `bossbar`, `title`, `toast`, `tip`, `dialogue` show one
directly and `/ui clear` removes the scoreboard and boss bar. Submitted
forms answer in chat, so a client (or a bot) can see what the server read.
"""

from minecraft.protocol.uuid import UUID

from .. import cmd
from ..internal.gojson import format_float
from ..player import dialogue, form
from ..player.bossbar import BossBar, Colour
from ..player.scoreboard import Scoreboard
from ..player.title import Title
from .command import CommandSource, ServerTx
from .server import Server
from .ui import ServerSubmitter, send_dialogue, send_form


def register_ui_commands(mut r: cmd.Registry[CommandSource]):
    """Registers `/ui`."""
    r.register(
        cmd.new[CommandSource, UICommand](
            "ui",
            "Shows forms, scoreboards, boss bars and titles.",
            List[String](),
        )
    )


@fieldwise_init
struct UIKind(cmd.Enum):
    """What `/ui` shows."""

    var value: String
    """The chosen option."""

    def __init__(out self):
        """Creates an unset option."""
        self.value = ""

    def type(self) -> String:
        """Returns the enum name."""
        return "UIKind"

    def options[S: cmd.Source](self, src: S) -> List[String]:
        """Lists the parts of the UI."""
        return [
            "menu",
            "form",
            "modal",
            "scoreboard",
            "bossbar",
            "title",
            "toast",
            "tip",
            "dialogue",
            "clear",
        ]

    def set_option(mut self, var option: String):
        """Stores the chosen option."""
        self.value = option^


struct UICommand(cmd.Runnable):
    """`/ui <kind>`."""

    var kind: UIKind
    """What to show."""

    def __init__(out self):
        """Creates the runnable with zero parameters."""
        self.kind = UIKind()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        """Shows the chosen part of the UI to the player running it."""
        comptime if S == CommandSource:
            ref s = rebind[CommandSource](src)
            if not s.player:
                o.error("Only players can see the UI")
                return
            show(
                rebind[ServerTx](tx).server(), s.player.value(), self.kind.value
            )


def show(mut srv: Server, player: UUID, kind: String):
    """Shows a part of the UI to a player."""
    var found = srv.session_index(player)
    if not found:
        return
    var i = found.value()
    if kind == "menu":
        _ = send_form(srv, player, demo_menu())
    elif kind == "form":
        _ = send_form(srv, player, demo_form())
    elif kind == "modal":
        _ = send_form(srv, player, demo_modal())
    elif kind == "scoreboard":
        var sb = Scoreboard("§l§6Ignis")
        try:
            _ = sb.write_string("Players: " + String(srv.player_count()))
            _ = sb.write_string("§aMojo " + "§r+ NetherNet")
            sb.set(3, "§7ignis-mc")
        except:
            pass
        srv.sessions[i].send_scoreboard(sb)
    elif kind == "bossbar":
        try:
            var bar = (
                BossBar("§dIgnis boss bar")
                .with_health_percentage(0.6)
                .with_colour(Colour.PINK)
            )
            srv.sessions[i].send_boss_bar(
                bar.text(), bar.colour().uint8(), bar.health_percentage()
            )
        except:
            pass
    elif kind == "title":
        srv.sessions[i].send_title(
            Title("§6Ignis")
            .with_subtitle("§7a Dragonfly port in Mojo")
            .with_action_text("§aaction bar")
            .with_duration_ms(5000)
        )
    elif kind == "toast":
        srv.sessions[i].send_toast("Ignis", "A toast from the server")
    elif kind == "tip":
        srv.sessions[i].send_tip("§eA tip above the hotbar")
    elif kind == "dialogue":
        try:
            var d = dialogue.new(
                DemoDialogue(dialogue.Button("Hello"), dialogue.Button("Bye")),
                "Ignis NPC",
            ).with_body("Pick a button.")
            _ = send_dialogue(srv, player, d^, player)
        except:
            pass
    elif kind == "clear":
        srv.sessions[i].remove_scoreboard()
        srv.sessions[i].remove_boss_bar()


@fieldwise_init
struct DemoMenu(form.Closer, form.MenuSubmittable):
    """The `/ui menu` form: one button per part of the UI."""

    var form: form.Button
    var modal: form.Button
    var scoreboard: form.Button
    var bossbar: form.Button
    var title: form.Button
    var toast: form.Button
    var dialogue: form.Button

    def submit[
        S: form.Submitter
    ](mut self, mut submitter: S, pressed: form.Button, mut tx: S.Tx):
        """Shows what the pressed button names."""
        comptime if S == ServerSubmitter:
            ref sub = rebind[ServerSubmitter](submitter)
            sub.message("§7menu: pressed " + pressed.text)
            show(sub.server(), sub.player, pressed.text.lower())

    def close[S: form.Submitter](mut self, mut submitter: S, mut tx: S.Tx):
        """Reports that the menu was closed."""
        comptime if S == ServerSubmitter:
            rebind[ServerSubmitter](submitter).message("§7menu: closed")


def demo_menu() -> form.Menu[DemoMenu]:
    """The `/ui menu` form."""
    return form.new_menu(
        DemoMenu(
            form.Button("Form", "textures/items/book_writable"),
            form.Button("Modal"),
            form.Button("Scoreboard"),
            form.Button("Bossbar"),
            form.Button("Title"),
            form.Button("Toast"),
            form.Button("Dialogue"),
        ),
        "§lIgnis UI",
    ).with_body("Pick something to show.")


@fieldwise_init
struct DemoForm(form.Closer, form.Submittable):
    """The `/ui form` custom form, with every element type."""

    var header: form.Header
    var label: form.Label
    var name: form.Input
    var agree: form.Toggle
    var volume: form.Slider
    var colour: form.Dropdown
    var size: form.StepSlider
    var divider: form.Divider

    def submit[S: form.Submitter](mut self, mut submitter: S, mut tx: S.Tx):
        """Echoes the submitted values in chat."""
        comptime if S == ServerSubmitter:
            var agree = "true" if self.agree.value() else "false"
            rebind[ServerSubmitter](submitter).message(
                String(
                    t"form: name={self.name.value()} agree={agree}"
                    t" volume={format_float(self.volume.value())}"
                    t" colour={self.colour.options[self.colour.value()]}"
                    t" size={self.size.options[self.size.value()]}"
                )
            )

    def close[S: form.Submitter](mut self, mut submitter: S, mut tx: S.Tx):
        """Reports that the form was closed."""
        comptime if S == ServerSubmitter:
            rebind[ServerSubmitter](submitter).message("form: closed")


def demo_form() -> form.Custom[DemoForm]:
    """The `/ui form` form."""
    return form.new(
        DemoForm(
            form.Header("Tell us about yourself"),
            form.Label("Every element type Dragonfly supports."),
            form.Input("Name", "", "Steve").with_tooltip("Your name"),
            form.Toggle("Agree", True),
            form.Slider("Volume", 0, 10, 0.5, 5),
            form.Dropdown("Colour", ["red", "green", "blue"], 1),
            form.StepSlider("Size", ["S", "M", "L"], 1),
            form.Divider(),
        ),
        "§lIgnis form",
    )


@fieldwise_init
struct DemoModal(form.ModalSubmittable):
    """The `/ui modal` form."""

    var yes: form.Button
    var no: form.Button

    def submit[
        S: form.Submitter
    ](mut self, mut submitter: S, pressed: form.Button, mut tx: S.Tx):
        """Echoes the pressed button in chat."""
        comptime if S == ServerSubmitter:
            rebind[ServerSubmitter](submitter).message(
                "modal: pressed " + pressed.text
            )


def demo_modal() -> form.Modal[DemoModal]:
    """The `/ui modal` form."""
    return form.new_modal(
        DemoModal(form.yes_button(), form.no_button()), "§lIgnis modal"
    ).with_body("Do you like Mojo?")


@fieldwise_init
struct DemoDialogue(dialogue.Closer, dialogue.Submittable):
    """The `/ui dialogue` dialogue."""

    var hello: dialogue.Button
    var bye: dialogue.Button

    def submit[
        S: dialogue.Submitter
    ](mut self, mut submitter: S, pressed: dialogue.Button, mut tx: S.Tx):
        """Echoes the pressed button and closes the dialogue."""
        comptime if S == ServerSubmitter:
            ref sub = rebind[ServerSubmitter](submitter)
            sub.message("dialogue: pressed " + pressed.text)
            sub.close_dialogue()

    def close[S: dialogue.Submitter](mut self, mut submitter: S, mut tx: S.Tx):
        """Reports that the dialogue was closed."""
        comptime if S == ServerSubmitter:
            rebind[ServerSubmitter](submitter).message("dialogue: closed")
