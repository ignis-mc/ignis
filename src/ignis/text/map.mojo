"""Minecraft formatting codes, ported from gophertunnel `minecraft/text/map.go`
(the colour constants, their ANSI equivalents and the tag names
`colourf` accepts)."""

comptime BLACK = "§0"
comptime DARK_BLUE = "§1"
comptime DARK_GREEN = "§2"
comptime DARK_AQUA = "§3"
comptime DARK_RED = "§4"
comptime DARK_PURPLE = "§5"
comptime ORANGE = "§6"
comptime GREY = "§7"
comptime DARK_GREY = "§8"
comptime BLUE = "§9"
comptime GREEN = "§a"
comptime AQUA = "§b"
comptime RED = "§c"
comptime PURPLE = "§d"
comptime YELLOW = "§e"
comptime WHITE = "§f"
comptime DARK_YELLOW = "§g"
comptime QUARTZ = "§h"
comptime IRON = "§i"
comptime NETHERITE = "§j"
comptime OBFUSCATED = "§k"
comptime BOLD = "§l"
comptime REDSTONE = "§m"
comptime COPPER = "§n"
comptime ITALIC = "§o"
comptime GOLD = "§p"
comptime EMERALD = "§q"
comptime RESET = "§r"
comptime DIAMOND = "§s"
comptime LAPIS = "§t"
comptime AMETHYST = "§u"
comptime RESIN = "§v"


def tag_format(name: StringSlice) -> String:
    """Returns the formatting code of a `colourf` tag name (Go `strMap`), or
    an empty string for an unknown name."""
    if name == "black":
        return String(BLACK)
    if name == "dark-blue":
        return String(DARK_BLUE)
    if name == "dark-green":
        return String(DARK_GREEN)
    if name == "dark-aqua":
        return String(DARK_AQUA)
    if name == "dark-red":
        return String(DARK_RED)
    if name == "dark-purple":
        return String(DARK_PURPLE)
    if name == "orange":
        return String(ORANGE)
    if name == "grey":
        return String(GREY)
    if name == "dark-grey":
        return String(DARK_GREY)
    if name == "blue":
        return String(BLUE)
    if name == "green":
        return String(GREEN)
    if name == "aqua":
        return String(AQUA)
    if name == "red":
        return String(RED)
    if name == "purple":
        return String(PURPLE)
    if name == "yellow":
        return String(YELLOW)
    if name == "white":
        return String(WHITE)
    if name == "dark-yellow":
        return String(DARK_YELLOW)
    if name == "quartz":
        return String(QUARTZ)
    if name == "iron":
        return String(IRON)
    if name == "netherite":
        return String(NETHERITE)
    if name == "obfuscated":
        return String(OBFUSCATED)
    if name == "bold" or name == "b":
        return String(BOLD)
    if name == "redstone":
        return String(REDSTONE)
    if name == "copper":
        return String(COPPER)
    if name == "gold":
        return String(GOLD)
    if name == "emerald":
        return String(EMERALD)
    if name == "italic" or name == "i":
        return String(ITALIC)
    if name == "diamond":
        return String(DIAMOND)
    if name == "lapis":
        return String(LAPIS)
    if name == "amethyst":
        return String(AMETHYST)
    if name == "resin":
        return String(RESIN)
    return ""


def ansi_code(code: UInt8) -> Optional[String]:
    """Returns the ANSI escape for the byte after `§` (Go `m`), or None if
    the code is unknown."""
    var c = chr(Int(code))
    if c == "0":
        return String("\x1b[38;5;16m")
    if c == "1":
        return String("\x1b[38;5;19m")
    if c == "2":
        return String("\x1b[38;5;34m")
    if c == "3":
        return String("\x1b[38;5;37m")
    if c == "4":
        return String("\x1b[38;5;124m")
    if c == "5":
        return String("\x1b[38;5;127m")
    if c == "6":
        return String("\x1b[38;5;214m")
    if c == "7":
        return String("\x1b[38;5;145m")
    if c == "8":
        return String("\x1b[38;5;59m")
    if c == "9":
        return String("\x1b[38;5;63m")
    if c == "a":
        return String("\x1b[38;5;83m")
    if c == "b":
        return String("\x1b[38;5;87m")
    if c == "c":
        return String("\x1b[38;5;203m")
    if c == "d":
        return String("\x1b[38;5;207m")
    if c == "e":
        return String("\x1b[38;5;227m")
    if c == "f":
        return String("\x1b[38;5;231m")
    if c == "g":
        return String("\x1b[38;5;226m")
    if c == "h":
        return String("\x1b[38;5;224m")
    if c == "i":
        return String("\x1b[38;5;251m")
    if c == "j":
        return String("\x1b[38;5;234m")
    if c == "k":
        return String("")
    if c == "l":
        return String("\x1b[1m")
    if c == "m":
        return String("\x1b[38;5;1m")
    if c == "n":
        return String("\x1b[38;5;216m")
    if c == "o":
        return String("\x1b[3m")
    if c == "p":
        return String("\x1b[38;5;220m")
    if c == "q":
        return String("\x1b[38;5;71m")
    if c == "r":
        return String("\x1b[m")
    if c == "s":
        return String("\x1b[38;5;122m")
    if c == "t":
        return String("\x1b[38;5;4m")
    if c == "u":
        return String("\x1b[38;5;171m")
    if c == "v":
        return String("\x1b[38;5;172m")
    return None
