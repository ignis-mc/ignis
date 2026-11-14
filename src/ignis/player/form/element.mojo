"""Form elements, ported from Dragonfly `server/player/form/element.go`.

Each element writes the JSON Go's `MarshalJSON` writes (`ignis.internal.
gojson`: keys sorted, Go's string escaping and float format). The value a
submitter fills out is parsed by `parse_value`, which is Go's
`Custom.parseValue` case for the element.
"""

from ...internal.gojson import JsonObject, string_array, valid_utf8
from ...internal.json import (
    JSON_BOOL,
    JSON_NUMBER,
    JSON_STRING,
    JsonDoc,
)
from .number import parse_number_float, parse_number_int


trait Element(Copyable):
    """An element of a custom form (Go `form.Element`)."""

    def marshal_json(self) -> String:
        """Returns the element's JSON (Go `MarshalJSON`)."""
        ...

    def readonly(self) -> Bool:
        """Reports whether submitters cannot fill the element out (Go
        `elementReadonly`: dividers, headers and labels)."""
        ...

    def parse_value(mut self, doc: JsonDoc, i: Int) raises:
        """Sets the value a submitter filled out from a JSON value, raising
        if it is not valid for the element (Go `parseValue`)."""
        ...


trait MenuElement(Copyable):
    """An element of a menu form (Go `form.MenuElement`)."""

    def marshal_json(self) -> String:
        """Returns the element's JSON (Go `MarshalJSON`)."""
        ...

    def as_button(self) -> Optional[Button]:
        """Returns the element if it is a button (Go `elem.(Button)`)."""
        ...


struct Divider(Defaultable, Element, MenuElement):
    """A horizontal line on a form (Go `Divider`)."""

    def __init__(out self):
        """Creates a divider."""
        pass

    def marshal_json(self) -> String:
        """Returns `{"text":"","type":"divider"}`."""
        var m = JsonObject()
        m.string("type", "divider")
        m.string("text", "")
        return m.encode()

    def readonly(self) -> Bool:
        """Dividers hold no value."""
        return True

    def parse_value(mut self, doc: JsonDoc, i: Int) raises:
        """Does nothing; dividers hold no value."""
        pass

    def as_button(self) -> Optional[Button]:
        """Returns None."""
        return None


@fieldwise_init
struct Header(Element, MenuElement):
    """Larger text for section titles (Go `Header`)."""

    var text: String
    """The text, which may hold formatting codes."""

    def marshal_json(self) -> String:
        """Returns the header's JSON."""
        var m = JsonObject()
        m.string("type", "header")
        m.string("text", self.text)
        return m.encode()

    def readonly(self) -> Bool:
        """Headers hold no value."""
        return True

    def parse_value(mut self, doc: JsonDoc, i: Int) raises:
        """Does nothing; headers hold no value."""
        pass

    def as_button(self) -> Optional[Button]:
        """Returns None."""
        return None


@fieldwise_init
struct Label(Element, MenuElement):
    """A static box of text (Go `Label`)."""

    var text: String
    """The text, which may hold formatting codes."""

    def marshal_json(self) -> String:
        """Returns the label's JSON."""
        var m = JsonObject()
        m.string("type", "label")
        m.string("text", self.text)
        return m.encode()

    def readonly(self) -> Bool:
        """Labels hold no value."""
        return True

    def parse_value(mut self, doc: JsonDoc, i: Int) raises:
        """Does nothing; labels hold no value."""
        pass

    def as_button(self) -> Optional[Button]:
        """Returns None."""
        return None


struct Input(Element):
    """A text box (Go `Input`)."""

    var text: String
    """The text above the box."""
    var default: String
    """The text filled out by default."""
    var placeholder: String
    """The text shown while the box is empty."""
    var tooltip: String
    """Text shown when hovering the info icon; no icon if empty."""
    var _value: String

    def __init__(
        out self,
        text: String = "",
        default: String = "",
        placeholder: String = "",
        tooltip: String = "",
    ):
        """Creates an input (Go `NewInput`)."""
        self.text = text
        self.default = default
        self.placeholder = placeholder
        self.tooltip = tooltip
        self._value = String()

    def with_tooltip(self, tooltip: String) -> Self:
        """Returns a copy with the tooltip set (Go `WithTooltip`)."""
        var c = self.copy()
        c.tooltip = tooltip
        return c^

    def value(self) -> String:
        """Returns the text the submitter filled out (Go `Value`)."""
        return self._value

    def marshal_json(self) -> String:
        """Returns the input's JSON."""
        var m = JsonObject()
        m.string("type", "input")
        m.string("text", self.text)
        m.string("default", self.default)
        m.string("placeholder", self.placeholder)
        if self.tooltip.byte_length() > 0:
            m.string("tooltip", self.tooltip)
        return m.encode()

    def readonly(self) -> Bool:
        """Inputs hold a value."""
        return False

    def parse_value(mut self, doc: JsonDoc, i: Int) raises:
        """Takes a string."""
        if doc.kind(i) != JSON_STRING:
            raise Error("value is not allowed for input element")
        var s = doc.as_string(i)
        if not valid_utf8(s.as_bytes()):
            raise Error("value is not valid UTF8")
        self._value = s^


