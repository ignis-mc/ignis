package main

import (
	"bufio"
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"math"
	"os"
	"sort"
	"strings"

	"github.com/df-mc/dragonfly/server/block"
	"github.com/df-mc/dragonfly/server/block/cube"
	"github.com/df-mc/dragonfly/server/world"
	"github.com/df-mc/dragonfly/server/world/chunk"
	"github.com/df-mc/dragonfly/server/world/mcdb"
	"github.com/df-mc/goleveldb/leveldb"
	"github.com/google/uuid"
)

// fixturePlayer is the player whose spawn position the fixture stores.
var fixturePlayer = uuid.MustParse("8f9a6c2e-1b3d-4e5f-a6b7-c8d9e0f1a2b3")

type fixtureColumn struct {
	pos world.ChunkPos
	dim world.Dimension
	col *chunk.Column
}

// fixtureColumns are the columns of the fixture world, mirrored by
// test/support/mcdb_world.mojo.
func fixtureColumns() []fixtureColumn {
	stone := br.BlockRuntimeID(block.Stone{})
	dirt := br.BlockRuntimeID(block.Dirt{})
	mixed := &chunk.Column{Chunk: mixedChunk()}
	mixed.Entities = []chunk.Entity{
		{ID: -4294967295, Data: map[string]any{
			"identifier":  "minecraft:pig",
			"Pos":         []any{float32(1.5), float32(70), float32(-2.25)},
			"Rotation":    []any{float32(90), float32(0)},
			"Health":      int16(10),
			"Saddled":     byte(1),
			"definitions": []any{"+minecraft:pig", "+minecraft:pig_adult"},
		}},
		{ID: 77, Data: map[string]any{
			"identifier": "minecraft:item",
			"Pos":        []any{float32(3), float32(64.5), float32(3)},
			"Age":        int32(1200),
			"Item":       map[string]any{"Name": "minecraft:diamond", "Count": byte(3), "Damage": int16(0)},
		}},
	}
	simple := &chunk.Column{Chunk: simpleChunk()}
	simple.BlockEntities = []chunk.BlockEntity{
		{Pos: cube.Pos{-16 + 2, 5, 32 + 3}, Data: map[string]any{
			"id":         "Chest",
			"CustomName": "Fixture chest",
			"Items":      []any{map[string]any{"Name": "minecraft:stone", "Count": byte(64), "Slot": byte(0)}},
			"Findable":   byte(0),
		}},
		{Pos: cube.Pos{-16 + 9, -60, 32 + 15}, Data: map[string]any{"id": "Sign", "Text": "hello"}},
	}
	biomes := &chunk.Column{Chunk: biomeChunk(), Tick: 1234}
	biomes.ScheduledBlocks = []chunk.ScheduledBlockUpdate{
		{Pos: cube.Pos{80, 10, -112}, Block: stone, Tick: 1240},
		{Pos: cube.Pos{81, -64, -100}, Block: dirt, Tick: 1300},
	}
	return []fixtureColumn{
		{world.ChunkPos{0, 0}, world.Overworld, mixed},
		{world.ChunkPos{-1, 2}, world.Overworld, simple},
		{world.ChunkPos{5, -7}, world.Overworld, biomes},
		{world.ChunkPos{1, 1}, world.Overworld, &chunk.Column{Chunk: flatChunk(true)}},
		{world.ChunkPos{0, 0}, world.Nether, &chunk.Column{Chunk: netherChunk()}},
		{world.ChunkPos{-3, -3}, world.End, &chunk.Column{Chunk: endChunk()}},
	}
}

