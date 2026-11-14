# Player UI test vectors

`main.go` imports Dragonfly v0.11.6 and gophertunnel v1.63.0 (pinned in
`go.mod`) and writes `test/data/ui/vectors.txt`, one `key hex(value)` line
per vector:

- `colourf.*`, `clean.*`: gophertunnel's `text.Colourf`, `Clean` and `ANSI`
  over a corpus that exercises `golang.org/x/net/html`'s tokenizer (tags,
  comments, doctypes, raw text, character references, unterminated input).
  Arguments are joined with `\x1f`. (`test/ignis/text/test_colour.mojo`)
- `float.*`, `quote.*`: `encoding/json.Marshal` of float64s (input as IEEE
  bits) and strings, including invalid UTF-8.
  (`test/ignis/internal/test_gojson.mojo`)
- `form.*`: the JSON of custom, menu and modal forms and the result of
  `SubmitJSON` for many responses (valid, out of range, wrong types,
  `null`, closed). (`test/ignis/player/form/test_form.mojo`)
- `dialogue.*`, `scoreboard.*`, `bossbar.*`, `chat.*`, `skin.*`: the other
  packages' data.
- `packet.*`: the packets Dragonfly's session writes for messages,
  translations, tips, toasts, scoreboards (sent, replaced, renamed,
  removed), boss bars, titles, forms and NPC dialogues, each as a 2-byte
  big-endian length and the encoded packet (header and payload).

`go run . -entities ../../src/ignis/text/entity.mojo` regenerates the HTML
character reference table from x/net's `entity.go` (then run
`pixi run format`).

Regenerate from the repository root:

```sh
(cd interop/ui && go run . -out ../../test/data/ui)
```
