# LevelDB and world interop

`main.go` imports `github.com/df-mc/goleveldb` v1.1.9 and Dragonfly v0.11.6
(pinned in `go.mod`) and produces or checks what the Mojo ports in
`src/ignis/leveldb` and `src/ignis/world/mcdb` must match.

| Command | Purpose |
| --- | --- |
| `go run . ldb-fixtures ../../test/data/leveldb` | goleveldb tables (none, snappy, bloom, DEFLATE) and a journal; Mojo must write the same bytes |
| `go run . ldb-write ../../test/data/leveldb/goleveldb-unclean 11 250 unclean` | a database left by an unclean stop (then delete its `LOG` and `LOCK`) |
| `go run . upgrade-vectors ../../resources/legacy_states.nbt ../../test/data/world/upgrade_vectors.txt` | stored block states decoded by Dragonfly (hash, count and a sample) |
| `go run . world-write <dir>` / `world-dump <dir> <out>` | the fixture world written with Dragonfly's mcdb, and a dump of what Dragonfly loads |

`test/data/mcdb/dragonfly-world/` is `world-write`'s output (without `LOCK`
and `LOG`; its data is still in the journal) and
`test/data/mcdb/dragonfly-world.txt` its `world-dump`.

Live round trips, both directions, from the repository root:

```sh
interop/mcdb/run_leveldb.sh   # goleveldb <-> ignis.leveldb, unclean stops, torn journals
interop/mcdb/run_world.sh     # Dragonfly mcdb <-> ignis.world.mcdb
```

`ldbtool.mojo` and `worldtool.mojo` are the Mojo halves; they share the
workload and fixture definitions in `test/support/`.

## Vanilla client check (manual)

With the minecraft MCP (`mcp-call`, see its headless skill), a world
created and saved by the vanilla 1.26.60 client was:

1. dumped with `world-dump <copy> <out> lenient` and
   `worldtool dump <copy> <out> lenient` after removing `level.dat` from
   the copies (Dragonfly v0.11.6 cannot decode a 1.26.60 `level.dat`; it
   has `editorLevelMigrationVersion`): identical;
2. edited with `worldtool tower <world> <cx> <cz> "Ignis Mojo"` (which also
   rewrites every table) and opened in the vanilla client, which showed the
   tower and the renamed world;
3. dumped again after the client saved on top of Ignis's table: identical.

`test/data/mcdb/vanilla-1.26.60-level.dat` is that world's `level.dat`.