// worldWrite writes the fixture world with Dragonfly's mcdb provider.
func worldWrite(dir string) error {
	db, err := mcdb.Open(dir)
	if err != nil {
		return err
	}
	s := db.Settings()
	s.Name = "Ignis Fixture"
	s.Spawn = cube.Pos{1, 70, 2}
	s.Time = 6000
	s.TimeCycle = false
	s.RainTime = 12000
	s.Raining = true
	s.ThunderTime = 24000
	s.CurrentTick = 99999
	s.DefaultGameMode = world.GameModeCreative
	s.Difficulty = world.DifficultyHard
	s.TickRange = 4
	db.SaveSettings(s)
	for _, c := range fixtureColumns() {
		if err := db.StoreColumn(c.pos, c.dim, c.col); err != nil {
			return err
		}
	}
	if err := db.SavePlayerSpawnPosition(fixturePlayer, cube.Pos{-5, 64, 9}); err != nil {
		return err
	}
	return db.Close()
}

// canon prints an NBT value with sorted compound keys and typed scalars,
// mirrored by test/support/mcdb_world.mojo.
func canon(v any) string {
	switch v := v.(type) {
	case byte:
		return fmt.Sprintf("%db", v)
	case int16:
		return fmt.Sprintf("%ds", v)
	case int32:
		return fmt.Sprintf("%di", v)
	case int64:
		return fmt.Sprintf("%dl", v)
	case float32:
		return fmt.Sprintf("f%08x", math.Float32bits(v))
	case float64:
		return fmt.Sprintf("d%016x", math.Float64bits(v))
	case string:
		return fmt.Sprintf("%q", v)
	case []any:
		parts := make([]string, len(v))
		for i, x := range v {
			parts[i] = canon(x)
		}
		return "[" + strings.Join(parts, ",") + "]"
	case map[string]any:
		keys := make([]string, 0, len(v))
		for k := range v {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		parts := make([]string, len(keys))
		for i, k := range keys {
			parts[i] = fmt.Sprintf("%q:%s", k, canon(v[k]))
		}
		return "{" + strings.Join(parts, ",") + "}"
	}
	return fmt.Sprintf("?%T", v)
}

func storageHash(s *chunk.PalettedStorage) string {
	h := sha256.New()
	var b [4]byte
	for x := uint8(0); x < 16; x++ {
		for y := uint8(0); y < 16; y++ {
			for z := uint8(0); z < 16; z++ {
				binary.LittleEndian.PutUint32(b[:], s.At(x, y, z))
				h.Write(b[:])
			}
		}
	}
	return fmt.Sprintf("%x", h.Sum(nil))[:16]
}

// columnKeys lists the columns of a world by scanning its version keys
// with goleveldb, as mcdb.ColumnIterator does.
func columnKeys(dir string) ([]fixtureColumn, error) {
	ldb, err := leveldb.OpenFile(dir+"/db", nil)
	if err != nil {
		return nil, err
	}
	defer ldb.Close()
	var out []fixtureColumn
	seen := map[[3]int32]bool{}
	it := ldb.NewIterator(nil, nil)
	for it.Next() {
		k := it.Key()
		n := len(k)
		if (n != 9 && n != 13) || (k[n-1] != ',' && k[n-1] != 'v') {
			continue
		}
		dim := world.Dimension(world.Overworld)
		id := int32(0)
		if n > 9 {
			id = int32(binary.LittleEndian.Uint32(k[8:12]))
			dim, _ = world.DimensionByID(int(id))
		}
		pos := world.ChunkPos{int32(binary.LittleEndian.Uint32(k[:4])), int32(binary.LittleEndian.Uint32(k[4:8]))}
		if seen[[3]int32{id, pos[0], pos[1]}] {
			continue
		}
		seen[[3]int32{id, pos[0], pos[1]}] = true
		out = append(out, fixtureColumn{pos: pos, dim: dim})
	}
	it.Release()
	return out, it.Error()
}

// worldDump opens a world with Dragonfly and writes everything the
// provider returns, one fact per line. With lenient set, every column is
// loaded on its own and a column that fails to load is a single ERR line
// (for worlds with blocks the registry lacks).
func worldDump(dir, out string, lenient bool) error {
	var keys []fixtureColumn
	if lenient {
		var err error
		if keys, err = columnKeys(dir); err != nil {
			return err
		}
	}
	db, err := mcdb.Open(dir)
	if err != nil {
		return err
	}
	f, err := os.Create(out)
	if err != nil {
		return err
	}
	w := bufio.NewWriter(f)
	s := db.Settings()
	mode, _ := world.GameModeID(s.DefaultGameMode)
	diff, _ := world.DifficultyID(s.Difficulty)
	fmt.Fprintf(w, "settings %q spawn=%v time=%d cycle=%v rain=%d raining=%v thunder=%d thundering=%v weather=%v tick=%d mode=%d difficulty=%d range=%d\n",
		s.Name, [3]int(s.Spawn), s.Time, s.TimeCycle, s.RainTime, s.Raining, s.ThunderTime, s.Thundering, s.WeatherCycle, s.CurrentTick, mode, diff, s.TickRange)
	pos, ok, err := db.LoadPlayerSpawnPosition(fixturePlayer)
	fmt.Fprintf(w, "player %v %v %v\n", [3]int(pos), ok, err)
	var lines []string
	if lenient {
		for _, k := range keys {
			id, _ := world.DimensionID(k.dim)
			col, err := db.LoadColumn(k.pos, k.dim)
			if err != nil {
				lines = append(lines, fmt.Sprintf("%d %d %d ERR", id, k.pos[0], k.pos[1]))
				continue
			}
			lines = append(lines, columnLines(fmt.Sprintf("%d %d %d", id, k.pos[0], k.pos[1]), col)...)
		}
	} else {
		it := db.NewColumnIterator(nil)
		for it.Next() {
			cp := it.Position()
			id, _ := world.DimensionID(it.Dimension())
			lines = append(lines, columnLines(fmt.Sprintf("%d %d %d", id, cp[0], cp[1]), it.Column())...)
		}
		it.Release()
		if err := it.Error(); err != nil {
			return err
		}
	}
	sort.Strings(lines)
	for _, l := range lines {
		fmt.Fprintln(w, l)
	}
	if err := w.Flush(); err != nil {
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}
	return db.Close()
}

// columnLines dumps one column.
func columnLines(p string, col *chunk.Column) []string {
	var lines []string
	{
		c := col.Chunk
		for i, sub := range c.Sub() {
			layers := sub.Layers()
			hs := make([]string, len(layers))
			for j, l := range layers {
				hs[j] = storageHash(l)
			}
			lines = append(lines, fmt.Sprintf("%s sub %02d layers=%d %s", p, i, len(layers), strings.Join(hs, " ")))
		}
		bh := sha256.New()
		var b [4]byte
		r := c.Range()
		for y := r[0]; y <= r[1]; y++ {
			for x := uint8(0); x < 16; x++ {
				for z := uint8(0); z < 16; z++ {
					binary.LittleEndian.PutUint32(b[:], c.Biome(x, int16(y), z))
					bh.Write(b[:])
				}
			}
		}
		lines = append(lines, fmt.Sprintf("%s biomes %x", p, bh.Sum(nil)[:8]))
		lines = append(lines, fmt.Sprintf("%s legacy %v", p, c.LegacyStates()))
		for _, e := range col.Entities {
			lines = append(lines, fmt.Sprintf("%s entity %d %s", p, e.ID, canon(e.Data)))
		}
		for _, be := range col.BlockEntities {
			lines = append(lines, fmt.Sprintf("%s blockentity %v %s", p, [3]int(be.Pos), canon(be.Data)))
		}
		lines = append(lines, fmt.Sprintf("%s tick %d", p, col.Tick))
		for _, u := range col.ScheduledBlocks {
			lines = append(lines, fmt.Sprintf("%s scheduled %v %d %d", p, [3]int(u.Pos), u.Block, u.Tick))
		}
	}
	return lines
}
