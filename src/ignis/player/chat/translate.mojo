"""Translatable messages, ported from Dragonfly
`server/player/chat/translate.go`.

Go resolves a `TranslationString` per `language.Tag`; Dragonfly's own
strings resolve to their key for every language, so a translation here
holds its key and `resolve` takes the locale only to keep Go's shape.
Arguments are strings (Go's `fmt.Sprint` of each argument).
"""

from ...text import colourf, sprintf


@fieldwise_init
struct Translation(Copyable):
    """A translation key with its formatting (Go `chat.Translation`)."""

    var str: String
    """The translation key, such as `%multiplayer.player.joined`."""
    var format: String
    """Where the translated text goes: a `colourf` format with one `%v`."""
    var params: Int
    """How many arguments `f` takes."""
    var fallback: String
    """The English text, used by `Translated.string`."""

    def zero(self) -> Bool:
        """Reports whether the translation was not made with `translate`
        (Go `Zero`)."""
        return self.format.byte_length() == 0

    def enc(self, format: String) -> Self:
        """Returns a copy whose translated text is put into a `colourf`
        format with one `%v` (Go `Enc`)."""
        var t = self.copy()
        t.format = format
        return t^

    def f(self, var args: List[String] = []) raises -> Translated:
        """Fills out the arguments (Go `F`); raises unless exactly `params`
        are given (Go panics)."""
        if len(args) != self.params:
            raise Error(
                t"translation '{self.format}' requires exactly {self.params}"
                t" parameters, got {len(args)}"
            )
        return Translated(self.copy(), args^)

    def resolve(self, locale: String = "en_US") raises -> String:
        """Resolves the translation without arguments (Go `Resolve`)."""
        return self.f().resolve(locale)


@fieldwise_init
struct Translated(Copyable, Writable):
    """A translation with its arguments filled out (Go's unexported
    `translation`)."""

    var t: Translation
    """The translation."""
    var params: List[String]
    """The arguments."""

    def resolve(self, locale: String = "en_US") -> String:
        """Returns the key in its format, for the client to translate (Go
        `Resolve`)."""
        return colourf(self.t.format, [self.t.str])

    def parameters(self, locale: String = "en_US") -> List[String]:
        """Returns the arguments (Go `Params`)."""
        return self.params.copy()

    def string(self) -> String:
        """Returns the English text with the arguments filled out (Go
        `String`)."""
        return sprintf(colourf(self.t.format, [self.t.fallback]), self.params)

    def write_to(self, mut writer: Some[Writer]):
        """Writes `string()`."""
        writer.write(self.string())


def translate(key: String, params: Int, fallback: String) -> Translation:
    """Creates a translation of a key that takes `params` arguments (Go
    `Translate`)."""
    return Translation(key, "%v", params, fallback)


def message_join() -> Translation:
    """`%v joined the game`, in yellow (Go `MessageJoin`)."""
    return translate("%multiplayer.player.joined", 1, "%v joined the game").enc(
        "<yellow>%v</yellow>"
    )


def message_quit() -> Translation:
    """`%v left the game`, in yellow (Go `MessageQuit`)."""
    return translate("%multiplayer.player.left", 1, "%v left the game").enc(
        "<yellow>%v</yellow>"
    )


def message_server_disconnect() -> Translation:
    """`Disconnected by Server` (Go `MessageServerDisconnect`)."""
    return translate(
        "%disconnect.disconnected", 0, "Disconnected by Server"
    ).enc("<yellow>%v</yellow>")


def message_bed_too_far() -> Translation:
    """Go `MessageBedTooFar`."""
    return translate("%tile.bed.tooFar", 0, "Bed is too far away").enc(
        "<grey>%v</grey>"
    )


def message_bed_obstructed() -> Translation:
    """Go `MessageBedObstructed`."""
    return translate("%tile.bed.obstructed", 0, "Bed is obstructed").enc(
        "<grey>%v</grey>"
    )


def message_respawn_point_set() -> Translation:
    """Go `MessageRespawnPointSet`."""
    return translate("%tile.bed.respawnSet", 0, "Respawn point set").enc(
        "<grey>%v</grey>"
    )


def message_no_sleep() -> Translation:
    """Go `MessageNoSleep`."""
    return translate(
        "%tile.bed.noSleep",
        0,
        "You can only sleep at night and during thunderstorms",
    ).enc("<grey>%v</grey>")


def message_bed_is_occupied() -> Translation:
    """Go `MessageBedIsOccupied`."""
    return translate("%tile.bed.occupied", 0, "This bed is occupied").enc(
        "<grey>%v</grey>"
    )


def message_sleeping() -> Translation:
    """Go `MessageSleeping`."""
    return translate(
        "%chat.type.sleeping",
        2,
        (
            "%v is sleeping in a bed. To skip to dawn, %v more users need to"
            " sleep in beds at the same time."
        ),
    )


def message_skipping_night() -> Translation:
    """Go `MessageSkippingNight`."""
    return translate(
        "%multiplayer.playersSkippingNight", 0, "Sleeping through this night"
    )


def message_bed_not_valid() -> Translation:
    """Go `MessageBedNotValid`."""
    return translate(
        "%tile.bed.notValid", 0, "Your home bed was missing or obstructed"
    )
