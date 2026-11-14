"""Checks the model of every block against Dragonfly
(`test/data/world/models.txt` from `interop/world`): the solid faces and
the boxes with air, stone, the same block and a mix of connecting blocks
around it."""

from ignis.block.cube.bbox import BBox
from ignis.block.cube.face import Face, faces, horizontal_faces
from ignis.block.cube.pos import Pos
from ignis.block.cube.trace.block import block_intercept, block_intersects
from ignis.block.hash import AnyBlock
from ignis.block.model.bamboo import Bamboo
from ignis.block.model.solid import FULL
from ignis.block.register import (
    block_model_bbox,
    block_model_face_solid,
    vanilla_block_registry,
)
from ignis.block.stone import Stone
from ignis.world.block_registry import UNKNOWN_KIND
from std.collections import Dict
from std.testing import TestSuite, assert_equal, assert_true
from support.block_source import FixedSource
from support.go_values import Tokens, b01, box_s, read_lines, vec_s

comptime _MODEL_POS = Pos(3, 64, -7)


def _ids(boxes: List[BBox], table: Dict[String, Int]) raises -> String:
    var out = List[String]()
    for b in boxes:
        var k = box_s(b)
        if k in table:
            out.append(String(table[k]))
        else:
            out.append("?" + k)
    return String(";").join(out)


def test_models_match_dragonfly() raises:
    var src = FixedSource(vanilla_block_registry())
    var stone = src.br.block_runtime_id(Stone())
    var table = Dict[String, Int]()
    var mixed = List[UInt32]()
    var checked = 0
    var traced = 0
    for line in read_lines("test/data/world/models.txt"):
        var p = line.split("\t")
        if p[0] == "box":
            table[String(p[2])] = Int(p[1])
            continue
        if p[0] == "mixed":
            for r in p[1].split(","):
                mixed.append(UInt32(Int(r)))
            continue
        if p[0] == "trace":
            var rid = UInt32(Int(p[1]))
            var b = AnyBlock(
                kind=src.br.kind(rid), state=src.br.state_hash(rid)
            )
            src.blocks.clear()
            var hf = horizontal_faces()
            for i in range(4):
                src.blocks[_MODEL_POS.side(hf[i])] = mixed[i]
            var ray = Tokens(p[2])
            var start = ray.vec()
            var end = ray.vec()
            var res = String("0")
            if case .Some(r) = block_intercept(_MODEL_POS, src, b, start, end):
                assert_true(r.block_position() == _MODEL_POS)
                res = String(
                    t"1,{vec_s(r.position())},{Int(r.face())},{box_s(r.bbox())}"
                )
            var hit = b01(block_intersects(_MODEL_POS, src, b, start, end))
            assert_equal(hit + "\t" + res, String(p[3]) + "\t" + String(p[4]))
            traced += 1
            continue
        if p[0] == "bamboo":
            var c = p[1].split(",")
            var pos = Pos(Int(c[0]), Int(c[1]), Int(c[2]))
            src.blocks.clear()
            var got = _ids(Bamboo(thick=p[2] == "1").bbox(pos, src), table)
            assert_equal(got, String(p[3]), String(t"bamboo at {pos}"))
            continue
        var rid = UInt32(Int(p[1]))
        var b = AnyBlock(kind=src.br.kind(rid), state=src.br.state_hash(rid))
        src.blocks.clear()
        var mask = 0
        for f in faces():
            if block_model_face_solid(b, _MODEL_POS, f, src):
                mask |= 1 << Int(f)
        var air = _ids(block_model_bbox(b, _MODEL_POS, src), table)
        for f in faces():
            src.blocks[_MODEL_POS.side(f)] = stone
        var on_stone = _ids(block_model_bbox(b, _MODEL_POS, src), table)
        src.blocks.clear()
        for f in horizontal_faces():
            src.blocks[_MODEL_POS.side(f)] = rid
        var same = _ids(block_model_bbox(b, _MODEL_POS, src), table)
        src.blocks.clear()
        var hf = horizontal_faces()
        for i in range(4):
            src.blocks[_MODEL_POS.side(hf[i])] = mixed[i]
        var on_mixed = _ids(block_model_bbox(b, _MODEL_POS, src), table)
        var got = String(t"{mask}\t{air}\t{on_stone}\t{same}\t{on_mixed}")
        if p[2] == "x":
            # Dragonfly's registered shulker boxes have no lid progress
            # counter and its Model panics; Ignis treats the lid as closed.
            var full = String(table[box_s(FULL)])
            assert_equal(got, String(t"0\t{full}\t{full}\t{full}\t{full}"))
        else:
            var want = String("\t").join(p[3:])
            assert_equal(got, want, String(t"rid {rid} ({p[2]})"))
        checked += 1
    assert_equal(checked, 15313)
    assert_equal(traced, 50)


def test_unknown_blocks_are_full_cubes() raises:
    var src = FixedSource(vanilla_block_registry())
    var b = AnyBlock(kind=UNKNOWN_KIND, state=0)
    var boxes = block_model_bbox(b, _MODEL_POS, src)
    assert_equal(len(boxes), 1)
    assert_true(boxes[0] == FULL)
    assert_true(block_model_face_solid(b, _MODEL_POS, Face.UP, src))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
