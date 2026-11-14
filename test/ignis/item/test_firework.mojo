from ignis.item.colour import Colour
from ignis.item.firework import Firework
from ignis.item.firework_explosion import FireworkExplosion
from ignis.item.firework_shape import FireworkShape
from ignis.item.firework_star import FireworkStar
from minecraft.nbt.tree import Tree
from std.testing import TestSuite, assert_equal, assert_true


def test_flight() raises:
    # Creative inventory rockets carry Flight 1 to 3.
    for ticks in range(1, 4):
        var t = Tree()
        var fw = t.put_compound(t.root(), "Fireworks")
        _ = t.put_list(fw, "Explosions")
        _ = t.put_byte(fw, "Flight", UInt8(ticks))
        var f = Firework().decode_nbt(t, t.root())
        assert_equal(f.duration, (ticks * 50 + 50) * 10)
        var out = Tree()
        f.encode_nbt(out, out.root())
        var c = out.get_compound(out.root(), "Fireworks")
        assert_equal(Int(out.get_byte(c, "Flight")), ticks)
    # Go: uint8((0/10 - 50ms).Milliseconds() / 50) == uint8(-1).
    var zero = Tree()
    Firework().encode_nbt(zero, zero.root())
    var c = zero.get_compound(zero.root(), "Fireworks")
    assert_equal(Int(zero.get_byte(c, "Flight")), 255)


def test_explosion_round_trip() raises:
    var e = FireworkExplosion(
        shape=FireworkShape.CREEPER_HEAD,
        colour=Colour.RED,
        fade=Colour.BLUE,
        fades=True,
        trail=True,
    )
    var f = Firework(duration=1500, explosions=[e, FireworkExplosion()])
    var t = Tree()
    f.encode_nbt(t, t.root())
    var back = Firework().decode_nbt(t, t.root())
    assert_true(back == f)


def test_star() raises:
    var s = FireworkStar(
        firework_explosion=FireworkExplosion(colour=Colour.WHITE)
    )
    assert_equal(s.encode_item().meta, 15)
    var t = Tree()
    s.encode_nbt(t, t.root())
    # int32FromRGBA(0xf0f0f0ff) == 0xfff0f0f0.
    assert_equal(Int(t.get_int(t.root(), "customColor")), -986896)
    var item = t.get_compound(t.root(), "FireworksItem")
    assert_equal(t.get_byte_array(item, "FireworkColor")[0], 15)
    assert_equal(len(t.get_byte_array(item, "FireworkFade")), 0)
    for it in FireworkStar.all_items():
        assert_true(FireworkStar.from_hash(it.hash()) == it)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
