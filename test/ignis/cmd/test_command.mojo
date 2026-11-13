from std.testing import TestSuite, assert_equal, assert_false, assert_true

from ignis import cmd
from ignis.cmd.argument import parse_targets
from ignis.mgl64 import Vec3
from samples import (
    TestSource,
    TestTx,
    read_vectors,
    sample_commands,
    sample_registry,
    uuid,
)


def _expected(row: List[String]) -> cmd.Message:
    if len(row) == 2:
        return cmd.Message(row[1].copy())
    var params = List[String]()
    for i in range(3, len(row)):
        params.append(row[i].copy())
    return cmd.Message(
        text=row[1].copy(), translation=row[2].copy(), params=params^
    )


def test_usage_and_aliases_match_dragonfly() raises:
    var r = sample_registry()
    var checked = 0
    for row in read_vectors():
        if row[0] == "usage":
            assert_equal(r.by_alias(row[1]).value().usage(), row[2])
            checked += 1
        elif row[0] == "aliases":
            var got = String(",").join(r.by_alias(row[1]).value().aliases())
            assert_equal(got, row[2])
    assert_equal(checked, 10)


def test_execute_matches_dragonfly() raises:
    var r = sample_registry()
    var op = TestSource("Op", True)
    var user = TestSource("User", False)
    var tx = TestTx()
    var rows = read_vectors()
    var cases = 0
    var i = 0
    while i < len(rows):
        if rows[i][0] != "case":
            i += 1
            continue
        ref row = rows[i]
        var c = r.by_alias(row[2]).value().copy()
        var got: cmd.Output
        if row[1] == "Op":
            c.execute(row[3], op, tx)
            got = op.out.copy()
        else:
            c.execute(row[3], user, tx)
            got = user.out.copy()
        var want_ok = List[cmd.Message]()
        var want_err = List[cmd.Message]()
        i += 1
        while rows[i][0] != "end":
            if rows[i][0] == "ok":
                want_ok.append(_expected(rows[i]))
            else:
                want_err.append(_expected(rows[i]))
            i += 1
        var label = "/" + row[2] + " " + row[3]
        assert_equal(got.message_count(), len(want_ok), label)
        assert_equal(got.error_count(), len(want_err), label)
        for j in range(len(want_ok)):
            assert_equal(got.messages()[j].text, want_ok[j].text, label)
            assert_true(got.messages()[j] == want_ok[j], label)
        for j in range(len(want_err)):
            assert_equal(got.errors()[j].text, want_err[j].text, label)
            assert_equal(
                got.errors()[j].translation, want_err[j].translation, label
            )
            assert_true(got.errors()[j] == want_err[j], label)
        cases += 1
    assert_equal(cases, 75)
    assert_equal(op.outputs + user.outputs, cases)


def _world() -> TestTx:
    var tx = TestTx()
    tx.is_attached = True
    tx.all.append(cmd.Target(uuid(1), "Steve", Vec3(100, 0, 0), True))
    tx.all.append(cmd.Target(uuid(2), "", Vec3(0, 0, 0), False))
    tx.all.append(cmd.Target(uuid(3), "Alex", Vec3(2, 2, 3), True))
    tx.all.append(cmd.Target(uuid(4), "Zed", Vec3(50, 0, 0), True))
    return tx^


def _run(
    c: cmd.Command[TestSource], args: String, mut tx: TestTx
) -> cmd.Output:
    var src = TestSource("Op", True)
    c.execute(args, src, tx)
    return src.out.copy()


def _targets(
    selector: String, mut tx: TestTx
) raises cmd.Message -> List[cmd.Target]:
    var src = TestSource("Op", True)
    var line = cmd.Line([selector], ["/x"], "/x <t: target>")
    return parse_targets(line, src, tx)


def test_selectors_with_a_world() raises:
    var tx = _world()
    assert_equal(len(_targets("@a", tx)), 3)
    assert_equal(len(_targets("@e", tx)), 4)
    var s = _targets("@s", tx)
    assert_equal(len(s), 1)
    assert_equal(s[0].name, "Op")
    var r = _targets("@r", tx)
    assert_equal(len(r), 1)
    assert_true(r[0].player)
    # Names are matched case-insensitively.
    var steve = _targets("sTEVE", tx)
    assert_equal(steve[0].uuid, uuid(1))


