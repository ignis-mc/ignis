# Agent guide for `ignis`

`ignis` is a Minecraft: Bedrock Edition server in pure Mojo, ported from
[Dragonfly](https://github.com/df-mc/dragonfly) v0.11.6 (protocol 2225,
Minecraft 1.26.60). It speaks the protocol from the `protocol` submodule
(a port of gophertunnel) over NetherNet from the `nethernet` submodule.
**There is no RakNet and there never will be.** No C bindings or FFI
(`external_call`) and no Python interop, in this repo or its dependencies.

This file is the single source of truth for coding agents. `CLAUDE.md` only
points here.

## Toolchain

- Mojo is pinned to **1.2.x** (`pixi.toml`). Run everything through
  `pixi run <task>`, or put a Mojo 1.2 `mojo` on `PATH`
  (`/home/xd/.local/share/mojo-env/bin/mojo` on the development host).
- Every compile needs all three include roots, and tests also `-I test`
  for the shared helpers in `test/support/`:
  `mojo run --fp-mode contract=off -I src -I test -I third_party/protocol/src -I third_party/nethernet/src -D ASSERT=all test/ignis/test_version.mojo`.
  The test binary accepts `--only <names…>`, `--skip <names…>`. Tests run
  from the repository root (they read `resources/` and `test/data/`).
- Build and run with `--fp-mode contract=off` (as `scripts/run_tests.sh`
  does). Mojo fuses `a + b*c` into FMA instructions by default, which
  rounds differently from Go on amd64; without the flag float results such
  as ray-trace hit points drift from Dragonfly's by an ulp.
- Tasks: `pixi run test`, `format`, `format-check`, `lint-docs`, `build`,
  `check`.
- After every edit, compile and run the affected test file. Do not report a
  change as working without that output.
- Go reference source is in the module cache:
  `~/go/pkg/mod/github.com/df-mc/dragonfly@v0.11.6/server/` and
  `~/go/pkg/mod/github.com/sandertv/gophertunnel@v1.63.0/minecraft/`.
- Pixi task commands run in deno_task_shell: no `for` loops in `pixi.toml`;
  put loops in `scripts/*.sh`.
- Fresh worktrees need `git -c protocol.file.allow=always submodule update --init`
  when a submodule points at a local path; from GitHub a plain
  `git submodule update --init` works. Do not init the submodules'
  own submodules: `third_party/nethernet` is the one nethernet for both.

## Mojo rules

Follow the "Mojo 1.2 rules" and "Idioms" sections of
`third_party/nethernet/AGENTS.md` and the "Mojo rules" section of
`third_party/protocol/AGENTS.md`; they apply here unchanged (`def` only,
`comptime`, `std.` imports, `.copy()` / `^`, explicit zeroing `__init__`,
no `List[Self]`, no globals, no async, no threads, network bytes never in
`String(unsafe_from_utf8=)`, keep moved structs small). Load the
`mojo-syntax` skill (`.agents/skills/mojo-syntax/`) before writing Mojo; the
compiler wins where they disagree.

## Architecture: one thread, one loop

Mojo 1.2 has no usable threads or async, so Ignis is a single-threaded,
tick-driven server. Where Dragonfly uses goroutines, channels, mutexes and
`World.Exec` transactions, Ignis uses one event loop:

1. Wait on the listeners' and connections' descriptors (`nethernet.os.poll`)
   until the next tick or timer is due.
2. Advance NetherNet (signaling, ICE, DTLS, SCTP) and accept connections.
3. Decode packets from every session and apply them to the world.
4. Run due world ticks (20 per second): scheduled block updates, entities,
   time, weather.
5. Flush each session's outgoing packets as one batch.

Consequences for porting:

- `World.Exec(func(tx *Tx))` and transactions become plain method calls on
  the `World`; there is nothing to lock. Keep Dragonfly's names where they
  still mean something (`Tx` may become a view/handle passed to handlers).
- Handlers (`player.Handler`, `world.Handler`) are traits; a server holds
  them by value or in a `Variant`.
- Anything blocking (disk, DNS, HTTP) must not stall the loop: do it in
  bounded steps from the loop, or before the server starts.
- Interfaces with many implementations (`world.Block`, `item.Item`,
  `world.Entity`) need a Mojo shape chosen once in the core packages and
  then followed everywhere; see `docs/architecture.md`.

## Porting conventions

The goal is that a reader can put a Go file and its Mojo port side by side.

- **Layout**: Dragonfly's `server/<pkg>/<file>.go` →
  `src/ignis/<pkg>/<file>.mojo`, e.g. `server/world/chunk/chunk.go` →
  `src/ignis/world/chunk/chunk.mojo`. Each module has a test file at the
  mirrored path under `test/`.
- **Names**: Go type names unchanged; fields and functions in `snake_case`;
  constants in `SCREAMING_SNAKE_CASE`; keep field order identical to Go.
- **Protocol types**: use the `protocol` submodule's types (`minecraft.protocol`,
  `minecraft.protocol.packet`, `minecraft.nbt`) instead of redefining them.
- **Embedded data**: Dragonfly's `.nbt`/`.json` resources (block states,
  items, recipes, creative inventory) are copied into `resources/` with a
  note of their source version, and loaded at startup.
- **Tests**: byte-exact against Dragonfly wherever there is a wire or disk
  format (chunk encodings, block runtime IDs and hashes, NBT). Generate the
  expected bytes with a small Go program under `interop/` that imports
  Dragonfly at the pinned version, and commit its output as test data.
- Docstrings are short: one line, taken from Dragonfly's doc comment and
  shortened; more only when something is genuinely not obvious. Never write
  `Args:`, `Returns:`, `Raises:` or `Parameters:` sections. Module
  docstrings name the Go file.

## Quality bar

- `pixi run format` before committing; never hand-format.
- Bug fixes come with a reproducing test.
- Where Dragonfly has a bug, do not copy it: fix it, keep the wire bytes the
  client expects, add a test, and note it in the module docstring.
- Do not edit `third_party/*` here; change those repos and bump the
  submodule.
- Never print, log or commit account tokens or private keys.
- Do not commit agent notes or scratch files.
- Commit trailer: `Co-Authored-By: Dylan T. <14214667+dktapps@users.noreply.github.com>`
  (never a Claude trailer or "Generated with Claude Code").