struct Toggle(Element):
    """An on-off switch (Go `Toggle`)."""

    var text: String
    """The text next to the toggle."""
    var default: Bool
    """Whether the toggle is on by default."""
    var tooltip: String
    """Text shown when hovering the info icon; no icon if empty."""
    var _value: Bool

    def __init__(
        out self, text: String = "", default: Bool = False, tooltip: String = ""
    ):
        """Creates a toggle (Go `NewToggle`)."""
        self.text = text
        self.default = default
        self.tooltip = tooltip
        self._value = False

    def with_tooltip(self, tooltip: String) -> Self:
        """Returns a copy with the tooltip set (Go `WithTooltip`)."""
        var c = self.copy()
        c.tooltip = tooltip
        return c^

    def value(self) -> Bool:
        """Returns whether the submitter turned the toggle on (Go `Value`)."""
        return self._value

    def marshal_json(self) -> String:
        """Returns the toggle's JSON."""
        var m = JsonObject()
        m.string("type", "toggle")
        m.string("text", self.text)
        m.bool("default", self.default)
        if self.tooltip.byte_length() > 0:
            m.string("tooltip", self.tooltip)
        return m.encode()

    def readonly(self) -> Bool:
        """Toggles hold a value."""
        return False

    def parse_value(mut self, doc: JsonDoc, i: Int) raises:
        """Takes a boolean."""
        if doc.kind(i) != JSON_BOOL:
            raise Error("value is not allowed for toggle element")
        self._value = doc.as_bool(i)


struct Slider(Element):
    """A slider over a range of numbers (Go `Slider`)."""

    var text: String
    """The text above the slider."""
    var min: Float64
    """The lowest value."""
    var max: Float64
    """The highest value."""
    var step_size: Float64
    """The size of one step."""
    var default: Float64
    """The value selected by default."""
    var tooltip: String
    """Text shown when hovering the info icon; no icon if empty."""
    var _value: Float64

    def __init__(
        out self,
        text: String = "",
        min: Float64 = 0,
        max: Float64 = 0,
        step_size: Float64 = 0,
        default: Float64 = 0,
        tooltip: String = "",
    ):
        """Creates a slider (Go `NewSlider`)."""
        self.text = text
        self.min = min
        self.max = max
        self.step_size = step_size
        self.default = default
        self.tooltip = tooltip
        self._value = 0

    def with_tooltip(self, tooltip: String) -> Self:
        """Returns a copy with the tooltip set (Go `WithTooltip`)."""
        var c = self.copy()
        c.tooltip = tooltip
        return c^

    def value(self) -> Float64:
        """Returns the value the submitter selected (Go `Value`)."""
        return self._value

    def marshal_json(self) -> String:
        """Returns the slider's JSON."""
        var m = JsonObject()
        m.string("type", "slider")
        m.string("text", self.text)
        m.float("min", self.min)
        m.float("max", self.max)
        m.float("step", self.step_size)
        m.float("default", self.default)
        if self.tooltip.byte_length() > 0:
            m.string("tooltip", self.tooltip)
        return m.encode()

    def readonly(self) -> Bool:
        """Sliders hold a value."""
        return False

    def parse_value(mut self, doc: JsonDoc, i: Int) raises:
        """Takes a number within the slider's range."""
        if doc.kind(i) != JSON_NUMBER:
            raise Error("value is not allowed for slider element")
        var f = parse_number_float(doc, i)
        if not f:
            raise Error("value is not allowed for slider element")
        var v = f.value()
        if v > self.max or v < self.min:
            raise Error("slider value is out of range")
        self._value = v


