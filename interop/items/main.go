// Command items writes test vectors for Ignis's item core from Dragonfly
// v0.11.6: the item table StartGame carries, item runtime IDs as
// world.ItemRuntimeID computes them, and the network ItemStacks Dragonfly's
// session builds for a few stacks.
//
// Usage (from the repository root):
//
//	(cd interop/items && go run . -out ../../test/data/items)
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
	"sort"
	"strings"

	"github.com/df-mc/dragonfly/server/block"
	"github.com/df-mc/dragonfly/server/item"
	"github.com/df-mc/dragonfly/server/world"
	"github.com/sandertv/gophertunnel/minecraft/nbt"
	"github.com/sandertv/gophertunnel/minecraft/protocol"
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

// entry is the value type Dragonfly's server.go decodes vanilla_items.nbt
// into for StartGame's item table.
type entry struct {
	RuntimeID      int32          `nbt:"runtime_id"`
	ComponentBased bool           `nbt:"component_based"`
	Version        int32          `nbt:"version"`
	Data           map[string]any `nbt:"data,omitempty"`
}

// nameItem is an item that only encodes to a name. world.ItemRuntimeID only
// calls EncodeItem, so it reads Dragonfly's name to runtime ID table for any
// name.
type nameItem struct{ name string }

func (n nameItem) EncodeItem() (string, int16) { return n.name, 0 }

