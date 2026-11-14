package main

import (
	"fmt"
	"math/rand/v2"
	"os"
	"strings"

	"github.com/df-mc/dragonfly/server/block/cube"
	"github.com/df-mc/dragonfly/server/entity"
	"github.com/df-mc/dragonfly/server/world"
)

// writeLight writes "x,y,z sky block" for every position of the region
// whose light differs from the flat world (sky 15 above the grass, 0 in it
// and below, no block light), after loading chunks -2..2 in x-major order.
func writeLight(path string) {
	w := world.Config{
		Synchronous:     true,
		RandSource:      rand.NewPCG(1, 2),
		Generator:       featureFlat{flat: flat(), placements: lightFeatures()},
		RandomTickSpeed: -1,
		Entities:        entity.DefaultRegistry,
	}.New()
	var b strings.Builder
	w.Do(func(tx *world.Tx) {
		for cx := -2; cx <= 2; cx++ {
			for cz := -2; cz <= 2; cz++ {
				tx.Block(cube.Pos{cx << 4, 0, cz << 4})
			}
		}
		for y := -63; y <= -52; y++ {
			for z := -8; z <= 24; z++ {
				for x := -8; x <= 31; x++ {
					pos := cube.Pos{x, y, z}
					sky, bl := tx.SkyLight(pos), tx.BlockLight(pos)
					wantSky := uint8(0)
					if y > -62 {
						wantSky = 15
					}
					if sky != wantSky || bl != 0 {
						fmt.Fprintf(&b, "%d,%d,%d\t%d\t%d\n", x, y, z, sky, bl)
					}
				}
			}
		}
	})
	if err := os.WriteFile(path, []byte(b.String()), 0o644); err != nil {
		panic(err)
	}
}
