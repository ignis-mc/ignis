"""The recipe packet, ported from `sendRecipes`, `stacksToRecipeStacks` and
`stacksToIngredientItems` in Dragonfly `server/session/player.go`.

Go gives every recipe a random `uuid.New()` recipe ID; `crafting_data`
takes the IDs from the caller (`random_recipe_ids` makes Go's), so that the
packet can be compared byte for byte.
"""

from minecraft.protocol.item import ItemStack
from minecraft.protocol.item_descriptor import (
    DefaultItemDescriptor,
    InvalidItemDescriptor,
    ItemDescriptor,
    ItemDescriptorCount,
    ItemTagItemDescriptor,
)
from minecraft.protocol.packet.crafting_data import CraftingData
from minecraft.protocol.recipe import (
    MultiRecipe,
    PotionContainerChangeRecipe,
    PotionRecipe,
    ShapedRecipe,
    ShapelessRecipe,
    SmithingTransformRecipe,
    SmithingTrimRecipe,
)
from minecraft.protocol.uuid import UUID
from nethernet.os.random import random_bytes

from ..item.recipe.item import VARIANTS_META, Item
from ..item.recipe.recipe import RecipeKind
from ..item.recipe.register import Recipes
from ..item.register import VanillaBlockItems
from ..item.stack import Stack
from ..world.block_registry import BasicBlockRegistry
from ..world.item import EncodedItem, ItemRegistry
from .creative import delete_damage
from .item import stack_from_item


def random_recipe_ids(n: Int) raises -> List[String]:
    """Returns `n` random UUID strings, Go's `uuid.New().String()`."""
    var out = List[String](capacity=n)
    for _ in range(n):
        out.append(String(UUID.from_random(Span(random_bytes(16)))))
    return out^


def crafting_data(
    br: BasicBlockRegistry,
    reg: ItemRegistry,
    recipes: Recipes,
    recipe_ids: List[String],
) raises -> CraftingData:
    """Builds the `CraftingData` packet (Go `sendRecipes`): recipe `i`
    gets network ID `i + 1` and recipe ID `recipe_ids[i]`."""
    var pk = CraftingData()
    for index in range(len(recipes.recipes())):
        ref r = recipes.recipes()[index]
        var network_id = UInt32(index) + 1
        var id = recipe_ids[index]
        if r.kind == RecipeKind.SHAPELESS or (
            r.kind == RecipeKind.USER_DATA_SHAPELESS
        ):
            var s = ShapelessRecipe()
            s.recipe_id = id
            s.priority = Int32(r.priority())
            s.input = _ingredients(reg, r.input())
            s.output = _recipe_stacks(br, reg, r.output())
            s.block = r.block()
            s.recipe_network_id = network_id
            if r.kind == RecipeKind.SHAPELESS:
                pk.shapeless_recipes.append(s^)
            else:
                pk.user_data_shapeless_recipes.append(s^)
        elif r.kind == RecipeKind.MULTI:
            var m = MultiRecipe()
            m.uuid = r.uuid()
            m.recipe_network_id = network_id
            pk.multi_recipes.append(m^)
        elif r.kind == RecipeKind.SHAPED:
            var s = ShapedRecipe()
            s.recipe_id = id
            s.priority = Int32(r.priority())
            s.width = Int32(r.shape().width())
            s.height = Int32(r.shape().height())
            s.input = _ingredients(reg, r.input())
            s.output = _recipe_stacks(br, reg, r.output())
            s.block = r.block()
            s.assume_symmetry = True
            s.recipe_network_id = network_id
            pk.shaped_recipes.append(s^)
        elif r.kind == RecipeKind.SMITHING_TRANSFORM:
            var input = _ingredients(reg, r.input())
            var output = _recipe_stacks(br, reg, r.output())
            var s = SmithingTransformRecipe()
            s.recipe_id = id
            s.base = input[0].copy()
            s.addition = input[1].copy()
            s.template = input[2].copy()
            s.result = output[0].copy()
            s.block = r.block()
            s.recipe_network_id = network_id
            pk.smithing_transform_recipes.append(s^)
        elif r.kind == RecipeKind.SMITHING_TRIM:
            var input = _ingredients(reg, r.input())
            var s = SmithingTrimRecipe()
            s.recipe_id = id
            s.base = input[0].copy()
            s.addition = input[1].copy()
            s.template = input[2].copy()
            s.block = r.block()
            s.recipe_network_id = network_id
            pk.smithing_trim_recipes.append(s^)
        elif r.kind == RecipeKind.POTION:
            var input = _runtime_id(reg, r.input()[0].stack().value())
            var reagent = _runtime_id(reg, r.input()[1].stack().value())
            var output = _runtime_id(reg, r.output()[0])
            var p = PotionRecipe()
            p.input_potion_id = input[0]
            p.input_potion_metadata = input[1]
            p.reagent_item_id = reagent[0]
            p.reagent_item_metadata = reagent[1]
            p.output_potion_id = output[0]
            p.output_potion_metadata = output[1]
            pk.potion_recipes.append(p^)
        elif r.kind == RecipeKind.POTION_CONTAINER_CHANGE:
            var p = PotionContainerChangeRecipe()
            p.input_item_id = _runtime_id(reg, r.input()[0].stack().value())[0]
            p.reagent_item_id = _runtime_id(reg, r.input()[1].stack().value())[
                0
            ]
            p.output_item_id = _runtime_id(reg, r.output()[0])[0]
            pk.potion_container_change_recipes.append(p^)
    pk.clear_recipes = True
    return pk^


def _recipe_stacks(
    br: BasicBlockRegistry, reg: ItemRegistry, stacks: List[Stack]
) raises -> List[ItemStack]:
    """Go `stacksToRecipeStacks`."""
    var out = List[ItemStack](capacity=len(stacks))
    for s in stacks:
        out.append(delete_damage(stack_from_item(br, reg, s)))
    return out^


def _ingredients(
    reg: ItemRegistry, inputs: List[Item]
) raises -> List[ItemDescriptorCount]:
    """Go `stacksToIngredientItems`."""
    var out = List[ItemDescriptorCount](capacity=len(inputs))
    for i in inputs:
        var d = ItemDescriptor()
        if case .Some(st) = i.stack():
            if st.empty():
                out.append(ItemDescriptorCount(ItemDescriptor(), 0))
                continue
            var enc = _encode(reg, st)
            var meta = enc.meta
            if i.variants():
                meta = VARIANTS_META
            d = ItemDescriptor(DefaultItemDescriptor(enc.name, Int32(meta)))
        elif case .Some(t) = i.tag():
            d = ItemDescriptor(ItemTagItemDescriptor(t.tag()))
        out.append(ItemDescriptorCount(d^, Int32(i.count())))
    return out^


def _encode(reg: ItemRegistry, st: Stack) raises -> EncodedItem:
    var it = st.item().value()
    if it.block:
        if case .Some(enc) = VanillaBlockItems.encode_item(it.kind, it.hash):
            return enc
    elif case .Some(enc) = reg.encode_item(it):
        return enc
    raise Error(t"crafting_data: unregistered item {it}")


def _runtime_id(reg: ItemRegistry, st: Stack) raises -> Tuple[Int32, Int32]:
    """Go `world.ItemRuntimeID`: the runtime ID and metadata, zero for an
    unknown name."""
    var enc = _encode(reg, st)
    if case .Some(rid) = reg.runtime_id(enc.name):
        return (rid, Int32(enc.meta))
    return (Int32(0), Int32(enc.meta))
