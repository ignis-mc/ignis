"""The recipe registry, ported from Dragonfly
`server/item/recipe/register.go`.

Go's package globals (`recipes`, `dynamicRecipes`, `index`, `reagent`)
are the fields of `Recipes`. Go's `hashItems` key concatenates names with
the raw bytes of their metadata; Ignis writes the metadata in decimal
after a `:`, which identifies the same item lists and keeps the key valid
UTF-8. Items are passed by their `EncodeItem` result.
"""

from std.collections import Dict

from ...world.item import EncodedItem, ItemRegistry
from ..stack import Stack
from .dynamic import DecoratedPotRecipe
from .recipe import Recipe, RecipeKind


struct Recipes(Copyable, Defaultable):
    """Every registered recipe and the brewing index (Go's globals)."""

    var _recipes: List[Recipe]
    var _dynamic: List[DecoratedPotRecipe]
    var _index: Dict[String, Dict[String, Int]]
    var _reagent: Dict[String, Stack]

    def __init__(out self):
        """Creates an empty registry."""
        self._recipes = List[Recipe]()
        self._dynamic = List[DecoratedPotRecipe]()
        self._index = Dict[String, Dict[String, Int]]()
        self._reagent = Dict[String, Stack]()

    def recipes(ref self) -> ref[self._recipes] List[Recipe]:
        """Returns every recipe in registration order (Go `Recipes`)."""
        return self._recipes

    def dynamic_recipes(
        ref self,
    ) -> ref[self._dynamic] List[DecoratedPotRecipe]:
        """Returns every dynamic recipe (Go `DynamicRecipes`)."""
        return self._dynamic

    def register(mut self, var recipe: Recipe, reg: ItemRegistry) raises:
        """Registers a recipe (Go `Register`); brewing recipes are also
        indexed by their inputs."""
        var container = recipe.kind == RecipeKind.POTION_CONTAINER_CHANGE
        var potion = recipe.kind == RecipeKind.POTION
        if potion:
            var st = recipe.input()[1].stack().value().copy()
            var name = _encode(reg, st).name
            self._reagent[name] = st^
        if container or potion:
            var input = List[EncodedItem]()
            for i in recipe.input():
                if case .Some(st) = i.stack():
                    if not st.empty():
                        input.append(_encode(reg, st))
            var hash = hash_items(input^, not container)
            var block = recipe.block()
            if block not in self._index:
                self._index[block] = Dict[String, Int]()
            self._index[block][hash] = len(self._recipes)
        self._recipes.append(recipe^)

    def register_dynamic(mut self, var recipe: DecoratedPotRecipe):
        """Registers a recipe validated by the server only (Go
        `RegisterDynamic`)."""
        self._dynamic.append(recipe^)

    def perform(
        self, block: String, input: List[EncodedItem], reg: ItemRegistry
    ) raises -> Optional[List[Stack]]:
        """Returns the outputs of the brewing recipe of a block for the
        inputs passed, or None if there is none (Go `Perform`)."""
        if block not in self._index:
            return None
        ref block_index = self._index[block]
        var key = hash_items(input.copy(), True)
        if key not in block_index:
            key = hash_items(input.copy(), False)
            if key not in block_index:
                return None
        ref r = self._recipes[block_index[key]]
        var container = r.kind == RecipeKind.POTION_CONTAINER_CHANGE
        var out = List[Stack]()
        for ind in range(len(r.output())):
            var it = r.output()[ind].copy()
            if container:
                var name = _encode(reg, it).name
                if case .Some(found) = reg.item_by_name(name, input[ind].meta):
                    it = Stack(found, it.count())
            out.append(it^)
        return out^

    def valid_brewing_reagent(self, it: EncodedItem) -> Bool:
        """Reports whether an item is a brewing reagent (Go
        `ValidBrewingReagent`)."""
        return it.name in self._reagent


def hash_items(var items: List[EncodedItem], use_meta: Bool) -> String:
    """Returns a key for a list of items regardless of their order (Go
    `hashItems`)."""
    for i in range(1, len(items)):
        var j = i
        while j > 0 and _less(items[j], items[j - 1]):
            items.swap_elements(j, j - 1)
            j -= 1
    var out = String()
    for it in items:
        out += it.name
        if use_meta:
            out += String(t":{it.meta};")
    return out^


def _less(a: EncodedItem, b: EncodedItem) -> Bool:
    if a.name == b.name:
        return a.meta < b.meta
    return a.name < b.name


def _encode(reg: ItemRegistry, st: Stack) raises -> EncodedItem:
    if case .Some(it) = st.item():
        if case .Some(enc) = reg.encode_item(it):
            return enc
    raise Error(t"recipe: unregistered item {st}")
