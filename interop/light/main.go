// Command light writes test vectors for Ignis's light engine from Dragonfly
// v0.11.6 (`server/world/chunk/light.go`, `light_area.go`) and checks them
// against a real Dragonfly world.
//
// Each scenario places blocks in a square of chunks, loads the chunks in a
// fixed order the way `World.loadChunk` and `World.addChunk` do (`Fill` per
// chunk, then `Spread` for every chunk whose 3x3 neighbourhood is complete),
// and writes an FNV-1a 64 hash of every sub-chunk's sky and block light
// arrays plus the light at a few probe positions.
//
// Dragonfly v0.11.6 does not relight when blocks change: `Tx.SetBlock` leaves
// the light as it was until the chunk is loaded again. For each step of block
// changes the vectors hold the light Dragonfly computes when it loads the
// changed chunks afresh in the same order, which is what Ignis's incremental
// relighting must reproduce. The program checks that each such result is a
// fixed point of Dragonfly's propagation rule, so that it is the only answer
// an incremental engine can give.
//
// Usage (from the repository root):
//
//	(cd interop/light && go run . -out ../../test/data/light)
package main

import (
	"encoding/binary"
	"flag"
	"fmt"
	"hash/fnv"
	"math/rand/v2"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/df-mc/dragonfly/server/block"
	"github.com/df-mc/dragonfly/server/block/cube"
	"github.com/df-mc/dragonfly/server/world"
	"github.com/df-mc/dragonfly/server/world/chunk"
)

var (
	br = finalized()
	ra = world.Overworld.Range()
)

func finalized() *world.BasicBlockRegistry {
	world.DefaultBlockRegistry.Finalize()
	return world.DefaultBlockRegistry
}

func rid(b world.Block) uint32 { return br.BlockRuntimeID(b) }

var (
	air       = rid(block.Air{})
	stone     = rid(block.Stone{})
	dirt      = rid(block.Dirt{})
	grass     = rid(block.Grass{})
	bedrock   = rid(block.Bedrock{})
	glass     = rid(block.Glass{})
	glowstone = rid(block.Glowstone{})
	torch     = rid(block.Torch{Facing: cube.FaceDown, Type: block.NormalFire()})
	soulTorch = rid(block.Torch{Facing: cube.FaceDown, Type: block.SoulFire()})
	lantern   = rid(block.Lantern{Type: block.NormalFire()})
	water     = rid(block.Water{Still: true, Depth: 8})
	lava      = rid(block.Lava{Still: true, Depth: 8})
	leaves    = rid(block.Leaves{Type: block.OakLeaves(), Persistent: true})
	ice       = rid(block.Ice{})
	light7    = rid(block.Light{Level: 7})
	light15   = rid(block.Light{Level: 15})
)

// op is a box of blocks: every position from (x0, y0, z0) to (x1, y1, z1)
// inclusive; with sphere set, every position within radius r of
// (x0, y0, z0); with heights set, a row of terrain columns (see columns).
type op struct {
	x0, y0, z0, x1, y1, z1 int
	layer                  uint8
	rid                    uint32
	sphere                 bool
	r                      int
	heights                []int
}

// columns is a row of terrain columns at x from z0 on: stone from just above
// the bottom of the world, two dirt and grass on top, or water up to y 54
// over columns lower than 55.
func columns(x, z0 int, heights []int) op {
	return op{x0: x, z0: z0, heights: heights}
}

func fill(x0, y0, z0, x1, y1, z1 int, rid uint32) op {
	return op{x0: x0, y0: y0, z0: z0, x1: x1, y1: y1, z1: z1, rid: rid}
}

func fillLayer(x0, y0, z0, x1, y1, z1 int, layer uint8, rid uint32) op {
	o := fill(x0, y0, z0, x1, y1, z1, rid)
	o.layer = layer
	return o
}

func set(x, y, z int, rid uint32) op { return fill(x, y, z, x, y, z, rid) }

func sphere(x, y, z, r int, rid uint32) op {
	return op{x0: x, y0: y, z0: z, x1: x, y1: y, z1: z, rid: rid, sphere: true, r: r}
}

