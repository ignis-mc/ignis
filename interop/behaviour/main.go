// Command behaviour writes test vectors for Ignis's world-driven block
// behaviour from Dragonfly v0.11.6: it builds small worlds, runs Dragonfly's
// own ticks on them (a synchronous world with a seeded PCG) and records the
// blocks of a region at fixed ticks.
//
// Usage (from the repository root):
//
//	(cd interop/behaviour && go run . -out ../../test/data/behaviour)
package main

import (
	"flag"
	"fmt"
	"math/rand/v2"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/df-mc/dragonfly/server/block"
	"github.com/df-mc/dragonfly/server/block/cube"
	"github.com/df-mc/dragonfly/server/entity"
	"github.com/df-mc/dragonfly/server/world"
	"github.com/df-mc/dragonfly/server/world/biome"
	"github.com/df-mc/dragonfly/server/world/generator"
)

var br = world.DefaultBlockRegistry

// scenario is a world set up by setup and ticked; the blocks in [lo, hi]
// are written after each checkpoint tick.
type scenario struct {
	name        string
	speed       int
	setup       func(tx *world.Tx)
	checkpoints []int
	lo, hi      cube.Pos
}

func main() {
	out := flag.String("out", "../../test/data/behaviour", "output directory")
	flag.Parse()
	br.Finalize()
	if err := os.MkdirAll(*out, 0o755); err != nil {
		panic(err)
	}
	write(filepath.Join(*out, "liquids.txt"), liquidScenarios())
}

func write(path string, scenarios []scenario) {
	var b strings.Builder
	for _, s := range scenarios {
		run(&b, s)
	}
	if err := os.WriteFile(path, []byte(b.String()), 0o644); err != nil {
		panic(err)
	}
}

// flat is Ignis's test world: grass on dirt on bedrock, the grass at y=-62.
func flat() world.Generator {
	return generator.NewFlat(biome.Plains{}, []world.Block{block.Grass{}, block.Dirt{}, block.Bedrock{}})
}

func run(b *strings.Builder, s scenario) {
	w := world.Config{
		Synchronous:     true,
		RandSource:      rand.NewPCG(1, 2),
		Generator:       flat(),
		RandomTickSpeed: s.speed,
		Entities:        entity.DefaultRegistry,
	}.New()
	w.Do(s.setup)
	tick := 0
	for _, cp := range s.checkpoints {
		for ; tick < cp; tick++ {
			w.AdvanceTick()
		}
		w.Do(func(tx *world.Tx) { dump(b, s, tick, tx) })
	}
}

// base is the block of the flat world at a height: grass, dirt, bedrock, air.
func base(y int) uint32 {
	switch y {
	case -62:
		return br.BlockRuntimeID(block.Grass{})
	case -63:
		return br.BlockRuntimeID(block.Dirt{})
	case -64:
		return br.BlockRuntimeID(block.Bedrock{})
	}
	return br.AirRuntimeID()
}

// dump writes "scenario tick x,y,z layer rid state" for every block of the
// region that differs from the flat world, then the number of entities.
func dump(b *strings.Builder, s scenario, tick int, tx *world.Tx) {
	for y := s.lo[1]; y <= s.hi[1]; y++ {
		for z := s.lo[2]; z <= s.hi[2]; z++ {
			for x := s.lo[0]; x <= s.hi[0]; x++ {
				pos := cube.Pos{x, y, z}
				b0 := tx.Block(pos)
				rid := br.BlockRuntimeID(b0)
				if rid != base(y) {
					line(b, s, tick, pos, 0, rid)
				}
				if _, ok := b0.(world.Liquid); ok {
					continue
				}
				if l, ok := tx.Liquid(pos); ok {
					line(b, s, tick, pos, 1, br.BlockRuntimeID(l))
				}
			}
		}
	}
	n := 0
	for range tx.Entities() {
		n++
	}
	fmt.Fprintf(b, "%s\t%d\tentities\t%d\n", s.name, tick, n)
}

func line(b *strings.Builder, s scenario, tick int, pos cube.Pos, layer int, rid uint32) {
	fmt.Fprintf(b, "%s\t%d\t%d,%d,%d\t%d\t%d\t%s\n", s.name, tick, pos[0], pos[1], pos[2], layer, rid, state(rid))
}

// state renders a runtime ID as name{key=value,...} with sorted keys.
func state(rid uint32) string {
	name, props, _ := br.RuntimeIDToState(rid)
	keys := make([]string, 0, len(props))
	for k := range props {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	parts := make([]string, len(keys))
	for i, k := range keys {
		parts[i] = fmt.Sprintf("%s=%v", k, props[k])
	}
	return name + "{" + strings.Join(parts, ",") + "}"
}
