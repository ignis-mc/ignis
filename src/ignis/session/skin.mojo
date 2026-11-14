"""Skin conversions: Dragonfly's `Server.parseSkin` (`server.go`),
`skinToProtocol` (`session/session_list.go`) and `protocolToSkin` (with
its validation, `session/player.go`)."""

from minecraft.protocol.login.data import ClientData
from minecraft.protocol.skin import (
    SKIN_ANIMATION_BODY_128X128,
    SKIN_ANIMATION_BODY_32X32,
    SKIN_ANIMATION_HEAD,
    Skin as ProtocolSkin,
    SkinAnimation,
)
from minecraft.protocol.uuid import UUID
from minecraft.protocol.info import CURRENT_VERSION
from nethernet.crypto.base64 import base64_decode
from nethernet.os.random import random_bytes

from ..internal.json import JSON_NULL, JSON_OBJECT, JsonDoc
from ..player.skin import (
    ANIMATION_BODY_128X128,
    ANIMATION_BODY_32X32,
    ANIMATION_HEAD,
    Animation,
    Cape,
    ModelConfig,
    Skin,
    decode_model_config,
)


def _b64(s: String) -> List[UInt8]:
    # Go base64.StdEncoding.DecodeString with its error ignored.
    try:
        return base64_decode(s)
    except:
        return List[UInt8]()


def _random_uuid() -> String:
    var b = List[UInt8](length=16, fill=0)
    try:
        b = random_bytes(16)
    except:
        pass
    try:
        return String(UUID.from_random(Span(b)))
    except:
        return "00000000-0000-4000-8000-000000000000"


def parse_skin(data: ClientData) -> Skin:
    """Builds a player's skin from its login client data (Go
    `Server.parseSkin`)."""
    var s = Skin(data.skin_image_width, data.skin_image_height)
    s.persona = data.persona_skin
    s.pix = _b64(data.skin_data)
    s.model = _b64(data.skin_geometry)
    try:
        s.model_config = decode_model_config(_b64(data.skin_resource_patch))
    except:
        s.model_config = ModelConfig()
    s.full_id = data.skin_id.copy()
    s.cape = Cape(data.cape_image_width, data.cape_image_height)
    s.cape.pix = _b64(data.cape_data)
    for a in data.animated_image_data:
        var t = ANIMATION_HEAD
        if a.type == Int(SKIN_ANIMATION_BODY_32X32):
            t = ANIMATION_BODY_32X32
        elif a.type == Int(SKIN_ANIMATION_BODY_128X128):
            t = ANIMATION_BODY_128X128
        var anim = Animation(
            a.image_width, a.image_height, a.animation_expression, t
        )
        anim.frame_count = Int(a.frames)
        anim.pix = _b64(a.image)
        s.animations.append(anim^)
    return s^


def skin_to_protocol(s: Skin) -> ProtocolSkin:
    """Converts a skin to its network form, with fresh random skin and cape
    IDs (Go `skinToProtocol`)."""
    var p = ProtocolSkin()
    for a in s.animations:
        var pa = SkinAnimation()
        pa.image_width = UInt32(a.bounds()[0])
        pa.image_height = UInt32(a.bounds()[1])
        pa.image_data = a.pix.copy()
        pa.frame_count = Float32(a.frame_count)
        if a.type() == ANIMATION_HEAD:
            pa.animation_type = SKIN_ANIMATION_HEAD
        elif a.type() == ANIMATION_BODY_32X32:
            pa.animation_type = SKIN_ANIMATION_BODY_32X32
        elif a.type() == ANIMATION_BODY_128X128:
            pa.animation_type = SKIN_ANIMATION_BODY_128X128
        pa.expression_type = UInt32(a.animation_expression)
        p.animations.append(pa^)
    p.full_id = s.full_id.copy()
    if p.full_id.byte_length() == 0:
        p.full_id = _random_uuid()
    p.skin_geometry = s.model.copy()
    if len(p.skin_geometry) == 0:
        p.skin_geometry = List[UInt8]("{}".as_bytes())
    p.skin_id = _random_uuid()
    p.skin_resource_patch = List[UInt8](s.model_config.encode().as_bytes())
    p.skin_image_width = UInt32(s.bounds()[0])
    p.skin_image_height = UInt32(s.bounds()[1])
    p.skin_data = s.pix.copy()
    p.cape_image_width = UInt32(s.cape.bounds()[0])
    p.cape_image_height = UInt32(s.cape.bounds()[1])
    p.cape_data = s.cape.pix.copy()
    p.persona_skin = s.persona
    p.cape_id = _random_uuid()
    p.trusted = True
    p.override_appearance = True
    p.geometry_data_engine_version = List[UInt8](CURRENT_VERSION.as_bytes())
    return p^


def protocol_to_skin(sk: ProtocolSkin) raises -> Skin:
    """Converts a network skin, raising if it is invalid (Go
    `protocolToSkin`): an empty skin ID, geometry that is not a JSON
    object, an invalid resource patch or an unknown animation type."""
    if sk.skin_id.byte_length() == 0:
        raise Error("SkinID must not be an empty string")
    var s = Skin(Int(sk.skin_image_width), Int(sk.skin_image_height))
    s.persona = sk.persona_skin
    s.pix = sk.skin_data.copy()
    s.model = sk.skin_geometry.copy()
    s.full_id = sk.full_id.copy()
    s.cape = Cape(Int(sk.cape_image_width), Int(sk.cape_image_height))
    s.cape.pix = sk.cape_data.copy()
    try:
        var doc = JsonDoc(Span(sk.skin_geometry))
        var k = doc.kind(doc.root())
        if k != JSON_OBJECT and k != JSON_NULL:
            raise Error("json: cannot unmarshal into map[string]interface {}")
    except e:
        raise Error(t"SkinGeometry was not a valid JSON string: {e}")
    try:
        s.model_config = decode_model_config(Span(sk.skin_resource_patch))
    except e:
        raise Error(t"SkinResourcePatch was not a valid JSON string: {e}")
    for a in sk.animations:
        var t: Int
        if a.animation_type == SKIN_ANIMATION_HEAD:
            t = ANIMATION_HEAD
        elif a.animation_type == SKIN_ANIMATION_BODY_32X32:
            t = ANIMATION_BODY_32X32
        elif a.animation_type == SKIN_ANIMATION_BODY_128X128:
            t = ANIMATION_BODY_128X128
        else:
            raise Error(t"invalid animation type: {a.animation_type}")
        var anim = Animation(
            Int(a.image_width), Int(a.image_height), Int(a.expression_type), t
        )
        anim.frame_count = Int(a.frame_count)
        anim.pix = a.image_data.copy()
        s.animations.append(anim^)
    return s^