struct Dropdown(Element):
    """A list of options to pick one from (Go `Dropdown`)."""

    var text: String
    """The text above the dropdown."""
    var options: List[String]
    """The options, in order."""
    var default_index: Int
    """The index of the option selected by default."""
    var tooltip: String
    """Text shown when hovering the info icon; no icon if empty."""
    var _value: Int

    def __init__(
        out self,
        text: String = "",
        var options: List[String] = [],
        default_index: Int = 0,
        tooltip: String = "",
    ):
        """Creates a dropdown (Go `NewDropdown`)."""
        self.text = text
        self.options = options^
        self.default_index = default_index
        self.tooltip = tooltip
        self._value = 0

    def with_tooltip(self, tooltip: String) -> Self:
        """Returns a copy with the tooltip set (Go `WithTooltip`)."""
        var c = self.copy()
        c.tooltip = tooltip
        return c^

    def value(self) -> Int:
        """Returns the index of the option the submitter picked (Go
        `Value`)."""
        return self._value

    def marshal_json(self) -> String:
        """Returns the dropdown's JSON."""
        var m = JsonObject()
        m.string("type", "dropdown")
        m.string("text", self.text)
        m.int("default", self.default_index)
        m.raw("options", string_array(self.options))
        if self.tooltip.byte_length() > 0:
            m.string("tooltip", self.tooltip)
        return m.encode()

    def readonly(self) -> Bool:
        """Dropdowns hold a value."""
        return False

    def parse_value(mut self, doc: JsonDoc, i: Int) raises:
        """Takes the index of an option."""
        self._value = _option_index(doc, i, len(self.options), "dropdown")


struct StepSlider(Element):
    """A slider over a list of options (Go `StepSlider`)."""

    var text: String
    """The text above the slider."""
    var options: List[String]
    """The options, in order."""
    var default_index: Int
    """The index of the option selected by default."""
    var tooltip: String
    """Text shown when hovering the info icon; no icon if empty."""
    var _value: Int

    def __init__(
        out self,
        text: String = "",
        var options: List[String] = [],
        default_index: Int = 0,
        tooltip: String = "",
    ):
        """Creates a step slider (Go `NewStepSlider`)."""
        self.text = text
        self.options = options^
        self.default_index = default_index
        self.tooltip = tooltip
        self._value = 0

    def with_tooltip(self, tooltip: String) -> Self:
        """Returns a copy with the tooltip set (Go `WithTooltip`)."""
        var c = self.copy()
        c.tooltip = tooltip
        return c^

    def value(self) -> Int:
        """Returns the index of the option the submitter picked (Go
        `Value`)."""
        return self._value

    def marshal_json(self) -> String:
        """Returns the step slider's JSON."""
        var m = JsonObject()
        m.string("type", "step_slider")
        m.string("text", self.text)
        m.int("default", self.default_index)
        m.raw("steps", string_array(self.options))
        if self.tooltip.byte_length() > 0:
            m.string("tooltip", self.tooltip)
        return m.encode()

    def readonly(self) -> Bool:
        """Step sliders hold a value."""
        return False

    def parse_value(mut self, doc: JsonDoc, i: Int) raises:
        """Takes the index of an option."""
        # Go reports step slider errors as dropdown errors.
        self._value = _option_index(doc, i, len(self.options), "dropdown")


def _option_index(doc: JsonDoc, i: Int, n: Int, what: String) raises -> Int:
    if doc.kind(i) != JSON_NUMBER:
        raise Error(t"value is not allowed for {what} element")
    var v = parse_number_int(doc, i)
    if not v:
        raise Error(t"value is not allowed for {what} element")
    var x = v.value()
    if x < 0 or x >= Int64(n):
        raise Error(t"{what} value is out of range")
    return Int(x)


@fieldwise_init
struct Button(Defaultable, Equatable, MenuElement):
    """A button on a menu or modal form, with optional image (Go
    `Button`)."""

    var text: String
    """The text, which may hold formatting codes and newlines."""
    var image: String
    """A URL (`http:`/`https:`) or a texture path; no image if empty."""

    def __init__(out self):
        """Creates a button without text."""
        self.text = String()
        self.image = String()

    def __init__(out self, text: String):
        """Creates a button without image."""
        self.text = text
        self.image = String()

    def marshal_json(self) -> String:
        """Returns the button's JSON."""
        var m = JsonObject()
        m.string("type", "button")
        m.string("text", self.text)
        if self.image.byte_length() > 0:
            var kind = "path"
            if self.image.startswith("http:") or self.image.startswith(
                "https:"
            ):
                kind = "url"
            var img = JsonObject()
            img.string("type", kind)
            img.string("data", self.image)
            m.raw("image", img.encode())
        return m.encode()

    def as_button(self) -> Optional[Button]:
        """Returns the button."""
        return self.copy()