// canonical renders a decoded NBT value with its tag type and compound keys
// sorted, so that the value can be compared regardless of map order:
// b<u8> s<i16> i<i32> l<i64> f<bits> d<bits> x<hex string>, [..] lists,
// B[..]/I[..]/L[..] arrays and {k=v,..} compounds.
func canonical(v any) string {
	switch x := v.(type) {
	case uint8:
		return fmt.Sprintf("b%d", x)
	case int16:
		return fmt.Sprintf("s%d", x)
	case int32:
		return fmt.Sprintf("i%d", x)
	case int64:
		return fmt.Sprintf("l%d", x)
	case float32:
		return fmt.Sprintf("f%08x", math.Float32bits(x))
	case float64:
		return fmt.Sprintf("d%016x", math.Float64bits(x))
	case string:
		return "x" + hex.EncodeToString([]byte(x))
	case []any:
		parts := make([]string, len(x))
		for i, e := range x {
			parts[i] = canonical(e)
		}
		return "[" + strings.Join(parts, ",") + "]"
	case map[string]any:
		keys := make([]string, 0, len(x))
		for k := range x {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		parts := make([]string, len(keys))
		for i, k := range keys {
			parts[i] = "x" + hex.EncodeToString([]byte(k)) + "=" + canonical(x[k])
		}
		return "{" + strings.Join(parts, ",") + "}"
	}
	// gophertunnel decodes arrays into Go arrays and lists into slices,
	// typed ([]int32, []string) when the elements allow it.
	rv := reflect.ValueOf(v)
	switch rv.Kind() {
	case reflect.Array:
		prefix := map[reflect.Kind]string{reflect.Uint8: "B", reflect.Int32: "I", reflect.Int64: "L"}[rv.Type().Elem().Kind()]
		if prefix == "" {
			panic(fmt.Sprintf("array %T", v))
		}
		parts := make([]string, rv.Len())
		for i := range parts {
			parts[i] = fmt.Sprint(rv.Index(i).Interface())
		}
		return prefix + "[" + strings.Join(parts, ",") + "]"
	case reflect.Slice:
		parts := make([]string, rv.Len())
		for i := range parts {
			parts[i] = canonical(rv.Index(i).Interface())
		}
		return "[" + strings.Join(parts, ",") + "]"
	}
	panic(fmt.Sprintf("canonical: %T", v))
}

func itemTable(v vectors, data []byte, out string) {
	var m map[string]entry
	must(nbt.Unmarshal(data, &m))

	names := make([]string, 0, len(m))
	for name := range m {
		names = append(names, name)
	}
	sort.Slice(names, func(i, j int) bool { return m[names[i]].RuntimeID < m[names[j]].RuntimeID })

	var all, sample strings.Builder
	for i, name := range names {
		e := m[name]
		rid, _, ok := world.ItemRuntimeID(nameItem{name})
		if !ok || rid != e.RuntimeID {
			panic(fmt.Sprintf("%s: world runtime ID %d %v, table %d", name, rid, ok, e.RuntimeID))
		}
		cb := 0
		if e.ComponentBased {
			cb = 1
		}
		data := "-"
		if e.Data != nil {
			data = canonical(e.Data)
		}
		line := fmt.Sprintf("%d\t%s\t%d\t%d\t%s", e.RuntimeID, name, cb, e.Version, data)
		all.WriteString(line + "\n")
		if i%37 == 0 || i == len(names)-1 || (e.Data != nil && i%5 == 0) {
			sample.WriteString(line + "\n")
		}
	}
	sum := sha256.Sum256([]byte(all.String()))
	v.hex("items.sha256", sum[:])
	v.int("items.count", len(names))
	must(os.WriteFile(filepath.Join(out, "items_sample.txt"), []byte(sample.String()), 0o644))
}

// stackFromItem is session.stackFromItem (server/session/player.go).
func stackFromItem(it item.Stack) protocol.ItemStack {
	if it.Empty() {
		return protocol.ItemStack{}
	}
	var blockRuntimeID uint32
	if b, ok := it.Item().(world.Block); ok {
		blockRuntimeID = br.BlockRuntimeID(b)
	}
	rid, meta, _ := world.ItemRuntimeID(it.Item())
	return protocol.ItemStack{
		ItemType: protocol.ItemType{
			NetworkID:     rid,
			MetadataValue: uint32(meta),
		},
		Count:          uint16(it.Count()),
		BlockRuntimeID: int32(blockRuntimeID),
		NBTData:        item.WriteNBT(it, false),
	}
}

func stacks(v vectors) {
	named := map[string]world.Item{
		"stick":        item.Stick{},
		"diamond":      item.Diamond{},
		"coal":         item.Coal{},
		"beef":         item.Beef{},
		"cooked_beef":  item.Beef{Cooked: true},
		"shears":       item.Shears{},
		"air":          block.Air{},
		"stone":        block.Stone{},
		"smooth_stone": block.Stone{Smooth: true},
		"grass":        block.Grass{},
		"dirt":         block.Dirt{},
		"coarse_dirt":  block.Dirt{Coarse: true},
		"bedrock":      block.Bedrock{},
	}
	for k, it := range named {
		rid, meta, ok := world.ItemRuntimeID(it)
		if !ok {
			panic(k)
		}
		v.int("item."+k+".rid", rid)
		v.int("item."+k+".meta", meta)
		back, ok := world.ItemByRuntimeID(rid, meta)
		if !ok || back != it {
			panic("round trip " + k)
		}
		if k != "air" {
			stackVector(v, k, item.NewStack(it, 3))
		}
	}
	stackVector(v, "air", item.NewStack(block.Air{}, 1))
	stackVector(v, "shears_damaged", item.NewStack(item.Shears{}, 1).Damage(5))
	stackVector(v, "shears_unbreakable", item.NewStack(item.Shears{}, 1).AsUnbreakable())
	stackVector(v, "stick_named", item.NewStack(item.Stick{}, 64).WithCustomName("Wand"))
	stackVector(v, "stick_lore", item.NewStack(item.Stick{}, 1).WithLore("a", "b"))
	stackVector(v, "dirt_all", item.NewStack(block.Dirt{}, 2).WithCustomName("Mud").WithLore("x").WithAnvilCost(3))
	stackVector(v, "shears_all", item.NewStack(item.Shears{}, 1).Damage(237).WithCustomName("S").AsUnbreakable())
	v.int("durability.shears.after_damage_5", item.NewStack(item.Shears{}, 1).Damage(5).Durability())
	v.int("durability.shears.after_break", item.NewStack(item.Shears{}, 1).Damage(238).Count())
}

// stackVector writes the stack's network NBT in canonical form and, when
// every compound has at most one key (so Go's map order cannot change the
// bytes), the marshalled ItemStack.
func stackVector(v vectors, k string, s item.Stack) {
	ps := stackFromItem(s)
	v["stack."+k+".nbt"] = canonical(ps.NBTData)
	if deterministic(ps.NBTData) {
		buf := new(bytes.Buffer)
		w := protocol.NewWriter(buf, 0)
		w.Item(&ps)
		v.hex("stack."+k+".bytes", buf.Bytes())
	}
}

func deterministic(m map[string]any) bool {
	if len(m) > 1 {
		return false
	}
	for _, x := range m {
		if sub, ok := x.(map[string]any); ok && !deterministic(sub) {
			return false
		}
	}
	return true
}

func main() {
	out := flag.String("out", "../../test/data/items", "output directory")
	in := flag.String("items", "../../resources/vanilla_items.nbt", "the copy of vanilla_items.nbt")
	flag.Parse()
	vanillaItems, err := os.ReadFile(*in)
	must(err)
	must(os.MkdirAll(*out, 0o755))
	br.Finalize()

	v := vectors{}
	sum := sha256.Sum256(vanillaItems)
	v.hex("file.sha256", sum[:])
	itemTable(v, vanillaItems, *out)
	stacks(v)
	itemDefinitions(*out)
	v.write(filepath.Join(*out, "vectors.txt"))
}
