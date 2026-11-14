"""Skin model configurations, ported from Dragonfly
`server/player/skin/model_config.go`."""

from ...internal.gojson import quote
from ...internal.json import JSON_NULL, JSON_OBJECT, JSON_STRING, JsonDoc


@fieldwise_init
struct ModelConfig(Copyable, Defaultable, Equatable):
    """Which geometry a skin uses (Go `skin.ModelConfig`), the skin
    resource patch."""

    var default: String
    """The default geometry, such as `geometry.humanoid.custom`."""
    var animated_face: String
    """The geometry of the animated face, if any."""

    def __init__(out self):
        """Creates an empty configuration."""
        self.default = String()
        self.animated_face = String()

    def encode(self) -> String:
        """Returns the configuration's JSON (Go `Encode`)."""
        var out = String('{"geometry":{"default":')
        out += quote(self.default)
        if self.animated_face.byte_length() > 0:
            out += ',"animated_face":'
            out += quote(self.animated_face)
        out += "}}"
        return out^


def _fold_equal(a: String, b: StaticString) -> Bool:
    # Go encoding/json matches field names case-insensitively.
    return a.lower() == b


def decode_model_config(b: Span[UInt8, _]) raises -> ModelConfig:
    """Decodes a configuration (Go `DecodeModelConfig`), raising if the
    JSON is invalid or a field has the wrong type."""
    var doc = JsonDoc(b)
    var out = ModelConfig()
    var root = doc.root()
    if doc.kind(root) == JSON_NULL:
        return out^
    if doc.kind(root) != JSON_OBJECT:
        raise Error(
            "json: cannot unmarshal into Go value of type"
            " skin.modelConfigContainer"
        )
    var failed = False
    for m in doc.children(root):
        if not _fold_equal(doc.key(m), "geometry"):
            continue
        if doc.kind(m) == JSON_NULL:
            continue
        if doc.kind(m) != JSON_OBJECT:
            failed = True
            continue
        for f in doc.children(m):
            var k = doc.key(f)
            if _fold_equal(k, "default") or _fold_equal(k, "animated_face"):
                if doc.kind(f) == JSON_NULL:
                    continue
                if doc.kind(f) != JSON_STRING:
                    failed = True
                    continue
                if _fold_equal(k, "default"):
                    out.default = doc.as_string(f)
                else:
                    out.animated_face = doc.as_string(f)
    if failed:
        raise Error(
            "json: cannot unmarshal into Go struct field of type string"
        )
    return out^
