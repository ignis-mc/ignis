# Command test vectors

`main.go` imports Dragonfly v0.11.6 (pinned in `go.mod`), registers the
sample commands that `test/ignis/cmd/samples.mojo` mirrors field for field,
and writes `test/data/cmd/vectors.txt`:

- `usage` / `aliases`: `Command.Usage()` and `Command.Aliases()`.
- `case` … `end`: a command line executed with `Command.Execute` (nil
  `*world.Tx`) as an operator or a plain user, followed by every output
  line: `ok` or `err`, the `String()`/`Error()` text and, for translations,
  what the session sends (`Resolve` and `Params`). Floats are printed as
  their IEEE bits.
- `packet`: the `AvailableCommands` payload `session.BuildAvailableCommands`
  builds for a subset of the commands, hex encoded. Go iterates the command
  map in random order, so each packet is rebuilt until its commands come out
  sorted by name, the order Ignis uses.

Fields are tab separated, with `\`, tab, newline and carriage return
escaped as `\\`, `\t`, `\n` and `\r`.

Regenerate from the repository root:

```sh
(cd interop/cmd && go run . -out ../../test/data/cmd)
```
