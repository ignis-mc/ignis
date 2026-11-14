"""What forms submit to, ported from Dragonfly
`server/player/form/submit.go`.

Go's `Submit(submitter Submitter, tx *world.Tx)` becomes a method generic
over the submitter type, with the submitter's associated `Tx` in place of
`*world.Tx`, as `cmd.Runnable.run` does for command sources.
"""

from .element import Button


trait Submitter:
    """Something that submits forms: a player (Go `form.Submitter`)."""

    comptime Tx: AnyType
    """What a form's submit receives besides the submitter (Go
    `*world.Tx`)."""

    def close_form(mut self):
        """Closes any form the submitter has open (Go `CloseForm`)."""
        ...


trait Submittable(Copyable, Deinitable):
    """A struct sent with `form.new` whose element fields are filled out
    when it is submitted (Go `Submittable`). Fields whose names start with
    `_` are not elements (Go's unexported fields)."""

    def submit[S: Submitter](mut self, mut submitter: S, mut tx: S.Tx):
        """Called with the fields filled out by the submitter."""
        ...


trait MenuSubmittable(Copyable, Deinitable):
    """A struct sent with `form.new_menu`; its fields are menu elements
    (Go `MenuSubmittable`)."""

    def submit[
        S: Submitter
    ](mut self, mut submitter: S, pressed: Button, mut tx: S.Tx):
        """Called with the button that was pressed."""
        ...


comptime ModalSubmittable = MenuSubmittable
"""A struct sent with `form.new_modal`, with exactly two `Button` fields
(Go `ModalSubmittable`)."""


trait Closer:
    """A submittable with logic for when the form is closed (Go
    `Closer`)."""

    def close[S: Submitter](mut self, mut submitter: S, mut tx: S.Tx):
        """Called when the submitter closes the form."""
        ...
