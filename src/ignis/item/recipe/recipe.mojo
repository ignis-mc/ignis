"""Recipes, ported from Dragonfly `server/item/recipe/recipe.go`.

Go has one type per kind of recipe behind the `Recipe` interface (and the
embedded `recipe` struct); here `Recipe` is one struct whose `kind` says
which Go type it is, with Go's constructors as functions. The `Input`,
`Output`, `Block` and `Priority` methods are shared; `shape` belongs to
shaped recipes and `uuid` to multi recipes.
"""

from minecraft.protocol.uuid import UUID

from ...internal.enum import enum_name
from ..stack import Stack
from .item import Item
from .shape import Shape


@fieldwise_init
struct RecipeKind(Equatable, ImplicitlyCopyable, Writable):
    """Which Go recipe type a `Recipe` is."""

    var _v: UInt8

    comptime SHAPELESS = RecipeKind(0)
    """Go `Shapeless`."""
    comptime USER_DATA_SHAPELESS = RecipeKind(1)
    """Go `UserDataShapeless`."""
    comptime MULTI = RecipeKind(2)
    """Go `Multi`."""
    comptime SMITHING_TRANSFORM = RecipeKind(3)
    """Go `SmithingTransform`."""
    comptime SMITHING_TRIM = RecipeKind(4)
    """Go `SmithingTrim`."""
    comptime POTION_CONTAINER_CHANGE = RecipeKind(5)
    """Go `PotionContainerChange`."""
    comptime POTION = RecipeKind(6)
    """Go `Potion`."""
    comptime SHAPED = RecipeKind(7)
    """Go `Shaped`."""

    def write_to(self, mut writer: Some[Writer]):
        """Writes the Go type name."""
        writer.write(
            enum_name(
                (
                    "Shapeless,UserDataShapeless,Multi,SmithingTransform,"
                    "SmithingTrim,PotionContainerChange,Potion,Shaped"
                ),
                Int(self._v),
            )
        )


struct Recipe(Copyable):
    """A recipe of any kind (Go `Recipe` and its implementations)."""

    var kind: RecipeKind
    """The Go type of the recipe."""
    var _input: List[Item]
    var _output: List[Stack]
    var _block: String
    var _priority: UInt32
    var _shape: Shape
    var _uuid: UUID

    def __init__(
        out self,
        kind: RecipeKind,
        var input: List[Item],
        var output: List[Stack],
        var block: String,
        priority: UInt32 = 0,
        shape: Shape = Shape(0, 0),
        uuid: UUID = UUID(),
    ):
        """Creates a recipe; use the `new_*` functions."""
        self.kind = kind
        self._input = input^
        self._output = output^
        self._block = block^
        self._priority = priority
        self._shape = shape
        self._uuid = uuid

    def input(ref self) -> ref[self._input] List[Item]:
        """Returns the items required to craft the recipe (Go `Input`)."""
        return self._input

    def output(ref self) -> ref[self._output] List[Stack]:
        """Returns the items the recipe gives (Go `Output`)."""
        return self._output

    def block(self) -> String:
        """Returns the block the recipe is crafted at (Go `Block`)."""
        return self._block

    def priority(self) -> UInt32:
        """Returns the recipe's priority among equal ones (Go `Priority`)."""
        return self._priority

    def shape(self) -> Shape:
        """Returns the shape of a shaped recipe (Go `Shaped.Shape`)."""
        return self._shape

    def uuid(self) -> UUID:
        """Returns the UUID of a multi recipe (Go `Multi.UUID`)."""
        return self._uuid


def new_shapeless(
    var input: List[Item], var output: Stack, var block: String
) -> Recipe:
    """Creates a shapeless recipe (Go `NewShapeless`)."""
    return Recipe(RecipeKind.SHAPELESS, input^, [output^], block^)


def new_user_data_shapeless(
    var input: List[Item], var output: Stack, var block: String
) -> Recipe:
    """Creates a shapeless recipe that keeps item user data (Go
    `NewUserDataShapeless`)."""
    return Recipe(RecipeKind.USER_DATA_SHAPELESS, input^, [output^], block^)


def new_multi(id: UUID) -> Recipe:
    """Creates a recipe the client computes itself (Go `NewMulti`)."""
    return Recipe(
        RecipeKind.MULTI, List[Item](), List[Stack](), "crafting_table", uuid=id
    )


def new_smithing_transform(
    var base: Item,
    var addition: Item,
    var template: Item,
    var output: Stack,
    var block: String,
) -> Recipe:
    """Creates a smithing table upgrade (Go `NewSmithingTransform`)."""
    return Recipe(
        RecipeKind.SMITHING_TRANSFORM,
        [base^, addition^, template^],
        [output^],
        block^,
    )


def new_smithing_trim(
    var base: Item, var addition: Item, var template: Item, var block: String
) -> Recipe:
    """Creates a smithing table trim recipe (Go `NewSmithingTrim`)."""
    return Recipe(
        RecipeKind.SMITHING_TRIM,
        [base^, addition^, template^],
        List[Stack](),
        block^,
    )


def new_potion_container_change(
    var input: Stack, var output: Stack, var reagent: Stack
) -> Recipe:
    """Creates a brewing recipe that changes a potion's container (Go
    `NewPotionContainerChange`, taking stacks of one item)."""
    return Recipe(
        RecipeKind.POTION_CONTAINER_CHANGE,
        [Item(input^), Item(reagent^)],
        [output^],
        "brewing_stand",
    )


def new_potion(var input: Item, var reagent: Item, var output: Stack) -> Recipe:
    """Creates a brewing recipe (Go `NewPotion`)."""
    return Recipe(
        RecipeKind.POTION, [input^, reagent^], [output^], "brewing_stand"
    )


def new_shaped(
    var input: List[Item], var output: Stack, shape: Shape, var block: String
) -> Recipe:
    """Creates a shaped recipe (Go `NewShaped`)."""
    return Recipe(RecipeKind.SHAPED, input^, [output^], block^, shape=shape)
