"""Recipes, ported from Dragonfly `server/item/recipe`.

Go keeps the registered recipes, the brewing index and the item tags in
package globals; Ignis builds a `Recipes` value once
(`vanilla.load_vanilla_recipes`) and the server keeps it.
"""
