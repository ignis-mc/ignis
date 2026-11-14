"""Dynamic recipes, ported from Dragonfly `server/item/recipe/dynamic.go`.

TODO(world-runtime): `DecoratedPotRecipe.Match`, which builds the decorated
pot from pot decorations when the crafting grid is checked.
"""


@fieldwise_init
struct DecoratedPotRecipe(Copyable):
    """The recipe of a decorated pot from four pot decorations, validated
    by the server (Go `DecoratedPotRecipe`)."""

    var _block: String

    def block(self) -> String:
        """Returns the block the recipe is crafted at (Go `Block`)."""
        return self._block


def new_decorated_pot_recipe() -> DecoratedPotRecipe:
    """Creates the recipe (Go `NewDecoratedPotRecipe`)."""
    return DecoratedPotRecipe("crafting_table")
