"""Forms, ported from Dragonfly `server/player/form`.

```mojo
from ignis.player import form


struct Survey(form.Submittable):
    var name: form.Input
    var agree: form.Toggle
    var _asked_by: String  # not an element: starts with `_`

    def submit[S: form.Submitter](mut self, mut submitter: S, mut tx: S.Tx):
        print(self.name.value(), self.agree.value())


var f = form.new(Survey(form.Input("Name"), form.Toggle("Agree"), "srv"), "Survey")
session.send_form(...)  # the server keeps a form.Form[S](f^) per form ID
```

| Dragonfly | Ignis |
| --- | --- |
| `form.New(s, title...)` | `form.new(s, title)` (`Custom[R]`) |
| `form.NewMenu`, `form.NewModal` | `form.new_menu`, `form.new_modal` |
| unexported fields | fields starting with `_` |
| a non-`Element` field: panic | a compile error |
| `form.Form` interface value | `form.Form[S]` (owns any `FormType`) |
| `Submit(submitter, tx *world.Tx)` | `submit[S: Submitter](mut self, mut submitter, mut tx: S.Tx)` |

The JSON is byte-for-byte what Dragonfly sends (`ignis.internal.gojson`),
and responses are validated as Go's `SubmitJSON` validates them.
"""

from .element import (
    Button,
    Divider,
    Dropdown,
    Element,
    Header,
    Input,
    Label,
    MenuElement,
    Slider,
    StepSlider,
    Toggle,
)
from .form import Custom, Form, FormType, format, new
from .menu import Menu, new_menu
from .modal import Modal, new_modal, no_button, yes_button
from .submit import (
    Closer,
    MenuSubmittable,
    ModalSubmittable,
    Submittable,
    Submitter,
)