func (o op) line() string {
	if o.heights != nil {
		var b strings.Builder
		fmt.Fprintf(&b, "columns %d %d %d %d %d %d", o.x0, o.z0, stone, dirt, grass, water)
		for _, h := range o.heights {
			fmt.Fprintf(&b, " %d", h)
		}
		return b.String()
	}
	if o.sphere {
		return fmt.Sprintf("sphere %d %d %d %d %d", o.x0, o.y0, o.z0, o.r, o.rid)
	}
	return fmt.Sprintf("fill %d %d %d %d %d %d %d %d", o.x0, o.y0, o.z0, o.x1, o.y1, o.z1, o.layer, o.rid)
}

// each calls f for every position of the op, x outermost, then y, then z.
func (o op) each(f func(x, y, z int, rid uint32)) {
	if o.heights != nil {
		for i, h := range o.heights {
			z := o.z0 + i
			for y := ra.Min() + 1; y <= max(h, 54); y++ {
				switch {
				case y <= h-3:
					f(o.x0, y, z, stone)
				case y <= h-1:
					f(o.x0, y, z, dirt)
				case y == h && h >= 55:
					f(o.x0, y, z, grass)
				case y >= h && h < 55:
					f(o.x0, y, z, water)
				}
			}
		}
		return
	}
	if o.sphere {
		for x := o.x0 - o.r; x <= o.x0+o.r; x++ {
			for y := o.y0 - o.r; y <= o.y0+o.r; y++ {
				for z := o.z0 - o.r; z <= o.z0+o.r; z++ {
					dx, dy, dz := x-o.x0, y-o.y0, z-o.z0
					if dx*dx+dy*dy+dz*dz <= o.r*o.r {
						f(x, y, z, o.rid)
					}
				}
			}
		}
		return
	}
	for x := o.x0; x <= o.x1; x++ {
		for y := o.y0; y <= o.y1; y++ {
			for z := o.z0; z <= o.z1; z++ {
				f(x, y, z, o.rid)
			}
		}
	}
}

type scenario struct {
	name  string
	order []world.ChunkPos
	build []op
	steps [][]op
	probe []cube.Pos
}

// area is the chunks from (x0, z0) to (x1, z1) inclusive, row by row.
func area(x0, z0, x1, z1 int32) []world.ChunkPos {
	var out []world.ChunkPos
	for z := z0; z <= z1; z++ {
		for x := x0; x <= x1; x++ {
			out = append(out, world.ChunkPos{x, z})
		}
	}
	return out
}

// bounds returns the block range covered by the chunks.
func bounds(order []world.ChunkPos) (x0, z0, x1, z1 int) {
	x0, z0, x1, z1 = 1<<30, 1<<30, -(1 << 30), -(1 << 30)
	for _, p := range order {
		x0, z0 = min(x0, int(p[0])<<4), min(z0, int(p[1])<<4)
		x1, z1 = max(x1, int(p[0])<<4+15), max(z1, int(p[1])<<4+15)
	}
	return
}

// ground fills every chunk with stone (bedrock at the bottom) up to top.
func ground(order []world.ChunkPos, top int) []op {
	x0, z0, x1, z1 := bounds(order)
	return []op{
		fill(x0, ra.Min(), z0, x1, ra.Min(), z1, bedrock),
		fill(x0, ra.Min()+1, z0, x1, top, z1, stone),
	}
}

