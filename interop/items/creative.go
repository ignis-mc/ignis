package main

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"sort"
	"strings"
	_ "unsafe"

	"github.com/df-mc/dragonfly/server/item"
	"github.com/df-mc/dragonfly/server/item/creative"
	_ "github.com/df-mc/dragonfly/server/item/recipe"
	"github.com/sandertv/gophertunnel/minecraft/nbt"
	"github.com/sandertv/gophertunnel/minecraft/protocol"
	"github.com/sandertv/gophertunnel/minecraft/protocol/packet"
)

// creativeContent is session.creativeContent (server/session/player.go).
func creativeContent() ([]protocol.CreativeGroup, []protocol.CreativeItem) {
	groups := make([]protocol.CreativeGroup, 0, len(creative.Groups()))
	for _, group := range creative.Groups() {
		groups = append(groups, protocol.CreativeGroup{
			Category: group.Category.Uint8(),
			Name:     group.Name,
			Icon:     deleteDamage(stackFromItem(group.Icon)),
		})
	}
	it := make([]protocol.CreativeItem, 0, len(creative.Items()))
	for index, i := range creative.Items() {
		group := slices.IndexFunc(creative.Groups(), func(group creative.Group) bool {
			return group.Name == i.Group
		})
		if group < 0 {
			continue
		}
		it = append(it, protocol.CreativeItem{
			CreativeItemNetworkID: uint32(index) + 1,
			Item:                  deleteDamage(stackFromItem(i.Stack)),
			GroupIndex:            uint32(group),
		})
	}
	return groups, it
}

func deleteDamage(st protocol.ItemStack) protocol.ItemStack {
	delete(st.NBTData, "Damage")
	return st
}

// sortedValue turns NBT maps into structs whose fields are the map's keys
// in sorted order, so that the NBT encoder writes them deterministically.
func sortedValue(v any) any {
	switch x := v.(type) {
	case map[string]any:
		keys := make([]string, 0, len(x))
		for k := range x {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		fields := make([]reflect.StructField, len(keys))
		vals := make([]reflect.Value, len(keys))
		for i, k := range keys {
			sv := reflect.ValueOf(sortedValue(x[k]))
			fields[i] = reflect.StructField{Name: fmt.Sprintf("F%d", i), Type: sv.Type(), Tag: reflect.StructTag(fmt.Sprintf(`nbt:"%s"`, k))}
			vals[i] = sv
		}
		s := reflect.New(reflect.StructOf(fields)).Elem()
		for i := range vals {
			s.Field(i).Set(vals[i])
		}
		return s.Interface()
	case []any:
		out := make([]any, len(x))
		for i, e := range x {
			out[i] = sortedValue(e)
		}
		return out
	}
	return v
}

// writeItem is protocol.Writer.Item with the NBT keys sorted.
func writeItem(w *protocol.Writer, x *protocol.ItemStack) {
	w.Varint32(&x.NetworkID)
	w.Uint16(&x.Count)
	w.Varuint32(&x.MetadataValue)
	w.Varint32(&x.BlockRuntimeID)
	if x.NetworkID == 0 {
		var zero uint32
		w.Varuint32(&zero)
		return
	}
	buf := new(bytes.Buffer)
	bw := protocol.NewWriter(buf, 0)
	var length int16
	if len(x.NBTData) != 0 {
		length = -1
		version := uint8(1)
		bw.Int16(&length)
		bw.Uint8(&version)
		must(nbt.NewEncoderWithEncoding(buf, nbt.LittleEndian).Encode(sortedValue(x.NBTData)))
	} else {
		bw.Int16(&length)
	}
	protocol.FuncSliceUint32Length(bw, &x.CanBePlacedOn, bw.StringUTF)
	protocol.FuncSliceUint32Length(bw, &x.CanBreak, bw.StringUTF)
	extra := buf.Bytes()
	w.ByteSlice(&extra)
}

// creativeVectors writes creative.txt, one line per group ("g index
// category name stack") and item ("i network-id group stack"), stacks as
// "rid:meta*count block-rid canonical-nbt", and creative_content.bin, the
// CreativeContent packet Dragonfly sends with every NBT compound's keys
// sorted (Go's map order is random). It checks that the packet with sorted
// keys has the length of the one gophertunnel writes.
func creativeVectors(out string) {
	groups, items := creativeContent()
	stack := func(s protocol.ItemStack) string {
		n := "{}"
		if len(s.NBTData) != 0 {
			n = canonical(s.NBTData)
		}
		return fmt.Sprintf("%d:%d*%d %d %s", s.NetworkID, s.MetadataValue, s.Count, s.BlockRuntimeID, n)
	}
	var b strings.Builder
	for i, g := range groups {
		fmt.Fprintf(&b, "g\t%d\t%d\t%s\t%s\n", i, g.Category, g.Name, stack(g.Icon))
	}
	for _, it := range items {
		fmt.Fprintf(&b, "i\t%d\t%d\t%s\n", it.CreativeItemNetworkID, it.GroupIndex, stack(it.Item))
	}
	must(os.WriteFile(filepath.Join(out, "creative.txt"), []byte(b.String()), 0o644))

	buf := new(bytes.Buffer)
	w := protocol.NewWriter(buf, 0)
	n := uint32(len(groups))
	w.Varuint32(&n)
	for i := range groups {
		w.Uint8(&groups[i].Category)
		w.String(&groups[i].Name)
		writeItem(w, &groups[i].Icon)
	}
	n = uint32(len(items))
	w.Varuint32(&n)
	for i := range items {
		w.Varuint32(&items[i].CreativeItemNetworkID)
		writeItem(w, &items[i].Item)
		w.Varuint32(&items[i].GroupIndex)
	}
	ref := new(bytes.Buffer)
	pk := &packet.CreativeContent{Groups: groups, Items: items}
	pk.Marshal(protocol.NewWriter(ref, 0))
	if ref.Len() != buf.Len() {
		panic(fmt.Sprintf("sorted CreativeContent is %d bytes, gophertunnel's %d", buf.Len(), ref.Len()))
	}
	must(os.WriteFile(filepath.Join(out, "creative_content.bin"), buf.Bytes(), 0o644))
	_ = item.Stack{}
}

//go:linkname creative_registerCreativeItems github.com/df-mc/dragonfly/server/item/creative.registerCreativeItems
func creative_registerCreativeItems()

//go:linkname recipe_registerVanilla github.com/df-mc/dragonfly/server/item/recipe.registerVanilla
func recipe_registerVanilla()
