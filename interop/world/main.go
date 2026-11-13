// Command world writes test vectors for Ignis's world core from Dragonfly
// v0.11.6: block runtime IDs and network hashes, network-encoded sub-chunks
// and biomes, height maps, and the LevelChunk and SubChunk packets Dragonfly's
// session sends for them.
//
// Usage (from the repository root):
//
//	(cd interop/world && go run . -out ../../test/data/world)
package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"flag"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"sort"
	"strings"

	"github.com/df-mc/dragonfly/server/block"
	"github.com/df-mc/dragonfly/server/item"
	"github.com/df-mc/dragonfly/server/world"
	"github.com/df-mc/dragonfly/server/world/biome"
	"github.com/df-mc/dragonfly/server/world/chunk"
	"github.com/df-mc/dragonfly/server/world/generator"
	"github.com/sandertv/gophertunnel/minecraft/protocol"
	"github.com/sandertv/gophertunnel/minecraft/protocol/packet"
)

var br = world.DefaultBlockRegistry

// vectors collects "key value" lines, written sorted by key.
type vectors map[string]string

func (v vectors) hex(key string, b []byte) { v[key] = hex.EncodeToString(b) }
func (v vectors) int(key string, n any)    { v[key] = fmt.Sprint(n) }

func (v vectors) write(path string) {
	keys := make([]string, 0, len(v))
	for k := range v {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	var b strings.Builder
	for _, k := range keys {
		b.WriteString(k + " " + v[k] + "\n")
	}
	must(os.WriteFile(path, []byte(b.String()), 0o644))
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}

// stateLine renders one runtime ID as "rid<TAB>hash<TAB>name<TAB>props", the
// properties sorted by key as key=type:value with type b (byte or bool), i
// (int32) or s (string).
func stateLine(rid uint32) string {
	name, props, ok := br.RuntimeIDToState(rid)
	if !ok {
		panic(rid)
	}
	hash, _ := br.RuntimeIDToHash(rid)
	keys := make([]string, 0, len(props))
	for k := range props {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	parts := make([]string, 0, len(keys))
	for _, k := range keys {
		switch v := props[k].(type) {
		case bool:
			b := 0
			if v {
				b = 1
			}
			parts = append(parts, fmt.Sprintf("%s=b:%d", k, b))
		case uint8:
			parts = append(parts, fmt.Sprintf("%s=b:%d", k, v))
		case int32:
			parts = append(parts, fmt.Sprintf("%s=i:%d", k, v))
		case string:
			parts = append(parts, fmt.Sprintf("%s=s:%s", k, v))
		default:
			panic(fmt.Sprintf("%T", v))
		}
	}
	return fmt.Sprintf("%d\t%08x\t%s\t%s", rid, hash, name, strings.Join(parts, ","))
}

func blockStates(v vectors, out string) {
	n := uint32(br.BlockCount())
	var all, sample strings.Builder
	for rid := uint32(0); rid < n; rid++ {
		line := stateLine(rid)
		all.WriteString(line + "\n")
		if rid%97 == 0 || rid == n-1 || rid == br.AirRuntimeID() {
			sample.WriteString(line + "\n")
		}
	}
	sum := sha256.Sum256([]byte(all.String()))
	v.hex("states.sha256", sum[:])
	v.int("states.count", n)
	v.int("states.air", br.AirRuntimeID())
	v.int("states.bit_size", br.BitSize())
	must(os.WriteFile(filepath.Join(out, "block_states_sample.txt"), []byte(sample.String()), 0o644))

	named := map[string]world.Block{
		"air":             block.Air{},
		"stone":           block.Stone{},
		"smooth_stone":    block.Stone{Smooth: true},
		"grass":           block.Grass{},
		"dirt":            block.Dirt{},
		"coarse_dirt":     block.Dirt{Coarse: true},
		"bedrock":         block.Bedrock{},
		"bedrock_burning": block.Bedrock{InfiniteBurning: true},
	}
	for k, b := range named {
		v.int("block."+k+".rid", br.BlockRuntimeID(b))
		v.int("block."+k+".hash", br.BlockHash(b))
	}
}

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

func marshal(pk packet.Packet) []byte {
	buf := bytes.NewBuffer(nil)
	pk.Marshal(protocol.NewWriter(buf, 0))
	return buf.Bytes()
}

// networkChunk is session.sendNetworkChunk with sub-chunk requests enabled and
// no client cache, as Dragonfly v0.11.6 sends it.
func networkChunk(pos world.ChunkPos, c *chunk.Chunk) *packet.LevelChunk {
	return &packet.LevelChunk{
		Dimension:     0,
		SubChunkCount: 0,
		Position:      protocol.ChunkPos(pos),
		SubChunkLimit: protocol.Option(int32(c.HighestFilledSubChunk())),
		RawPayload:    append(chunk.EncodeBiomes(c, chunk.NetworkEncoding), 0),
	}
}

// subChunkEntry is session.subChunkEntry from Dragonfly v0.11.6 without block
// entities and without the client cache.
func subChunkEntry(offset protocol.SubChunkOffset, ind int16, col *chunk.Chunk) protocol.SubChunkEntry {
	chunkMap := col.HeightMap()
	subMapType, subMap := byte(protocol.HeightMapDataHasData), protocol.HeightMap{}
	higher, lower := true, true
	for z := uint8(0); z < 16; z++ {
		for x := uint8(0); x < 16; x++ {
			y := chunkMap.At(x, z)
			otherInd := col.SubIndex(y)
			switch {
			case otherInd > ind:
				subMap[z][x], lower = 16, false
			case otherInd < ind:
				subMap[z][x], higher = -1, false
			default:
				subMap[z][x], lower, higher = int8(y-col.SubY(otherInd)), false, false
			}
		}
	}
	var subMapData protocol.Optional[protocol.HeightMap]
	switch {
	case higher:
		subMapType = protocol.HeightMapDataTooHigh
	case lower:
		subMapType = protocol.HeightMapDataTooLow
	default:
		subMapData = protocol.Option(subMap)
	}

	sub := col.Sub()[ind]
	if sub.Empty() {
		return protocol.SubChunkEntry{
			Result:              protocol.SubChunkResultSuccessAllAir,
			HeightMapType:       subMapType,
			HeightMapData:       subMapData,
			RenderHeightMapType: subMapType,
			RenderHeightMapData: subMapData,
			Offset:              offset,
		}
	}
	serialisedSubChunk := chunk.EncodeSubChunk(col, chunk.NetworkEncoding, int(ind))
	return protocol.SubChunkEntry{
		Result:              protocol.SubChunkResultSuccess,
		RawPayload:          protocol.Option(serialisedSubChunk),
		HeightMapType:       subMapType,
		HeightMapData:       subMapData,
		RenderHeightMapType: subMapType,
		RenderHeightMapData: subMapData,
		Offset:              offset,
	}
}

// subChunkPacket is session.ViewSubChunks for a single loaded chunk column at
// the centre's X and Z.
func subChunkPacket(centre world.SubChunkPos, offsets []protocol.SubChunkOffset, c *chunk.Chunk) *packet.SubChunk {
	r := world.Overworld.Range()
	entries := make([]protocol.SubChunkEntry, 0, len(offsets))
	for _, offset := range offsets {
		ind := int16(centre.Y()) + int16(offset[1]) - int16(r[0])>>4
		if ind < 0 || ind > int16(r.Height()>>4) {
			entries = append(entries, protocol.SubChunkEntry{Result: protocol.SubChunkResultIndexOutOfBounds, Offset: offset})
			continue
		}
		if offset[0] != 0 || offset[2] != 0 {
			entries = append(entries, protocol.SubChunkEntry{Result: protocol.SubChunkResultChunkNotFound, Offset: offset})
			continue
		}
		entries = append(entries, subChunkEntry(offset, ind, c))
	}
	return &packet.SubChunk{
		Dimension:       0,
		Position:        protocol.SubChunkPos(centre),
		SubChunkEntries: entries,
	}
}

func chunkVectors(v vectors, name string, c *chunk.Chunk) {
	data := chunk.Encode(c, chunk.NetworkEncoding)
	for i, sub := range data.SubChunks {
		v.hex(fmt.Sprintf("%s.sub.%02d", name, i), sub)
	}
	v.hex(name+".biomes", data.Biomes)
	v.int(name+".highest_filled", c.HighestFilledSubChunk())
	hm := c.HeightMap()
	parts := make([]string, len(hm))
	for i, h := range hm {
		parts[i] = fmt.Sprint(h)
	}
	v[name+".height_map"] = strings.Join(parts, ",")
	v.hex(name+".level_chunk", marshal(networkChunk(world.ChunkPos{3, -2}, c)))

	var offsets []protocol.SubChunkOffset
	for y := int8(-5); y <= 21; y++ {
		offsets = append(offsets, protocol.SubChunkOffset{0, y, 0})
	}
	offsets = append(offsets, protocol.SubChunkOffset{1, 0, 0})
	v.hex(name+".sub_chunk", marshal(subChunkPacket(world.SubChunkPos{3, 0, -2}, offsets, c)))
}

func main() {
	out := flag.String("out", "../../test/data/world", "output directory")
	flag.Parse()
	must(os.MkdirAll(*out, 0o755))

	br.Finalize()
	v := vectors{}
	blockStates(v, *out)
	blockDefinitions(*out)
	cubeVectors(*out)
	chunkVectors(v, "empty", newChunk())
	chunkVectors(v, "simple", simpleChunk())
	chunkVectors(v, "flat", flatChunk(false))
	chunkVectors(v, "flat_fixed", flatChunk(true))
	chunkVectors(v, "biomes", biomeChunk())

	// Mixed palettes: encoding only, the height map depends on light
	// filtering of blocks Ignis does not implement yet.
	data := chunk.Encode(mixedChunk(), chunk.NetworkEncoding)
	for i := range widths {
		v.hex(fmt.Sprintf("mixed.sub.%02d", i), data.SubChunks[i])
	}
	v.write(filepath.Join(*out, "vectors.txt"))
}

// tools are the tools a BreakInfo's Harvestable and Effective are evaluated
// with: bit i of the masks in blocks.txt is tools[i]. Ignis builds the same
// list from (tool type, harvest level) pairs.
func tools() []item.Tool {
	out := []item.Tool{item.ToolNone{}}
	for _, tier := range item.ToolTiers() {
		out = append(out, item.Pickaxe{Tier: tier}, item.Axe{Tier: tier}, item.Hoe{Tier: tier}, item.Shovel{Tier: tier}, item.Sword{Tier: tier})
	}
	return append(out, item.Shears{})
}

// blockDefinitions writes blocks.txt: one line per runtime ID that has a
// registered block (not an unknown state), as
// "rid<TAB>type<TAB>base hash<TAB>state hash<TAB>light<TAB>filter<TAB>flags<TAB>break",
// flags being bits nbt|randomtick<<1|liquid<<2|liquiddisplacing<<3 and break
// "-" for blocks that are not Breakable, otherwise the IEEE bits of hardness
// and blast resistance in hex, the harvestable and effective tool masks in
// hex and the XP drop range.
func blockDefinitions(out string) {
	ts := tools()
	var b strings.Builder
	for rid := uint32(0); rid < uint32(br.BlockCount()); rid++ {
		blk, _ := br.BlockByRuntimeID(rid)
		typ := reflect.TypeOf(blk).Name()
		if typ == "unknownBlock" {
			continue
		}
		base, state := blk.Hash()
		flags := 0
		for i, f := range []bool{br.NBTBlock(rid), br.RandomTickBlock(rid), br.LiquidBlock(rid), br.LiquidDisplacingBlock(rid)} {
			if f {
				flags |= 1 << i
			}
		}
		brk := "-"
		if bb, ok := blk.(block.Breakable); ok {
			info := bb.BreakInfo()
			var harvest, effective uint64
			for i, t := range ts {
				if info.Harvestable(t) {
					harvest |= 1 << i
				}
				if info.Effective(t) {
					effective |= 1 << i
				}
			}
			brk = fmt.Sprintf("%016x,%016x,%x,%x,%d,%d", math.Float64bits(info.Hardness), math.Float64bits(info.BlastResistance), harvest, effective, info.XPDrops[0], info.XPDrops[1])
		}
		fmt.Fprintf(&b, "%d\t%s\t%d\t%d\t%d\t%d\t%d\t%s\n", rid, typ, base, state, br.LightBlock(rid), br.FilteringBlock(rid), flags, brk)
	}
	must(os.WriteFile(filepath.Join(out, "blocks.txt"), []byte(b.String()), 0o644))
}
