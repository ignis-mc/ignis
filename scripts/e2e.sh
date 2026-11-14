#!/usr/bin/env bash
# Builds the server and the bots, starts the server offline on a free port
# with its world and players in a temporary directory, and checks it end to
# end:
#   1. interop/bots/two_bots.mojo: joining, chunks, movement, chat, leaving.
#   1b. interop/bots/ui_bot.mojo: /ui forms (custom, closed, menu, modal)
#      answered, scoreboard, boss bar, title, toast and an NPC dialogue.
#   2. interop/bots/persist_bot.mojo: AvailableCommands and /time, /gamemode,
#      /list, /tp from a player; /say from the console (stdin).
#   3. SIGINT disconnects the online player, saves and stops the server;
#      after a restart the world time,
#      the player's position, rotation and game mode are back; SIGTERM
#      stops it again.
#   4. interop/bots/interact_bot.mojo: survival breaking with the crack
#      speed of the block's break time, the drop, picking it up and placing
#      it back; creative breaking at once without a drop; a creative
#      inventory pick (CraftCreative + Take) placed in the world; adventure
#      mode refused.
#   5. A copy of the world.mcdb fixture (test/data/mcdb/dragonfly-world)
#      loads: spawn, game mode and time come from its level.dat and the
#      spawn column's sub-chunks come from its database.
#   6. interop/bots/behaviour_bot.mojo: in a world with a water source and
#      floating sand, the water flows, the sand falls as a falling block
#      entity and lands in the water.
#
# Usage: scripts/e2e.sh [port]
set -euo pipefail
cd "$(dirname "$0")/.."

port="${1:-19190}"
addr="http://127.0.0.1:$port"
inc=(-I src -I third_party/protocol/src -I third_party/nethernet/src)
mkdir -p build
mojo build --fp-mode contract=off "${inc[@]}" cmd/ignis/main.mojo -o build/ignis
mojo build --fp-mode contract=off "${inc[@]}" interop/bots/two_bots.mojo -o build/two_bots
mojo build --fp-mode contract=off "${inc[@]}" interop/bots/persist_bot.mojo -o build/persist_bot
mojo build --fp-mode contract=off "${inc[@]}" interop/bots/interact_bot.mojo -o build/interact_bot
mojo build --fp-mode contract=off "${inc[@]}" interop/bots/behaviour_bot.mojo -o build/behaviour_bot
mojo build --fp-mode contract=off "${inc[@]}" interop/bots/ui_bot.mojo -o build/ui_bot

dir="$(mktemp -d)"
pid=""
on_exit() {
    local rc=$?
    exec 7>&- 2>/dev/null || true
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null
    if [[ $rc -ne 0 ]]; then
        for log in "$dir"/server*.log; do
            [[ -f "$log" ]] && { echo "--- $log"; cat "$log"; }
        done
    fi
    rm -rf "$dir"
    return $rc
}
trap on_exit EXIT
printf '[World]\nFolder = "%s/world"\n[Players]\nFolder = "%s/players"\n' \
    "$dir" "$dir" >"$dir/config.toml"

start() { # start LOG: runs the server with a FIFO as its console
    rm -f "$dir/console"
    mkfifo "$dir/console"
    ./build/ignis -config "$dir/config.toml" -addr "127.0.0.1:$port" -offline \
        >"$dir/$1" 2>&1 <"$dir/console" &
    pid=$!
    exec 7>"$dir/console"
    for _ in $(seq 1 150); do
        grep -q '^READY' "$dir/$1" && return 0
        sleep 0.2
    done
    cat "$dir/$1"
    exit 1
}

stop() { # stop SIGNAL LOG: the server must save and exit by itself
    kill "-$1" "$pid"
    for _ in $(seq 1 100); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
    done
    if kill -0 "$pid" 2>/dev/null; then
        echo "FAIL server still running after SIG$1"
        exit 1
    fi
    wait "$pid" || true
    pid=""
    exec 7>&-
    grep -q '^server closed' "$dir/$2" || { echo "FAIL no clean close"; cat "$dir/$2"; exit 1; }
    echo "PASS SIG$1 closes the server cleanly"
}

