"""The vanilla recipes, ported from Dragonfly
`server/item/recipe/vanilla.go`.

`register_vanilla` reads the four data files as Go's `registerVanilla`
does, skipping recipes with items that are not registered.
"""

from minecraft.nbt.decode import decode
from minecraft.nbt.nbt import NETWORK_LITTLE_ENDIAN
from minecraft.nbt.tree import Tag, Tree
from minecraft.protocol.uuid import UUID

from ...internal.nbtconv.read import get_int32, get_string
from ...world.block_registry import BasicBlockRegistry
from ...world.item import ItemRegistry
from ..stack import Stack
from .dynamic import new_decorated_pot_recipe
from .item import Item, input_item, input_items, output_item, output_items
from .item_tag import ItemTags
from .recipe import Recipe, RecipeKind, new_multi
from .register import Recipes
from .shape import Shape

comptime RECIPE_DIR = "resources"
"""Where the recipe data files live, relative to the repository root."""


def register_vanilla(
    br: BasicBlockRegistry,
    reg: ItemRegistry,
    tags: ItemTags,
    crafting_data: Span[UInt8, _],
    smithing_data: Span[UInt8, _],
    smithing_trim_data: Span[UInt8, _],
    potion_data: Span[UInt8, _],
) raises -> Recipes:
    """Registers every vanilla recipe (Go `registerVanilla`)."""
    var out = Recipes()
    var crafting = decode(crafting_data, NETWORK_LITTLE_ENDIAN)
    var root = crafting.root()

    if case .Some(multi) = crafting.get(root, "multi"):
        for id in crafting.children(multi):
            var u: UUID
            try:
                u = UUID.parse(crafting.as_string(id))
            except:
                continue
            out.register(new_multi(u), reg)

    _register_list(
        out,
        crafting,
        root,
        "shulker_box",
        RecipeKind.USER_DATA_SHAPELESS,
        br,
        reg,
        tags,
    )
    _register_list(
        out, crafting, root, "shapeless", RecipeKind.SHAPELESS, br, reg, tags
    )
    _register_list(
        out, crafting, root, "shaped", RecipeKind.SHAPED, br, reg, tags
    )

    var smithing = decode(smithing_data, NETWORK_LITTLE_ENDIAN)
    for s in smithing.children(smithing.root()):
        _register_one(
            out, smithing, s, RecipeKind.SMITHING_TRANSFORM, br, reg, tags
        )

    var trim = decode(smithing_trim_data, NETWORK_LITTLE_ENDIAN)
    for s in trim.children(trim.root()):
        _register_one(out, trim, s, RecipeKind.SMITHING_TRIM, br, reg, tags)

    var potions = decode(potion_data, NETWORK_LITTLE_ENDIAN)
    var proot = potions.root()
    if case .Some(l) = potions.get(proot, "potions"):
        for r in potions.children(l):
            var input = input_item(
                potions, potions.get_compound(r, "input"), reg, tags
            )
            var reagent = input_item(
                potions, potions.get_compound(r, "reagent"), reg, tags
            )
            var output = output_item(
                potions, potions.get_compound(r, "output"), br, reg
            )
            if not input or not reagent or not output:
                continue
            out.register(
                Recipe(
                    RecipeKind.POTION,
                    [input.value().copy(), reagent.value().copy()],
                    [output.value().copy()],
                    "brewing_stand",
                ),
                reg,
            )
    if case .Some(l) = potions.get(proot, "container_changes"):
        for c in potions.children(l):
            var input = reg.item_by_name(get_string(potions, c, "input"), 0)
            var reagent = input_item(
                potions, potions.get_compound(c, "reagent"), reg, tags
            )
            var output = reg.item_by_name(get_string(potions, c, "output"), 0)
            if not input or not reagent or not output:
                continue
            out.register(
                Recipe(
                    RecipeKind.POTION_CONTAINER_CHANGE,
                    [Item(Stack(input.value(), 1)), reagent.value().copy()],
                    [Stack(output.value(), 1)],
                    "brewing_stand",
                ),
                reg,
            )

    out.register_dynamic(new_decorated_pot_recipe())
    return out^


def load_vanilla_recipes(
    br: BasicBlockRegistry, reg: ItemRegistry, dir: String = RECIPE_DIR
) raises -> Recipes:
    """Reads the vanilla recipe data files and `item_tags.json` from a
    directory and registers every recipe."""
    var tags = ItemTags.load(dir + "/item_tags.json")
    var crafting = _read(dir + "/crafting_data.nbt")
    var smithing = _read(dir + "/smithing_data.nbt")
    var trim = _read(dir + "/smithing_trim_data.nbt")
    var potion = _read(dir + "/potion_data.nbt")
    return register_vanilla(
        br,
        reg,
        tags,
        Span(crafting),
        Span(smithing),
        Span(trim),
        Span(potion),
    )


def _read(path: String) raises -> List[UInt8]:
    with open(path, "r") as f:
        return f.read_bytes()


def _register_list(
    mut out: Recipes,
    tree: Tree,
    root: Tag,
    key: StringSlice,
    kind: RecipeKind,
    br: BasicBlockRegistry,
    reg: ItemRegistry,
    tags: ItemTags,
) raises:
    if case .Some(l) = tree.get(root, key):
        for s in tree.children(l):
            _register_one(out, tree, s, kind, br, reg, tags)


def _register_one(
    mut out: Recipes,
    tree: Tree,
    s: Tag,
    kind: RecipeKind,
    br: BasicBlockRegistry,
    reg: ItemRegistry,
    tags: ItemTags,
) raises:
    """Registers one `shapedRecipe` or `shapelessRecipe` entry as a recipe
    of the kind passed, unless one of its items is not registered."""
    var input = input_items(tree, tree.get_list(s, "input"), reg, tags)
    if not input:
        return
    var output = List[Stack]()
    if kind != RecipeKind.SMITHING_TRIM:
        var o = output_items(tree, tree.get_list(s, "output"), br, reg)
        if not o:
            return
        output = o.value().copy()
    var shape = Shape(0, 0)
    if kind == RecipeKind.SHAPED:
        shape = Shape(
            Int(get_int32(tree, s, "width")), Int(get_int32(tree, s, "height"))
        )
    out.register(
        Recipe(
            kind,
            input.value().copy(),
            output^,
            get_string(tree, s, "block"),
            priority=UInt32(get_int32(tree, s, "priority")),
            shape=shape,
        ),
        reg,
    )