func scenarios() []scenario {
	var out []scenario

	// Dragonfly's flat world: bedrock, two dirt and grass.
	{
		order := area(-1, -1, 1, 1)
		x0, z0, x1, z1 := bounds(order)
		s := scenario{name: "flat", order: order}
		s.build = []op{
			fill(x0, -64, z0, x1, -64, z1, bedrock),
			fill(x0, -63, z0, x1, -62, z1, dirt),
			fill(x0, -61, z0, x1, -61, z1, grass),
		}
		s.steps = [][]op{
			{fill(-6, -50, -6, 9, -50, 9, stone)},
			{set(1, -60, 1, torch), set(14, -60, 3, lantern)},
			{fill(0, -50, 0, 3, -50, 3, air)},
			{fill(5, -63, 5, 6, -61, 6, air), set(7, -61, 7, glass)},
		}
		s.probe = []cube.Pos{{0, -60, 0}, {1, -60, 1}, {4, -55, 4}, {20, -60, 20}, {0, -50, 0}, {5, -63, 5}}
		out = append(out, s)
	}

	// A hill with an overhang across chunk borders, a cave reached by a
	// shaft and a sealed cave.
	{
		order := area(-1, -1, 1, 1)
		s := scenario{name: "overhang", order: order}
		s.build = append(ground(order, 60),
			fill(-8, 70, -4, 20, 72, 12, stone),
			fill(2, 40, 2, 12, 50, 12, air),
			fill(7, 51, 7, 7, 60, 7, air),
			fill(-12, 30, -12, -4, 36, -4, air),
			fill(-14, 61, 18, -10, 75, 22, stone),
		)
		s.steps = [][]op{
			{fill(0, 70, 0, 4, 72, 4, air)},
			{set(7, 60, 7, stone)},
			{fill(-4, 33, -6, 2, 34, -6, air), fill(2, 33, -6, 2, 34, 2, air)},
			{fill(-8, 70, -4, 20, 72, 12, air)},
		}
		s.probe = []cube.Pos{{0, 61, 0}, {7, 45, 7}, {-8, 33, -8}, {10, 65, 10}, {-12, 65, 17}}
		out = append(out, s)
	}

	// Torches, glowstone, lanterns, light blocks and lava in sealed rooms.
	{
		order := area(-1, -1, 1, 1)
		s := scenario{name: "emitters", order: order}
		s.build = append(ground(order, 60),
			fill(-6, 20, 3, 21, 30, 9, air),
			set(5, 20, 5, torch),
			set(10, 31, 6, glowstone),
			set(18, 25, 3, soulTorch),
			set(-5, 22, 8, light7),
			fill(-10, 5, -10, -2, 8, -2, air),
			fill(-9, 5, -9, -3, 5, -3, lava),
			set(-6, 8, -6, lantern),
			set(3, 61, 3, torch),
			set(12, 40, 12, light15),
			set(-16, 50, 15, glowstone),
		)
		s.steps = [][]op{
			{set(5, 20, 5, air)},
			{set(5, 20, 5, glowstone), set(10, 31, 6, stone)},
			{fill(-6, 24, 2, -6, 26, 2, air), fill(-6, 24, -1, -6, 26, 1, air)},
			{fill(-9, 5, -9, -3, 5, -3, stone), set(18, 25, 3, stone)},
			{fill(0, 21, 4, 0, 61, 4, air)},
		}
		s.probe = []cube.Pos{{5, 21, 5}, {0, 25, 6}, {16, 25, 6}, {-6, 6, -6}, {3, 62, 3}, {12, 41, 12}, {0, 40, 4}}
		out = append(out, s)
	}

	// Light passing through water, ice and leaves, including leaves with
	// water on the second layer, and water and leaves above the height map.
	{
		order := area(-1, -1, 1, 1)
		s := scenario{name: "diffusion", order: order}
		s.build = append(ground(order, 60),
			fill(0, 30, 0, 14, 34, 4, air),
			fill(1, 30, 0, 14, 33, 4, water),
			set(0, 30, 2, glowstone),
			fill(-10, 30, -10, -2, 34, -2, air),
			fill(-6, 30, -10, -6, 34, -2, leaves),
			set(-9, 30, -6, torch),
			fill(-4, 30, -10, -4, 34, -2, leaves),
			fillLayer(-4, 30, -10, -4, 34, -2, 1, water),
			fill(4, 50, 4, 12, 60, 12, air),
			fill(4, 50, 4, 12, 58, 12, water),
			fill(-12, 70, 4, -4, 73, 12, leaves),
			fill(20, 80, -8, 28, 80, 0, water),
			fill(2, 40, -12, 10, 44, -6, air),
			fill(2, 40, -9, 10, 44, -9, ice),
			set(6, 40, -12, light15),
			fill(18, 30, 18, 24, 34, 24, air),
			fill(18, 34, 18, 24, 34, 24, glass),
			fill(18, 35, 18, 24, 60, 24, air),
		)
		s.steps = [][]op{
			{fill(5, 30, 0, 5, 33, 4, air)},
			{fill(-6, 30, -10, -6, 34, -2, air)},
			{set(-9, 30, -6, air), set(-2, 30, -6, torch)},
			{fill(2, 40, -9, 10, 44, -9, water)},
			{fill(18, 34, 18, 24, 34, 24, leaves)},
		}
		s.probe = []cube.Pos{{1, 30, 2}, {14, 33, 2}, {-5, 32, -6}, {-3, 32, -6}, {8, 52, 8}, {-8, 65, 8}, {6, 42, -6}, {20, 31, 20}}
		out = append(out, s)
	}

	// Light sources at chunk borders and corners, in a 4x4 area loaded out
	// of order so that Spread runs for several areas.
	{
		order := []world.ChunkPos{{1, 1}, {-2, -2}, {0, 0}, {1, -2}, {-1, 0}, {0, -1}, {-2, 1}, {1, 0}, {-1, -1}, {0, 1}, {-2, 0}, {-1, 1}, {1, -1}, {0, -2}, {-2, -1}, {-1, -2}}
		s := scenario{name: "border", order: order}
		s.build = append(ground(order, 60),
			fill(-12, 20, -12, 12, 26, 12, air),
			set(-1, 20, -1, light15),
			set(15, 22, 0, torch),
			set(0, 24, 15, glowstone),
			fill(-28, 40, -20, 12, 42, -18, air),
			set(-16, 40, -19, torch),
			set(-17, 41, -19, lantern),
			fill(-30, 61, 0, -2, 61, 0, glass),
			fill(-20, 50, 10, 4, 62, 14, air),
		)
		s.steps = [][]op{
			{set(-1, 20, -1, air)},
			{set(0, 20, 0, light15)},
			{fill(-16, 40, -20, -16, 42, -18, stone)},
			{fill(-1, 27, -1, 0, 60, 0, air)},
		}
		s.probe = []cube.Pos{{-1, 21, -1}, {16, 22, 0}, {0, 24, 16}, {-15, 40, -19}, {-1, 30, -1}, {-10, 55, 12}}
		out = append(out, s)
	}

	// Random terrain: hills, caves, a sea, trees and light sources.
	{
		order := area(-2, -2, 2, 2)
		rnd := rand.New(rand.NewPCG(7, 11))
		rnd.Shuffle(len(order), func(i, j int) { order[i], order[j] = order[j], order[i] })
		x0, z0, x1, z1 := bounds(order)
		s := scenario{name: "terrain", order: order}
		s.build = []op{fill(x0, ra.Min(), z0, x1, ra.Min(), z1, bedrock)}
		for x := x0; x <= x1; x++ {
			var heights []int
			for z := z0; z <= z1; z++ {
				h := 56 + (x*x+z*z)%7 + (x/5+z/7)%5
				if (x/9+z/11)%3 == 0 {
					h -= 8
				}
				heights = append(heights, h)
			}
			s.build = append(s.build, columns(x, z0, heights))
		}
		for i := 0; i < 40; i++ {
			cx, cy, cz := x0+rnd.IntN(x1-x0+1), 10+rnd.IntN(45), z0+rnd.IntN(z1-z0+1)
			s.build = append(s.build, sphere(cx, cy, cz, 2+rnd.IntN(5), air))
		}
		emitters := []uint32{torch, glowstone, lantern, light7, lava, soulTorch}
		for i := 0; i < 60; i++ {
			s.build = append(s.build, set(x0+rnd.IntN(x1-x0+1), 5+rnd.IntN(60), z0+rnd.IntN(z1-z0+1), emitters[rnd.IntN(len(emitters))]))
		}
		for i := 0; i < 12; i++ {
			tx, tz := x0+2+rnd.IntN(x1-x0-3), z0+2+rnd.IntN(z1-z0-3)
			s.build = append(s.build, fill(tx-2, 66, tz-2, tx+2, 69, tz+2, leaves), fill(tx, 60, tz, tx, 67, tz, rid(block.Log{Wood: block.OakWood()})))
		}
		for step := 0; step < 4; step++ {
			var ops []op
			for i := 0; i < 8; i++ {
				blocks := []uint32{air, stone, torch, glowstone, leaves, water, air, air}
				ops = append(ops, set(-16+rnd.IntN(32), 20+rnd.IntN(50), -16+rnd.IntN(32), blocks[rnd.IntN(len(blocks))]))
			}
			s.steps = append(s.steps, ops)
		}
		s.probe = []cube.Pos{{0, 60, 0}, {5, 30, -7}, {-12, 45, 9}, {17, 50, -3}, {-30, 40, 30}}
		out = append(out, s)
	}
	return out
}

