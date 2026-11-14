"""The creative inventory, ported from Dragonfly `server/item/creative`.

Go keeps the groups and items in package globals filled by
`registerCreativeItems`; Ignis builds a `Creative` value once
(`load_creative_items`) and the server keeps it.
"""