def test_nearest_player_is_nearest() raises:
    # Dragonfly sorts the players but compares distances by their old
    # indices, so its @p can return Steve here. Alex is nearest to (1,2,3).
    var tx = _world()
    var p = _targets("@p", tx)
    assert_equal(len(p), 1)
    assert_equal(p[0].name, "Alex")
    # A longer selector still counts by its first two bytes, as in Go.
    assert_equal(_targets("@pfoo", tx)[0].name, "Alex")


def test_target_parameters_with_a_world() raises:
    var r = sample_registry()
    var tx = _world()
    var c = r.by_alias("tp").value().copy()
    var o = _run(c, "@a alex", tx)
    assert_equal(o.error_count(), 0)
    assert_equal(o.messages()[0].text, "tp targets 3 1")
    # No players match: `No targets matched selector`.
    var empty = TestTx()
    empty.is_attached = True
    o = _run(c, "@a Steve", empty)
    assert_equal(o.errors()[1].text, cmd.MESSAGE_NO_TARGETS.f().text)
    o = _run(r.by_alias("gamemode").value(), "1 @r", tx)
    assert_equal(o.messages()[0].text, "gamemode int 1 1")
    o = _run(r.by_alias("give").value(), "Zed apple 3 -7", tx)
    assert_equal(o.messages()[0].text, "give 1 apple 3 -7")


def test_overloads_are_tried_in_order() raises:
    # `creative` is both a GameMode and an Item option; the first overload
    # wins, and `1` falls through to the int overload.
    var r = sample_registry()
    var tx = TestTx()
    var c = r.by_alias("gm").value().copy()
    assert_equal(
        _run(c, "creative", tx).messages()[0].text,
        "gamemode set creative unset",
    )
    assert_equal(_run(c, "1", tx).messages()[0].text, "gamemode int 1 unset")


def test_registry() raises:
    var r = sample_registry()
    assert_true(r.by_alias("teleport"))
    assert_true(r.by_alias("gmode"))
    assert_false(r.by_alias("GMode"))
    assert_false(r.by_alias("nope"))
    assert_equal(r.by_alias("hidden").value().name(), "secret")
    # One entry per name and alias.
    assert_equal(len(r.commands()), 14)


def test_runnables_and_params_respect_allower() raises:
    var cmds = sample_commands()
    ref secret = cmds[7]
    assert_equal(len(secret.runnables(TestSource("Op", True))), 1)
    assert_equal(len(secret.runnables(TestSource("User", False))), 0)
    assert_equal(len(secret.params(TestSource("User", False))), 0)
    ref give = cmds[5]
    var params = give.params(TestSource("User", False))
    assert_equal(len(params), 1)
    assert_equal(len(params[0]), 4)
    assert_equal(params[0][1].name, "item")
    assert_true(params[0][1].kind == cmd.ParamKind.ENUM)
    assert_equal(params[0][1].type_name, "Item")
    assert_equal(len(params[0][1].options), 2)
    assert_true(params[0][2].optional)
    assert_true(params[0][2].kind == cmd.ParamKind.UINT)


def test_output() raises:
    var o = cmd.Output()
    o.print("plain")
    o.print(t"n={3}")
    o.error(cmd.MESSAGE_UNKNOWN.f("x"))
    o.errort(cmd.MESSAGE_NUMBER_INVALID, "y")
    o.printt(cmd.MESSAGE_USAGE, "/u")
    assert_equal(o.message_count(), 3)
    assert_equal(o.messages()[1].text, "n=3")
    assert_false(o.messages()[0].translated)
    assert_true(o.messages()[2].translated)
    assert_equal(o.error_count(), 2)
    assert_equal(o.errors()[0].translation, "§r§c%commands.generic.unknown§r")
    assert_equal(o.errors()[1].params[0], "y")
    assert_equal(o.errors()[1].text, "§r§c> 'y' is not a valid number§r")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
