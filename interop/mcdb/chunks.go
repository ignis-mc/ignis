package main

// Chunk builders copied from interop/world/main.go; test/support/world_vectors.mojo
// mirrors them, and mcdb_world.mojo mirrors the nether and end chunks.

import (
	"slices"

	"github.com/df-mc/dragonfly/server/block"
	"github.com/df-mc/dragonfly/server/world"
	"github.com/df-mc/dragonfly/server/world/biome"
	"github.com/df-mc/dragonfly/server/world/chunk"
	"github.com/df-mc/dragonfly/server/world/generator"
)

var br = world.DefaultBlockRegistry

func newChunk() *chunk.Chunk {
	return chunk.New(br, world.Overworld.Range())
}

// rids returns n distinct non-air runtime IDs spread over the registry.
func rids(n int) []uint32 {
	count := uint32(br.BlockCount())
	out := make([]uint32, 0, n)
	for k := uint32(0); len(out) < n; k++ {
		rid := (k*131 + 7) % count
		if rid != br.AirRuntimeID() && !slices.Contains(out, rid) {
			out = append(out, rid)
		}
	}
	return out
}

// mixedChunk fills sub-chunk i with a palette of 2^w entries (air included),
// w being widths[i], and puts a second layer in the last one.
var widths = []int{1, 2, 3, 4, 5, 6, 8, 16}

func mixedChunk() *chunk.Chunk {
	c := newChunk()
	for i, w := range widths {
		d := (1 << w) - 1
		if w == 16 {
			d = 300
		}
		values := rids(d)
		base := c.SubY(int16(i))
		for x := uint8(0); x < 16; x++ {
			for y := uint8(0); y < 16; y++ {
				for z := uint8(0); z < 16; z++ {
					k := (int(x)*31 + int(y)*17 + int(z)*5) % d
					c.SetBlock(x, base+int16(y), z, 0, values[k])
				}
			}
		}
	}
	water := rids(1)[0]
	base := c.SubY(int16(len(widths) - 1))
	for x := uint8(0); x < 16; x += 3 {
		c.SetBlock(x, base+int16(x), 15-x, 1, water)
	}
	return c
}

// simpleChunk holds only blocks Ignis implements so far, so that the height
// map (which depends on light filtering) is comparable.
func simpleChunk() *chunk.Chunk {
	c := newChunk()
	stone, dirt, grass, bedrock := br.BlockRuntimeID(block.Stone{}), br.BlockRuntimeID(block.Dirt{}), br.BlockRuntimeID(block.Grass{}), br.BlockRuntimeID(block.Bedrock{})
	for x := uint8(0); x < 16; x++ {
		for z := uint8(0); z < 16; z++ {
			h := int16(-64 + int(x)*9 + int(z)*3)
			c.SetBlock(x, -64, z, 0, bedrock)
			for y := int16(-63); y <= h; y++ {
				c.SetBlock(x, y, z, 0, stone)
			}
			if (x+z)%4 == 0 {
				c.SetBlock(x, h+1, z, 0, dirt)
				c.SetBlock(x, h+2, z, 0, grass)
			}
		}
	}
	// A floating block high above the rest.
	c.SetBlock(3, 300, 4, 0, stone)
	return c
}

func biomeChunk() *chunk.Chunk {
	c := newChunk()
	// Section 0: per-block values including 0.
	for x := uint8(0); x < 16; x++ {
		for y := uint8(0); y < 16; y++ {
			for z := uint8(0); z < 16; z++ {
				c.SetBiome(x, -64+int16(y), z, uint32((int(x)+int(z)*2+int(y)/4)%5))
			}
		}
	}
	// Sections 1 and 2: the same section twice, so the second is written as
	// "same as previous".
	var sec [4][4][4]uint32
	for x := range 4 {
		for y := range 4 {
			for z := range 4 {
				sec[x][y][z] = uint32(1 + (x+y+z)%3)
			}
		}
	}
	c.SetBiomeSection(-48, sec)
	c.SetBiomeSection(-32, sec)
	// Section 3: a single biome via SetBiomeSection.
	var one [4][4][4]uint32
	for x := range 4 {
		for y := range 4 {
			for z := range 4 {
				one[x][y][z] = 7
			}
		}
	}
	c.SetBiomeSection(-16, one)
	// Section 4: 70 distinct biomes needs 8 bits.
	for x := uint8(0); x < 16; x++ {
		for z := uint8(0); z < 16; z++ {
			c.SetBiome(x, 0, z, uint32((int(x)*16+int(z))%70))
		}
	}
	return c
}

func flatChunk(fixBiomes bool) *chunk.Chunk {
	c := newChunk()
	f := generator.NewFlat(biome.Plains{}, []world.Block{block.Grass{}, block.Dirt{}, block.Dirt{}, block.Bedrock{}})
	f.GenerateChunk(world.ChunkPos{0, 0}, c)
	if fixBiomes {
		// Dragonfly's Flat stops at y = min + max; Ignis fills the whole range.
		for x := uint8(0); x < 16; x++ {
			for z := uint8(0); z < 16; z++ {
				for y := int16(256); y <= 319; y++ {
					c.SetBiome(x, y, z, uint32(biome.Plains{}.EncodeBiome()))
				}
			}
		}
	}
	return c
}

// netherChunk fills the nether range with terrain of five states.
func netherChunk() *chunk.Chunk {
	c := chunk.New(br, world.Nether.Range())
	values := rids(5)
	for x := uint8(0); x < 16; x++ {
		for z := uint8(0); z < 16; z++ {
			h := int16(10 + (int(x)+int(z))%40)
			for y := int16(0); y <= h; y++ {
				c.SetBlock(x, y, z, 0, values[(int(x)+int(y)+int(z))%5])
			}
		}
	}
	return c
}

// endChunk holds a ring of three states at y 60 in the end range.
func endChunk() *chunk.Chunk {
	c := chunk.New(br, world.End.Range())
	values := rids(3)
	for x := uint8(0); x < 16; x++ {
		c.SetBlock(x, 60, 0, 0, values[0])
		c.SetBlock(x, 60, 15, 0, values[1])
		c.SetBlock(0, 60, x, 0, values[2])
	}
	return c
}