// chunks builds the scenario's chunks.
func build(s scenario, ops []op) map[world.ChunkPos]*chunk.Chunk {
	cs := make(map[world.ChunkPos]*chunk.Chunk)
	for _, p := range s.order {
		cs[p] = chunk.New(br, ra)
	}
	apply(cs, ops)
	return cs
}

func apply(cs map[world.ChunkPos]*chunk.Chunk, ops []op) {
	for _, o := range ops {
		o.each(func(x, y, z int, rid uint32) {
			c, ok := cs[world.ChunkPos{int32(x >> 4), int32(z >> 4)}]
			if !ok || y < ra.Min() || y > ra.Max() {
				return
			}
			c.SetBlock(uint8(x), int16(y), uint8(z), o.layer, rid)
		})
	}
}

// light lights the chunks as World.loadChunk and World.addChunk do when they
// are loaded in order.
func light(s scenario, cs map[world.ChunkPos]*chunk.Chunk) {
	loaded := make(map[world.ChunkPos]bool)
	for _, pos := range s.order {
		chunk.LightArea([]*chunk.Chunk{cs[pos]}, int(pos[0]), int(pos[1])).Fill()
		loaded[pos] = true
		for x := int32(-1); x <= 1; x++ {
			for z := int32(-1); z <= 1; z++ {
				p := world.ChunkPos{pos[0] + x, pos[1] + z}
				if loaded[p] {
					spread(cs, loaded, p)
				}
			}
		}
	}
}

