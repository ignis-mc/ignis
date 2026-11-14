"""Runs an Ignis server (Dragonfly's `main.go`).

    mojo run -I src -I third_party/protocol/src -I third_party/nethernet/src \
        cmd/ignis/main.mojo [-config PATH] [-addr HOST:PORT] [-offline]

Reads `config.toml` (written with the defaults if missing), then serves
until SIGINT or SIGTERM, which saves the world and the players and exits.
Lines typed on standard input run as console commands. `-addr` and `-offline` override `[Network] Address` and
`[Server] AuthEnabled`. Run it from the repository root: the block and item
tables are read from `resources/`.
"""

from ignis.server.conf import load_user_config
from ignis.server.server import Server, termination_signals
from std.sys import argv


def main() raises:
    # First: this re-executes the program once with SIGINT and SIGTERM
    # blocked, so that every thread of the Mojo runtime blocks them.
    var signals = termination_signals()
    var args = argv()
    var path = String("config.toml")
    var addr = Optional[String](None)
    var offline = False
    var i = 1
    while i < len(args):
        var arg = String(args[i])
        if arg == "-offline":
            offline = True
        elif arg == "-config" and i + 1 < len(args):
            i += 1
            path = String(args[i])
        elif arg == "-addr" and i + 1 < len(args):
            i += 1
            addr = String(args[i])
        else:
            raise Error(t"unknown flag {arg}")
        i += 1
    var user = load_user_config(path)
    if offline:
        user.server_auth_enabled = False
    if addr:
        user.network_address = addr.value()
    var conf = user.config()
    print(
        t"starting {conf.name} on {conf.address}"
        t" auth={not conf.auth_disabled} gamemode={conf.default_game_mode}"
    )
    var srv = Server(conf^)
    srv.close_on_program_end(signals^)
    srv.read_console()
    print("READY", srv.addr())
    srv.run()
