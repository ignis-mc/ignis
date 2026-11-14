from ignis.player.skin import (
    ANIMATION_BODY_32X32,
    Animation,
    ModelConfig,
    Skin,
    decode_model_config,
)
from ignis.session.skin import protocol_to_skin, skin_to_protocol
from minecraft.protocol.skin import Skin as ProtocolSkin
from minecraft.protocol.skin import SkinAnimation
from std.testing import TestSuite, assert_equal, assert_raises, assert_true
from support.ui_vectors import UIVectors


def test_model_config_matches_dragonfly() raises:
    var v = UIVectors()
    var cfg = ModelConfig("geometry.humanoid.custom", "")
    assert_equal(cfg.encode(), v.str("skin.model_config"))
    cfg.animated_face = "geometry.animated_face"
    assert_equal(cfg.encode(), v.str("skin.model_config_face"))
    var i = 0
    while v.has(String(t"skin.decode.{i}.in")):
        var got: String
        try:
            var m = decode_model_config(v.bytes(String(t"skin.decode.{i}.in")))
            got = m.default + "|" + m.animated_face
        except:
            got = "error"
        assert_equal(got, v.str(String(t"skin.decode.{i}.out")), String(i))
        i += 1
    assert_equal(i, 5)


def test_skin_round_trips_and_validates() raises:
    var s = Skin(64, 32)
    s.pix[0] = 7
    s.full_id = "id"
    s.model_config = ModelConfig("geometry.humanoid.custom", "")
    var a = Animation(32, 32, 1, ANIMATION_BODY_32X32)
    a.frame_count = 3
    s.animations.append(a^)
    var p = skin_to_protocol(s)
    assert_equal(p.skin_image_width, 64)
    assert_equal(String(from_utf8=p.skin_geometry), "{}")
    assert_true(p.skin_id.byte_length() == 36)
    var back = protocol_to_skin(p)
    assert_equal(back.bounds()[0], 64)
    assert_equal(back.pix[0], 7)
    assert_equal(back.model_config.default, "geometry.humanoid.custom")
    assert_equal(back.animations[0].frame_count, 3)
    assert_equal(back.animations[0].type(), ANIMATION_BODY_32X32)
    var bad = p.copy()
    bad.skin_id = ""
    with assert_raises():
        _ = protocol_to_skin(bad)
    bad = p.copy()
    bad.skin_geometry = List[UInt8]("[]".as_bytes())
    with assert_raises():
        _ = protocol_to_skin(bad)
    bad = p.copy()
    bad.skin_resource_patch = List[UInt8]("nope".as_bytes())
    with assert_raises():
        _ = protocol_to_skin(bad)
    bad = p.copy()
    bad.animations[0].animation_type = 9
    with assert_raises():
        _ = protocol_to_skin(bad)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