func spread(cs map[world.ChunkPos]*chunk.Chunk, loaded map[world.ChunkPos]bool, pos world.ChunkPos) {
	c := make([]*chunk.Chunk, 0, 9)
	for z := int32(-1); z <= 1; z++ {
		for x := int32(-1); x <= 1; x++ {
			p := world.ChunkPos{pos[0] + x, pos[1] + z}
			if !loaded[p] {
				return
			}
			c = append(c, cs[p])
		}
	}
	chunk.LightArea(c, int(pos[0])-1, int(pos[1])-1).Spread()
}

// arrays returns the 2048-byte sky or block light array of every sub-chunk,
// read back nibble by nibble in Dragonfly's layout.
func arrays(c *chunk.Chunk, sky bool) [][]byte {
	var out [][]byte
	for i := range c.Sub() {
		arr := make([]byte, 2048)
		baseY := int(c.SubY(int16(i)))
		for x := 0; x < 16; x++ {
			for z := 0; z < 16; z++ {
				for y := 0; y < 16; y++ {
					var v uint8
					if sky {
						v = c.SkyLight(uint8(x), int16(baseY+y), uint8(z))
					} else {
						v = c.BlockLight(uint8(x), int16(baseY+y), uint8(z))
					}
					index := x<<8 | z<<4 | y
					arr[index>>1] |= v << ((index & 1) << 2)
				}
			}
		}
		out = append(out, arr)
	}
	return out
}

func fnv64(b []byte) uint64 {
	h := fnv.New64a()
	h.Write(b)
	return binary.BigEndian.Uint64(h.Sum(nil))
}

// dump writes, per chunk, the hash of its sky light arrays and of its block
// light arrays (the 2048 bytes of every sub-chunk, lowest first), or with
// -subs one hash per sub-chunk.
func dump(b *strings.Builder, step int, s scenario, cs map[world.ChunkPos]*chunk.Chunk) {
	for _, pos := range s.order {
		fmt.Fprintf(b, "light %d %d %d", step, pos[0], pos[1])
		for _, sky := range []bool{true, false} {
			var all []byte
			for _, arr := range arrays(cs[pos], sky) {
				if *subs {
					fmt.Fprintf(b, " %016x", fnv64(arr))
				}
				all = append(all, arr...)
			}
			if !*subs {
				fmt.Fprintf(b, " %016x", fnv64(all))
			}
		}
		b.WriteString("\n")
	}
	for _, p := range s.probe {
		c := cs[world.ChunkPos{int32(p[0] >> 4), int32(p[2] >> 4)}]
		x, y, z := uint8(p[0]), int16(p[1]), uint8(p[2])
		fmt.Fprintf(b, "probe %d %d %d %d %d %d %d\n", step, p[0], p[1], p[2], c.Light(x, y, z), c.SkyLight(x, y, z), c.BlockLight(x, y, z))
	}
}

