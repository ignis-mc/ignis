package main

import (
	"bytes"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strings"

	"github.com/df-mc/dragonfly/server/item"
	"github.com/df-mc/dragonfly/server/item/recipe"
	"github.com/df-mc/dragonfly/server/world"
	"github.com/sandertv/gophertunnel/minecraft/protocol"
	"github.com/sandertv/gophertunnel/minecraft/protocol/packet"
)

// sortedIO is a protocol.Writer whose item stacks are written with their
// NBT keys sorted (see writeItem).
type sortedIO struct{ *protocol.Writer }

func (w sortedIO) Item(x *protocol.ItemStack) { writeItem(w.Writer, x) }

// craftingData is Session.sendRecipes (server/session/player.go) with every
// RecipeID empty instead of a random UUID.
func craftingData() *packet.CraftingData {
	pk := &packet.CraftingData{ClearRecipes: true}
	for index, i := range recipe.Recipes() {
		networkID := uint32(index) + 1
		switch i := i.(type) {
		case recipe.Shapeless:
			pk.ShapelessRecipes = append(pk.ShapelessRecipes, protocol.ShapelessRecipe{
				Priority:        int32(i.Priority()),
				Input:           stacksToIngredientItems(i.Input()),
				Output:          stacksToRecipeStacks(i.Output()),
				Block:           i.Block(),
				RecipeNetworkID: networkID,
			})
		case recipe.UserDataShapeless:
			pk.UserDataShapelessRecipes = append(pk.UserDataShapelessRecipes, protocol.UserDataShapelessRecipe{ShapelessRecipe: protocol.ShapelessRecipe{
				Priority:        int32(i.Priority()),
				Input:           stacksToIngredientItems(i.Input()),
				Output:          stacksToRecipeStacks(i.Output()),
				Block:           i.Block(),
				RecipeNetworkID: networkID,
			}})
		case recipe.Multi:
			pk.MultiRecipes = append(pk.MultiRecipes, protocol.MultiRecipe{UUID: i.UUID(), RecipeNetworkID: networkID})
		case recipe.Shaped:
			pk.ShapedRecipes = append(pk.ShapedRecipes, protocol.ShapedRecipe{
				Priority:        int32(i.Priority()),
				Width:           int32(i.Shape().Width()),
				Height:          int32(i.Shape().Height()),
				Input:           stacksToIngredientItems(i.Input()),
				Output:          stacksToRecipeStacks(i.Output()),
				Block:           i.Block(),
				AssumeSymmetry:  true,
				RecipeNetworkID: networkID,
			})
		case recipe.SmithingTransform:
			input, output := stacksToIngredientItems(i.Input()), stacksToRecipeStacks(i.Output())
			pk.SmithingTransformRecipes = append(pk.SmithingTransformRecipes, protocol.SmithingTransformRecipe{
				Base: input[0], Addition: input[1], Template: input[2], Result: output[0],
				Block: i.Block(), RecipeNetworkID: networkID,
			})
		case recipe.SmithingTrim:
			input := stacksToIngredientItems(i.Input())
			pk.SmithingTrimRecipes = append(pk.SmithingTrimRecipes, protocol.SmithingTrimRecipe{
				Base: input[0], Addition: input[1], Template: input[2],
				Block: i.Block(), RecipeNetworkID: networkID,
			})
		case recipe.Potion:
			inputRuntimeID, inputMeta, _ := world.ItemRuntimeID(i.Input()[0].(item.Stack).Item())
			reagentRuntimeID, reagentMeta, _ := world.ItemRuntimeID(i.Input()[1].(item.Stack).Item())
			outputRuntimeID, outputMeta, _ := world.ItemRuntimeID(i.Output()[0].Item())
			pk.PotionRecipes = append(pk.PotionRecipes, protocol.PotionRecipe{
				InputPotionID: inputRuntimeID, InputPotionMetadata: int32(inputMeta),
				ReagentItemID: reagentRuntimeID, ReagentItemMetadata: int32(reagentMeta),
				OutputPotionID: outputRuntimeID, OutputPotionMetadata: int32(outputMeta),
			})
		case recipe.PotionContainerChange:
			inputRuntimeID, _, _ := world.ItemRuntimeID(i.Input()[0].(item.Stack).Item())
			reagentRuntimeID, _, _ := world.ItemRuntimeID(i.Input()[1].(item.Stack).Item())
			outputRuntimeID, _, _ := world.ItemRuntimeID(i.Output()[0].Item())
			pk.PotionContainerChangeRecipes = append(pk.PotionContainerChangeRecipes, protocol.PotionContainerChangeRecipe{
				InputItemID: inputRuntimeID, ReagentItemID: reagentRuntimeID, OutputItemID: outputRuntimeID,
			})
		}
	}
	return pk
}

// stacksToRecipeStacks is session.stacksToRecipeStacks.
func stacksToRecipeStacks(inputs []item.Stack) []protocol.ItemStack {
	items := make([]protocol.ItemStack, 0, len(inputs))
	for _, i := range inputs {
		items = append(items, deleteDamage(stackFromItem(i)))
	}
	return items
}

