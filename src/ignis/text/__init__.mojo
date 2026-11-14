"""Minecraft text formatting, ported from gophertunnel `minecraft/text`
(v1.63.0): the `§` formatting codes, `colourf` (HTML-like tags to codes),
`clean` and `ansi`.

Go's `Colourf(format, a...)` formats with `fmt.Sprintf` first; Mojo has no
`any` varargs, so `colourf(format, args)` takes the arguments as strings and
substitutes the verbs `%v`, `%s`, `%d` and `%%` the way `Sprintf` does for
string operands (`sprintf`). The tags are tokenized exactly as Go's
`golang.org/x/net/html` tokenizer does (`html.mojo`).
"""

from .colour import ansi, clean, colourf, sprintf
from .map import (
    AMETHYST,
    AQUA,
    BLACK,
    BLUE,
    BOLD,
    COPPER,
    DARK_AQUA,
    DARK_BLUE,
    DARK_GREEN,
    DARK_GREY,
    DARK_PURPLE,
    DARK_RED,
    DARK_YELLOW,
    DIAMOND,
    EMERALD,
    GOLD,
    GREEN,
    GREY,
    IRON,
    ITALIC,
    LAPIS,
    NETHERITE,
    OBFUSCATED,
    ORANGE,
    PURPLE,
    QUARTZ,
    RED,
    REDSTONE,
    RESET,
    RESIN,
    WHITE,
    YELLOW,
)