// highest is lightArea.highest: the largest value of f over both layers.
func highest(c *chunk.Chunk, x uint8, y int16, z uint8, f func(uint32) uint8) uint8 {
	v := f(c.Block(x, y, z, 0))
	if w := f(c.Block(x, y, z, 1)); w > v {
		return w
	}
	return v
}

// fixedPoint reports positions where light could still spread to a
// neighbour inside the area, which would make the result depend on how it
// was computed.
//
// Fill sets the sky light of the block at a column's height map value to 15
// without spreading it, so that block never lights its neighbours in the same
// chunk (Spread does carry it into other chunks). That edge is left out here,
// as Ignis's incremental relighting leaves it out.
func fixedPoint(s scenario, cs map[world.ChunkPos]*chunk.Chunk) error {
	x0, z0, x1, z1 := bounds(s.order)
	get := func(x, y, z int) (*chunk.Chunk, bool) {
		c, ok := cs[world.ChunkPos{int32(x >> 4), int32(z >> 4)}]
		return c, ok && y >= ra.Min() && y <= ra.Max() && x >= x0 && x <= x1 && z >= z0 && z <= z1
	}
	for x := x0; x <= x1; x++ {
		for z := z0; z <= z1; z++ {
			for y := ra.Min(); y <= ra.Max(); y++ {
				c, _ := get(x, y, z)
				sky, blk := c.SkyLight(uint8(x), int16(y), uint8(z)), c.BlockLight(uint8(x), int16(y), uint8(z))
				atHeight := int(c.HeightMap().At(uint8(x&15), uint8(z&15))) == y
				for _, d := range [][3]int{{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}} {
					nx, ny, nz := x+d[0], y+d[1], z+d[2]
					n, ok := get(nx, ny, nz)
					if !ok {
						continue
					}
					sameChunk := nx>>4 == x>>4 && nz>>4 == z>>4
					filter := highest(n, uint8(nx), int16(ny), uint8(nz), br.FilteringBlock) + 1
					if !(atHeight && d[1] == 0 && sameChunk) && sky > filter && n.SkyLight(uint8(nx), int16(ny), uint8(nz)) < sky-filter {
						return fmt.Errorf("sky light spreads from %v to %v", cube.Pos{x, y, z}, cube.Pos{nx, ny, nz})
					}
					if blk > filter && n.BlockLight(uint8(nx), int16(ny), uint8(nz)) < blk-filter {
						return fmt.Errorf("block light spreads from %v to %v", cube.Pos{x, y, z}, cube.Pos{nx, ny, nz})
					}
				}
			}
		}
	}
	return nil
}

// generator places a scenario's blocks for a real Dragonfly world.
type generator struct {
	cs map[world.ChunkPos]*chunk.Chunk
}

func (g generator) GenerateChunk(pos world.ChunkPos, c *chunk.Chunk) {
	src, ok := g.cs[pos]
	if !ok {
		return
	}
	for i, sub := range src.Sub() {
		baseY := src.SubY(int16(i))
		for layer := range sub.Layers() {
			for x := uint8(0); x < 16; x++ {
				for z := uint8(0); z < 16; z++ {
					for y := uint8(0); y < 16; y++ {
						if b := sub.Block(x, y, z, uint8(layer)); b != air {
							c.SetBlock(x, baseY+int16(y), z, uint8(layer), b)
						}
					}
				}
			}
		}
	}
}

func (generator) DefaultSpawn(world.Dimension) cube.Pos { return cube.Pos{} }

