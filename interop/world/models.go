package main

import (
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"

	"github.com/df-mc/dragonfly/server/block"
	"github.com/df-mc/dragonfly/server/block/cube"
	"github.com/df-mc/dragonfly/server/block/cube/trace"
	"github.com/df-mc/dragonfly/server/block/model"
	"github.com/df-mc/dragonfly/server/world"
	"github.com/go-gl/mathgl/mgl64"
)

// fixedSource is a world.BlockSource with a few blocks set and air
// everywhere else.
type fixedSource map[cube.Pos]world.Block

func (s fixedSource) Block(pos cube.Pos) world.Block {
	if b, ok := s[pos]; ok {
		return b
	}
	return block.Air{}
}

// modelPos is where every block is placed; the model of bamboo depends on
// it.
var modelPos = cube.Pos{3, 64, -7}

// modelVectors writes models.txt. "box" lines number the distinct boxes;
// "mixed" gives the runtime IDs of the blocks north, east, south and west
// of the block in the mixed neighbourhood; each "model" line is
// "rid type facesolid air stone same mixed": the solid faces as a bit mask
// (bit i for cube.Face(i), with air around) and, for each neighbourhood,
// the box numbers of BBox(modelPos, src) separated by ";" ("x" if Go
// panicked). The neighbourhoods: air everywhere; stone on all six sides;
// the same block on the four horizontal sides; and mixed.
func modelVectors(out string) {
	boxes := map[string]int{}
	var boxLines strings.Builder
	boxID := func(b cube.BBox) string {
		k := boxS(b)
		id, ok := boxes[k]
		if !ok {
			id = len(boxes)
			boxes[k] = id
			fmt.Fprintf(&boxLines, "box\t%d\t%s\n", id, k)
		}
		return fmt.Sprint(id)
	}
	bboxes := func(m world.BlockModel, src world.BlockSource) (s string) {
		defer func() {
			if recover() != nil {
				s = "x"
			}
		}()
		var ids []string
		for _, b := range m.BBox(modelPos, src) {
			ids = append(ids, boxID(b))
		}
		return strings.Join(ids, ";")
	}
	modelOf := func(b world.Block) (m world.BlockModel, name string) {
		defer func() {
			if recover() != nil {
				m, name = nil, "x"
			}
		}()
		m = b.Model()
		return m, reflect.TypeOf(m).Name()
	}
	horizontal := []cube.Face{cube.FaceNorth, cube.FaceEast, cube.FaceSouth, cube.FaceWest}
	stone := fixedSource{}
	for _, f := range cube.Faces() {
		stone[modelPos.Side(f)] = block.Stone{}
	}
	mixedBlocks := []world.Block{
		block.WoodFenceGate{Wood: block.OakWood(), Facing: cube.East},
		block.Wall{Block: block.Cobblestone{}, Post: true},
		block.GlassPane{},
		block.WoodFence{Wood: block.OakWood()},
	}
	mixed := fixedSource{}
	var mixedRIDs []string
	for i, f := range horizontal {
		mixed[modelPos.Side(f)] = mixedBlocks[i]
		mixedRIDs = append(mixedRIDs, fmt.Sprint(br.BlockRuntimeID(mixedBlocks[i])))
	}

	var lines strings.Builder
	lines.WriteString("mixed\t" + strings.Join(mixedRIDs, ",") + "\n")
	for rid := uint32(0); rid < uint32(br.BlockCount()); rid++ {
		b, _ := br.BlockByRuntimeID(rid)
		if reflect.TypeOf(b).Name() == "unknownBlock" {
			continue
		}
		m, name := modelOf(b)
		if m == nil {
			fmt.Fprintf(&lines, "model\t%d\t%s\tx\tx\tx\tx\tx\n", rid, name)
			continue
		}
		mask := 0
		for f := cube.Face(0); f < 6; f++ {
			if m.FaceSolid(modelPos, f, fixedSource{}) {
				mask |= 1 << f
			}
		}
		same := fixedSource{}
		for _, f := range horizontal {
			same[modelPos.Side(f)] = b
		}
		fmt.Fprintf(&lines, "model\t%d\t%s\t%d\t%s\t%s\t%s\t%s\n", rid, name, mask,
			bboxes(m, fixedSource{}), bboxes(m, stone), bboxes(m, same), bboxes(m, mixed))
	}
	// Bamboo at other positions, for the random offset.
	for _, p := range []cube.Pos{{0, 0, 0}, {1, 2, 3}, {-17, 70, 255}, {123456, -5, -98765}, {-1, 0, -1}, {2147483647, 0, -2147483648}} {
		for _, thick := range []bool{false, true} {
			fmt.Fprintf(&lines, "bamboo\t%d,%d,%d\t%s\t%s\n", p[0], p[1], p[2], boolS(thick),
				boxID(model.Bamboo{Thick: thick}.BBox(p, nil)[0]))
		}
	}
	// Rays through blocks in the mixed neighbourhood: "trace rid start end
	// intersects hit", hit being "0" or "1,position,face,box".
	traced := []world.Block{
		block.Stone{}, block.Air{}, block.Slab{Block: block.Planks{}, Top: true},
		block.Stairs{Block: block.Planks{}, Facing: cube.East, Corner: block.OuterLeftStairsCorner()},
		block.WoodFence{Wood: block.OakWood()}, block.GlassPane{}, block.Wall{Block: block.Cobblestone{}},
		block.Hopper{Facing: cube.FaceDown}, block.Flower{}, block.Composter{Level: 3},
	}
	at := modelPos.Vec3()
	rays := [][2]mgl64.Vec3{
		{at.Add(mgl64.Vec3{-1, 0.5, 0.5}), at.Add(mgl64.Vec3{2, 0.5, 0.5})},
		{at.Add(mgl64.Vec3{0.5, 3, 0.5}), at.Add(mgl64.Vec3{0.5, -1, 0.5})},
		{at.Add(mgl64.Vec3{0.1, 1.4, -0.5}), at.Add(mgl64.Vec3{0.9, 0.2, 1.5})},
		{at.Add(mgl64.Vec3{0.45, 0.95, 2}), at.Add(mgl64.Vec3{0.45, 0.95, -1})},
		{at.Add(mgl64.Vec3{3, 3, 3}), at.Add(mgl64.Vec3{4, 4, 4})},
	}
	for _, b := range traced {
		rid := br.BlockRuntimeID(b)
		for _, ray := range rays {
			res := "0"
			if r, ok := trace.BlockIntercept(modelPos, mixed, b, ray[0], ray[1]); ok {
				res = "1," + vecS(r.Position()) + "," + fmt.Sprint(int(r.Face())) + "," + boxS(r.BBox())
				if r.BlockPosition() != modelPos {
					panic("block position")
				}
			}
			fmt.Fprintf(&lines, "trace\t%d\t%s,%s\t%s\t%s\n", rid, vecS(ray[0]), vecS(ray[1]),
				boolS(trace.BlockIntersects(modelPos, mixed, b, ray[0], ray[1])), res)
		}
	}
	must(os.WriteFile(filepath.Join(out, "models.txt"), []byte(boxLines.String()+lines.String()), 0o644))
}
