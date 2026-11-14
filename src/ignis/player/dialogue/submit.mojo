"""What dialogues submit to, ported from Dragonfly
`server/player/dialogue/submit.go`; see `form/submit.mojo` for how Go's
`*world.Tx` argument maps."""

from .button import Button


trait Submitter:
    """Something that interacts with dialogues: a player (Go
    `dialogue.Submitter`)."""

    comptime Tx: AnyType
    """What a dialogue's submit receives besides the submitter."""

    def close_dialogue(mut self):
        """Closes the dialogue the submitter has open (Go
        `CloseDialogue`)."""
        ...


trait Submittable(Copyable, Deinitable):
    """A struct whose fields are the dialogue's buttons (Go
    `dialogue.Submittable`)."""

    def submit[
        S: Submitter
    ](mut self, mut submitter: S, pressed: Button, mut tx: S.Tx):
        """Called with the button that was pressed."""
        ...


trait Closer:
    """A submittable with logic for when the dialogue is closed (Go
    `Closer`)."""

    def close[S: Submitter](mut self, mut submitter: S, mut tx: S.Tx):
        """Called when the submitter closes the dialogue."""
        ...
