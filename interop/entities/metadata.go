package main

import (
	"bytes"
	"encoding/hex"
	"fmt"
	"reflect"
	"sort"
	"strings"
	"time"
	_ "unsafe"

	"github.com/df-mc/dragonfly/server/block"
	"github.com/df-mc/dragonfly/server/block/cube"
	"github.com/df-mc/dragonfly/server/entity"
	"github.com/df-mc/dragonfly/server/item"
	"github.com/df-mc/dragonfly/server/item/potion"
	"github.com/df-mc/dragonfly/server/session"
	"github.com/df-mc/dragonfly/server/world"
	"github.com/go-gl/mathgl/mgl64"
	"github.com/sandertv/gophertunnel/minecraft/nbt"
	"github.com/sandertv/gophertunnel/minecraft/protocol"
)

// parseEntityMetadata is Dragonfly's unexported metadata builder; run with
// -ldflags=-checklinkname=0. With a zero Session, owners have runtime ID 0.
//
//go:linkname parseEntityMetadata github.com/df-mc/dragonfly/server/session.(*Session).parseEntityMetadata
func parseEntityMetadata(s *session.Session, e world.Entity) protocol.EntityMetadata

// noOwner is an owner whose handle is nil: a zero Session cannot look up
// owners' runtime IDs, so the projectiles are recorded without one.
type noOwner struct{}

func (noOwner) Close() error            { return nil }
func (noOwner) H() *world.EntityHandle  { return nil }
func (noOwner) Position() mgl64.Vec3    { return mgl64.Vec3{} }
func (noOwner) Rotation() cube.Rotation { return cube.Rotation{} }

// metadata writes "name hex" with the marshalled metadata of each entity,
// spawned at the origin without velocity, as Dragonfly sends it in AddActor.
func metadata() string {
	var b strings.Builder
	w := newWorld()
	w.Do(func(tx *world.Tx) {
		var owner world.Entity = noOwner{}
		o := world.EntitySpawnOpts{Position: mgl64.Vec3{0.5, -60, 0.5}, Velocity: mgl64.Vec3{0, 0, 0}}
		crit := world.EntitySpawnOpts{Position: o.Position}
		fw := item.Firework{Duration: time.Second, Explosions: []item.FireworkExplosion{
			{Shape: item.FireworkShapeHugeSphere(), Colour: item.ColourRed(), Twinkle: true},
			{Shape: item.FireworkShapeStar(), Colour: item.ColourBlue(), Fade: item.ColourWhite(), Fades: true},
		}}
		arrow := entity.NewArrow(crit, owner)
		for _, c := range []struct {
			name string
			h    *world.EntityHandle
		}{
			{"snowball", entity.NewSnowball(o, owner)},
			{"egg", entity.NewEgg(o, owner)},
			{"ender_pearl", entity.NewEnderPearl(o, owner)},
			{"arrow", arrow},
			{"tipped_arrow", entity.NewTippedArrow(o, owner, potion.Strength())},
			{"splash_water", entity.NewSplashPotion(o, potion.Water(), owner)},
			{"splash_healing", entity.NewSplashPotion(o, potion.Healing(), owner)},
			{"lingering_swiftness", entity.NewLingeringPotion(o, potion.Swiftness(), owner)},
			{"xp_bottle", entity.NewBottleOfEnchanting(o, owner)},
			{"xp_orb", entity.NewExperienceOrb(world.EntitySpawnOpts{Position: o.Position, Velocity: mgl64.Vec3{0, 0.1, 0}}, 37)},
			{"firework", entity.NewFirework(o, fw)},
			{"tnt", entity.NewTNT(world.EntitySpawnOpts{Position: o.Position, Velocity: mgl64.Vec3{0, 0.1, 0}}, 3*time.Second)},
			{"lightning", entity.NewLightning(o)},
			{"cloud", entity.NewAreaEffectCloud(o, potion.Harming())},
			{"falling_sand", entity.NewFallingBlock(o, block.Sand{})},
			{"text", entity.NewText("hello", o.Position)},
			{"item", entity.NewItem(o, item.NewStack(block.Dirt{}, 1))},
		} {
			e := tx.AddEntity(c.h)
			m := parseEntityMetadata(new(session.Session), e)
			if v, ok := m[protocol.EntityDataKeyDisplayFirework]; ok {
				// Go's map order is random: the NBT is written on its own
				// line with sorted keys, and left out of the metadata.
				delete(m, protocol.EntityDataKeyDisplayFirework)
				data, err := nbt.MarshalEncoding(sortedValue(v), nbt.NetworkLittleEndian)
				if err != nil {
					panic(err)
				}
				fmt.Fprintf(&b, "%s_nbt\t%s\n", c.name, hex.EncodeToString(data))
			}
			var buf bytes.Buffer
			protocol.NewWriter(&buf, 0).EntityMetadata(&m)
			fmt.Fprintf(&b, "%s\t%s\n", c.name, hex.EncodeToString(buf.Bytes()))
		}
	})
	return b.String()
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
	// Typed slices of maps ([]map[string]any): a non-empty one becomes a
	// list of structs; an empty one keeps its type, which decides the list's
	// element type (TAG_Compound).
	if rv := reflect.ValueOf(v); rv.Kind() == reflect.Slice && rv.Type().Elem().Kind() == reflect.Map && rv.Len() > 0 {
		out := make([]any, rv.Len())
		for i := range out {
			out[i] = sortedValue(rv.Index(i).Interface())
		}
		return out
	}
	return v
}
