# Ignis

A Minecraft: Bedrock Edition server in pure Mojo, ported from
[Dragonfly](https://github.com/df-mc/dragonfly) v0.11.6 (protocol 2225,
game version 1.26.60).

- Transport: [NetherNet](https://github.com/ignis-mc/nethernet), the WebRTC
  transport the game uses since 1.26.60. RakNet is deliberately not
  supported.
- Protocol: [protocol](https://github.com/ignis-mc/protocol), a pure-Mojo
  port of gophertunnel.
- No C bindings and no Python: sockets, crypto, TLS and the protocol are all
  Mojo.

Ignis runs as a single-threaded, tick-driven event loop; see
[docs/architecture.md](docs/architecture.md).

**Status:** early. The repository is being scaffolded; nothing is playable
yet.

## Use

```sh
git clone --recursive https://github.com/ignis-mc/ignis
pixi run test
```

Compile programs with all three source roots:
`mojo run -I src -I third_party/protocol/src -I third_party/nethernet/src your_program.mojo`.

## Development

See [AGENTS.md](AGENTS.md) for the porting conventions and quality bar.

## License

MIT. Dragonfly is © 2019 Dragonfly Tech, also under the MIT license; its
notice is reproduced in [LICENSE](LICENSE).