// checkWorld loads the scenario's chunks into a Dragonfly world in order and
// checks that Tx.Light, Tx.SkyLight and Tx.BlockLight agree with cs.
func checkWorld(s scenario, cs map[world.ChunkPos]*chunk.Chunk) {
	blocks := build(s, s.build)
	w := world.Config{Generator: generator{cs: blocks}, Synchronous: true}.New()
	defer w.Close()
	<-w.Do(func(tx *world.Tx) {
		for _, pos := range s.order {
			tx.Block(cube.Pos{int(pos[0]) << 4, 0, int(pos[1]) << 4})
		}
		for _, pos := range s.order {
			c := cs[pos]
			for x := 0; x < 16; x++ {
				for z := 0; z < 16; z++ {
					for y := ra.Min(); y <= ra.Max(); y++ {
						p := cube.Pos{int(pos[0])<<4 + x, y, int(pos[1])<<4 + z}
						ux, uy, uz := uint8(x), int16(y), uint8(z)
						if tx.Light(p) != c.Light(ux, uy, uz) || tx.SkyLight(p) != c.SkyLight(ux, uy, uz) || tx.BlockLight(p) != c.BlockLight(ux, uy, uz) {
							panic(fmt.Sprintf("%s: world light differs at %v", s.name, p))
						}
					}
				}
			}
		}
	}).Done()
}

var subs = flag.Bool("subs", false, "write a hash per sub-chunk (for debugging)")

func main() {
	out := flag.String("out", "../../test/data/light", "output directory")
	bench := flag.Bool("bench", false, "time Fill and Spread instead of writing vectors")
	flag.Parse()
	if *bench {
		runBench()
		return
	}

	var b strings.Builder
	b.WriteString("# Generated by interop/light from Dragonfly v0.11.6; do not edit.\n")
	for _, s := range scenarios() {
		fmt.Fprintf(&b, "scenario %s\n", s.name)
		for _, pos := range s.order {
			fmt.Fprintf(&b, "load %d %d\n", pos[0], pos[1])
		}
		for _, o := range s.build {
			b.WriteString(o.line() + "\n")
		}
		cs := build(s, s.build)
		light(s, cs)
		checkWorld(s, cs)
		if err := fixedPoint(s, cs); err != nil {
			panic(s.name + ": " + err.Error())
		}
		dump(&b, 0, s, cs)

		ops := append([]op(nil), s.build...)
		for i, step := range s.steps {
			fmt.Fprintf(&b, "step %d\n", i+1)
			for _, o := range step {
				b.WriteString(o.line() + "\n")
			}
			ops = append(ops, step...)
			cs := build(s, ops)
			light(s, cs)
			if err := fixedPoint(s, cs); err != nil {
				panic(fmt.Sprintf("%s step %d: %v", s.name, i+1, err))
			}
			dump(&b, i+1, s, cs)
		}
		b.WriteString("end\n")
	}
	if err := os.MkdirAll(*out, 0o755); err != nil {
		panic(err)
	}
	if err := os.WriteFile(filepath.Join(*out, "vectors.txt"), []byte(b.String()), 0o644); err != nil {
		panic(err)
	}
}

// runBench times lighting a chunk column the way a world load does: Fill for
// one chunk, and Spread over a 3x3 area.
func runBench() {
	for _, s := range scenarios() {
		if s.name != "terrain" && s.name != "flat" {
			continue
		}
		base := build(s, s.build)
		pos := world.ChunkPos{0, 0}
		const n = 200
		var fill, spreadT time.Duration
		for i := 0; i < n; i++ {
			cs := make(map[world.ChunkPos]*chunk.Chunk)
			for p, c := range base {
				cs[p] = c.Clone()
			}
			for p, c := range cs {
				if p != pos {
					chunk.LightArea([]*chunk.Chunk{c}, int(p[0]), int(p[1])).Fill()
				}
			}
			start := time.Now()
			chunk.LightArea([]*chunk.Chunk{cs[pos]}, 0, 0).Fill()
			fill += time.Since(start)
			var area []*chunk.Chunk
			for z := int32(-1); z <= 1; z++ {
				for x := int32(-1); x <= 1; x++ {
					area = append(area, cs[world.ChunkPos{x, z}])
				}
			}
			start = time.Now()
			chunk.LightArea(area, -1, -1).Spread()
			spreadT += time.Since(start)
		}
		fmt.Printf("%s: Fill %v per chunk, Spread %v per 3x3 area\n", s.name, fill/n, spreadT/n)
	}
}