bot() { ./build/persist_bot "$@" 2>&1 | grep -v '^dial'; }

status=0
start server1.log
./build/two_bots "$addr" 2>&1 | grep -v '^dial' || status=$?
if [[ $status -eq 0 ]]; then
    ./build/ui_bot "$addr" 2>&1 | grep -v '^dial' || status=$?
fi
if [[ $status -eq 0 ]]; then
    bot walk "$addr" 7.5 -3.5
    bot command "$addr" "Set the time to 5000" /time set 5000
    bot command "$addr" "Set own game mode to Creative" /gamemode creative
    bot command "$addr" "There are 1/" /list
    bot command "$addr" "commands.generic.unknown" /nope
    echo "say hello from the console" >&7
    sleep 0.5
    grep -q '^\[Server\] hello from the console' "$dir/server1.log" ||
        { echo "FAIL console /say"; exit 1; }
    echo "PASS console /say"
    bot expect-disconnect "$addr" 30 >"$dir/disconnect.log" &
    waiter=$!
    for _ in $(seq 1 100); do
        grep -q '^WAITING' "$dir/disconnect.log" && break
        sleep 0.2
    done
    stop INT server1.log
    wait "$waiter" || { cat "$dir/disconnect.log"; exit 1; }
    grep -E '^(PASS|DISCONNECT)' "$dir/disconnect.log"
    [[ -f "$dir/world/level.dat" ]] || { echo "FAIL no level.dat"; exit 1; }
    echo "PASS level.dat written"

    start server2.log
    bot expect-time "$addr" 5000 7000
    out="$(bot expect-pos "$addr" 7.5 -3.5)"
    echo "$out"
    grep -q 'mode 1$' <<<"$out" || { echo "FAIL game mode not kept"; exit 1; }
    echo "PASS keeps its game mode"
    bot command "$addr" "Teleported Persist to 1.5" /tp 1.5 -60 1.5
    # The flat world's grass is at y = -61; by hand it breaks in 900 ms,
    # 18 ticks: crack data 65535 / 18.
    ./build/interact_bot survival "$addr" 4 -61 4 3640 2>&1 | grep -v '^dial'
    ./build/interact_bot creative "$addr" 6 -61 4 2>&1 | grep -v '^dial'
    ./build/interact_bot creative-item "$addr" 8 -61 4 2>&1 | grep -v '^dial'
    ./build/interact_bot adventure "$addr" 2 -61 6 2>&1 | grep -v '^dial'
    stop TERM server2.log

    cp -r test/data/mcdb/dragonfly-world "$dir/fixture"
    printf '[World]\nFolder = "%s/fixture"\n[Players]\nSaveData = false\n' \
        "$dir" >"$dir/config.toml"
    start server3.log
    # level.dat: spawn (1, 70, 2), creative, time 6000 with the cycle off.
    bot expect-start "$addr" 1.5 70.5 2.5 1 6000
    stop TERM server3.log

    ./build/behaviour_bot prepare "$dir/behaviour" 2>&1 | grep -v '^dial'
    printf '[World]\nFolder = "%s/behaviour"\n[Players]\nSaveData = false\n' \
        "$dir" >"$dir/config.toml"
    start server4.log
    ./build/behaviour_bot watch "$addr" 2>&1 | grep -v '^dial'
    stop TERM server4.log
fi
echo "--- server log"
cat "$dir/server1.log"
if [[ -f "$dir/server2.log" ]]; then
    echo "--- server log after restart"
    cat "$dir/server2.log"
fi
if [[ -f "$dir/server3.log" ]]; then
    echo "--- server log with the fixture world"
    cat "$dir/server3.log"
fi
exit "$status"