// stacksToIngredientItems is session.stacksToIngredientItems.
func stacksToIngredientItems(inputs []recipe.Item) []protocol.ItemDescriptorCount {
	items := make([]protocol.ItemDescriptorCount, 0, len(inputs))
	for _, i := range inputs {
		var d protocol.ItemDescriptor = &protocol.InvalidItemDescriptor{}
		switch i := i.(type) {
		case item.Stack:
			if i.Empty() {
				items = append(items, protocol.ItemDescriptorCount{Descriptor: &protocol.InvalidItemDescriptor{}})
				continue
			}
			name, meta := i.Item().EncodeItem()
			if _, ok := i.Value("variants"); ok {
				meta = math.MaxInt16
			}
			d = &protocol.DefaultItemDescriptor{Name: name, MetadataValue: int32(meta)}
		case recipe.ItemTag:
			d = &protocol.ItemTagItemDescriptor{Tag: i.Tag()}
		}
		items = append(items, protocol.ItemDescriptorCount{Descriptor: d, Count: int32(i.Count())})
	}
	return items
}

func descriptor(d protocol.ItemDescriptorCount) string {
	switch x := d.Descriptor.(type) {
	case *protocol.DefaultItemDescriptor:
		return fmt.Sprintf("%s:%d*%d", x.Name, x.MetadataValue, d.Count)
	case *protocol.ItemTagItemDescriptor:
		return fmt.Sprintf("#%s*%d", x.Tag, d.Count)
	}
	return fmt.Sprintf("-*%d", d.Count)
}

func craftStack(s protocol.ItemStack) string {
	n := "{}"
	if len(s.NBTData) != 0 {
		n = canonical(s.NBTData)
	}
	return fmt.Sprintf("%d:%d*%d %d %s", s.NetworkID, s.MetadataValue, s.Count, s.BlockRuntimeID, n)
}

func descriptors(ds []protocol.ItemDescriptorCount) string {
	parts := make([]string, len(ds))
	for i, d := range ds {
		parts[i] = descriptor(d)
	}
	return strings.Join(parts, ",")
}

func craftStacks(ss []protocol.ItemStack) string {
	parts := make([]string, len(ss))
	for i, s := range ss {
		parts[i] = craftStack(s)
	}
	return strings.Join(parts, ",")
}

// craftingVectors writes crafting.txt, one line per recipe of the
// CraftingData packet (type, network ID, then the type's fields, inputs as
// "name:meta*count" or "#tag*count", outputs as in creative.txt), and
// crafting_data.bin, the packet with empty recipe IDs and sorted NBT keys.
func craftingVectors(out string) {
	pk := craftingData()
	var b strings.Builder
	for _, r := range pk.ShapedRecipes {
		fmt.Fprintf(&b, "shaped\t%d\t%d\t%s\t%dx%d\t%s\t%s\n", r.RecipeNetworkID, r.Priority, r.Block, r.Width, r.Height, descriptors(r.Input), craftStacks(r.Output))
	}
	for _, r := range pk.ShapelessRecipes {
		fmt.Fprintf(&b, "shapeless\t%d\t%d\t%s\t%s\t%s\n", r.RecipeNetworkID, r.Priority, r.Block, descriptors(r.Input), craftStacks(r.Output))
	}
	for _, r := range pk.MultiRecipes {
		fmt.Fprintf(&b, "multi\t%d\t%s\n", r.RecipeNetworkID, r.UUID)
	}
	for _, r := range pk.UserDataShapelessRecipes {
		fmt.Fprintf(&b, "userdata\t%d\t%d\t%s\t%s\t%s\n", r.RecipeNetworkID, r.Priority, r.Block, descriptors(r.Input), craftStacks(r.Output))
	}
	for _, r := range pk.SmithingTransformRecipes {
		fmt.Fprintf(&b, "smithing\t%d\t%s\t%s\t%s\n", r.RecipeNetworkID, r.Block, descriptors([]protocol.ItemDescriptorCount{r.Template, r.Base, r.Addition}), craftStack(r.Result))
	}
	for _, r := range pk.SmithingTrimRecipes {
		fmt.Fprintf(&b, "trim\t%d\t%s\t%s\n", r.RecipeNetworkID, r.Block, descriptors([]protocol.ItemDescriptorCount{r.Template, r.Base, r.Addition}))
	}
	for _, r := range pk.PotionRecipes {
		fmt.Fprintf(&b, "potion\t%d:%d\t%d:%d\t%d:%d\n", r.InputPotionID, r.InputPotionMetadata, r.ReagentItemID, r.ReagentItemMetadata, r.OutputPotionID, r.OutputPotionMetadata)
	}
	for _, r := range pk.PotionContainerChangeRecipes {
		fmt.Fprintf(&b, "container\t%d\t%d\t%d\n", r.InputItemID, r.ReagentItemID, r.OutputItemID)
	}
	must(os.WriteFile(filepath.Join(out, "crafting.txt"), []byte(b.String()), 0o644))

	buf := new(bytes.Buffer)
	pk.Marshal(sortedIO{protocol.NewWriter(buf, 0)})
	ref := new(bytes.Buffer)
	pk.Marshal(protocol.NewWriter(ref, 0))
	if ref.Len() != buf.Len() {
		panic(fmt.Sprintf("sorted CraftingData is %d bytes, gophertunnel's %d", buf.Len(), ref.Len()))
	}
	must(os.WriteFile(filepath.Join(out, "crafting_data.bin"), buf.Bytes(), 0o644))
}
