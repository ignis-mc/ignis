"""Breaking and placing blocks, ported from Dragonfly
`server/player/player.go` (`StartBreaking`, `ContinueBreaking`,
`FinishBreaking`, `AbortBreaking`, `BreakBlock`, `breakTime`, `drops`,
`UseItemOnBlock`, `placeBlock`, `obstructedPos`, `resendNearbyBlocks`) and
`session/handler_player_action.go`.

Go's player reaches the world and its viewers through its transaction;
here these are functions of the server, which owns the sessions and the
world, for the player of session `i`. Viewers are the sessions whose chunk
loader has the block's chunk (Go `tx.Viewers`).

As in Dragonfly, the break time is computed for the crack animation shown
to viewers and the client decides when the block breaks (`PredictDestroy`
or `StopBreak`); the server does not check the timing.

Placing: blocks that are `UsableOnBlock` (logs, stairs, slabs, doors,
trapdoors) decide their position and state; other block items are placed
on the clicked face, or into the clicked block if it is replaceable by
them. Not ported yet: `Activatable` blocks, non-block items used on blocks,
`StateDeriver`.

Not ported yet: fire extinguishing, `Punchable` blocks, `BreakHandler` and
the `HandleStartBreak`/`HandleBlockBreak` handler calls.
"""

from minecraft.protocol.packet.level_event import (
    LEVEL_EVENT_PARTICLES_CRACK_BLOCK,
    LEVEL_EVENT_PARTICLES_DESTROY_BLOCK,
    LEVEL_EVENT_START_BLOCK_CRACKING,
    LEVEL_EVENT_STOP_BLOCK_CRACKING,
    LEVEL_EVENT_UPDATE_BLOCK_CRACKING,
)
from minecraft.protocol.packet.level_sound_event import SOUND_EVENT_HIT
from minecraft.protocol.player import (
    PLAYER_ACTION_ABORT_BREAK,
    PLAYER_ACTION_CONTINUE_DESTROY_BLOCK,
    PLAYER_ACTION_PREDICT_DESTROY_BLOCK,
    PLAYER_ACTION_START_BREAK,
    PLAYER_ACTION_STOP_BREAK,
)

from ..block.break_info import (
    BreakContext,
    BreakInfo,
    break_duration_ms,
    breaks_instantly,
)
from ..block.block import UseContext, User
from ..block.cube.face import Face
from ..block.cube.pos import Pos
from ..block.register import VanillaBlocks
from ..entity.effect.conduit_power import ConduitPower
from ..entity.effect.haste import Haste
from ..entity.effect.mining_fatigue import MiningFatigue
from ..entity.experience_orb import spawn_experience_orbs
from ..item.enchantment import AQUA_AFFINITY_ID, EFFICIENCY_ID, SILK_TOUCH_ID
from ..item.register import VanillaItems
from ..item.stack import Stack
from ..item.tool import TYPE_SWORD, ToolInfo
from ..mgl64 import Vec3
from ..world.game_mode import GAME_MODE_SPECTATOR
from ..block.cube.bbox import BBox
from ..block.hash import AnyBlock
from ..player.player import BBOX_HEIGHT, BBOX_WIDTH, EYE_HEIGHT
from ..session.session import BREAK_NOW, BlockAction, UseOnBlock
from minecraft.protocol.packet.level_sound_event import SOUND_EVENT_PLACE
from ..world.position import chunk_pos_from_block_pos
from .server import Server
from .survival import (
    damage_item,
    flush_living,
    inside_of_water,
    survival_context,
)


def handle_block_action(mut srv: Server, i: Int, a: BlockAction):
    """Applies a breaking action of a player (Go `handlePlayerAction` and
    `handleUseItemData`)."""
    if (
        a.action == PLAYER_ACTION_START_BREAK
        or a.action == PLAYER_ACTION_CONTINUE_DESTROY_BLOCK
    ):
        start_breaking(srv, i, a.pos, Face(a.face))
    elif a.action == PLAYER_ACTION_ABORT_BREAK:
        abort_breaking(srv, i)
    elif (
        a.action == PLAYER_ACTION_PREDICT_DESTROY_BLOCK
        or a.action == PLAYER_ACTION_STOP_BREAK
    ):
        finish_breaking(srv, i)
    elif a.action == BREAK_NOW:
        break_block(srv, i, a.pos)


def viewers(mut srv: Server, pos: Pos) -> List[Int]:
    """Returns the sessions whose loader has the chunk of a block (Go
    `tx.Viewers`)."""
    var out = List[Int]()
    var cp = chunk_pos_from_block_pos(pos)
    for j in range(len(srv.sessions)):
        if case .Some(l) = srv.sessions[j].loader():
            if srv.world.loader_has_chunk(l, cp):
                out.append(j)
    return out^


def _level_event(mut srv: Server, pos: Pos, event: Int32, data: Int32):
    for j in viewers(srv, pos):
        srv.sessions[j].view_level_event(event, pos.vec3(), data)


def swing_arm(mut srv: Server, i: Int):
    """Shows the player swinging its arm (Go `SwingArm`)."""
    var p = srv.sessions[i].player.copy()
    for j in range(len(srv.sessions)):
        srv.sessions[j].view_swing_arm(p)


def _crack_data(ms: Int) -> Int32:
    # Go: int32(65535 / (BreakTime.Seconds() * 20)).
    return Int32(65535.0 / (Float64(ms) / 1000.0 * 20.0))


def start_breaking(mut srv: Server, i: Int, pos: Pos, face: Face):
    """Go `StartBreaking`."""
    abort_breaking(srv, i)
    var rid = srv.world.block(pos)
    if rid == srv.world.block_registry()[].air_runtime_id():
        return
    if not srv.sessions[i].player.can_reach(pos.vec3_centre()):
        return
    var mode = srv.sessions[i].player.game_mode()
    if (
        mode.creative_inventory()
        and _held_tool(srv, i, rid).tool_type == TYPE_SWORD
    ):
        # Swords cannot break blocks in creative mode.
        return
    # Stored even if breaking does not go ahead, so the block can be resent.
    srv.sessions[i].player.breaking_pos = pos
    srv.sessions[i].player.breaking = True
    srv.sessions[i].player.breaking_face = face
    swing_arm(srv, i)
    if mode.creative_inventory():
        return
    var d = break_time(srv, i, pos)
    srv.sessions[i].player.last_break_duration_ms = d
    if d > 0:
        _level_event(srv, pos, LEVEL_EVENT_START_BLOCK_CRACKING, _crack_data(d))


def _held_tool(srv: Server, i: Int, rid: UInt32) -> ToolInfo:
    var held = srv.sessions[i].invs.held_item()
    if held.empty():
        return ToolInfo.none()
    var it = held.item().value()
    var kind = srv.world.block_registry()[].kind(rid)
    return VanillaItems.tool(it.kind, it.hash, kind)


def break_time(mut srv: Server, i: Int, pos: Pos) -> Int:
    """Returns how long the player needs to break a block, in milliseconds
    (Go `breakTime` and `breakContext`)."""
    var rid = srv.world.block(pos)
    var br = srv.world.block_registry()
    var info = VanillaBlocks.break_info(br[].kind(rid), br[].state_hash(rid))
    var held = srv.sessions[i].invs.held_item()
    var efficiency = 0
    if case .Some(e) = held.enchantment(Int16(EFFICIENCY_ID)):
        efficiency = e.level
    var underwater = inside_of_water(srv, i)
    var aqua = Bool(
        srv.sessions[i]
        .invs.armour.helmet()
        .enchantment(Int16(AQUA_AFFINITY_ID))
    )
    ref p = srv.sessions[i].player
    var ctx = BreakContext()
    ctx.underwater = underwater
    ctx.aqua_affinity = aqua
    ctx.airborne = not p.on_ground()
    ctx.flying = p.flying()
    if case .Some(e) = p.living.effect(Haste.ID):
        ctx.haste_level = e.level()
    if case .Some(e) = p.living.effect(ConduitPower.ID):
        ctx.conduit_power_level = e.level()
    if case .Some(e) = p.living.effect(MiningFatigue.ID):
        ctx.mining_fatigue_level = e.level()
    return break_duration_ms(info, _held_tool(srv, i, rid), efficiency, ctx)


def finish_breaking(mut srv: Server, i: Int):
    """Go `FinishBreaking`."""
    var pos = srv.sessions[i].player.breaking_pos
    if not srv.sessions[i].player.breaking:
        resend_block(srv, i, pos)
        return
    abort_breaking(srv, i)
    break_block(srv, i, pos)


def abort_breaking(mut srv: Server, i: Int):
    """Go `AbortBreaking`."""
    if not srv.sessions[i].player.breaking:
        return
    srv.sessions[i].player.breaking = False
    srv.sessions[i].player.break_counter = 0
    var pos = srv.sessions[i].player.breaking_pos
    _level_event(srv, pos, LEVEL_EVENT_STOP_BLOCK_CRACKING, 0)


def continue_breaking(mut srv: Server, i: Int):
    """Go `ContinueBreaking`, run every tick while breaking: punch
    particles, the hit sound every five ticks and the crack speed when the
    break time changes (such as on landing)."""
    if not srv.sessions[i].player.breaking:
        return
    var pos = srv.sessions[i].player.breaking_pos
    var rid = srv.world.block(pos)
    var face = Int32(Int(srv.sessions[i].player.breaking_face))
    _level_event(
        srv, pos, LEVEL_EVENT_PARTICLES_CRACK_BLOCK, Int32(rid) | (face << 24)
    )
    srv.sessions[i].player.break_counter += 1
    if srv.sessions[i].player.break_counter % 5 == 0:
        swing_arm(srv, i)
        for j in viewers(srv, pos):
            srv.sessions[j].view_sound(SOUND_EVENT_HIT, pos.vec3(), Int32(rid))
    var d = break_time(srv, i, pos)
    if d != srv.sessions[i].player.last_break_duration_ms:
        if d > 0:
            _level_event(
                srv, pos, LEVEL_EVENT_UPDATE_BLOCK_CRACKING, _crack_data(d)
            )
        srv.sessions[i].player.last_break_duration_ms = d


def resend_block(mut srv: Server, i: Int, pos: Pos):
    """Sends the player the block at a position within its chunk radius (Go
    `resendNearbyBlock`)."""
    var cp = chunk_pos_from_block_pos(pos)
    if case .Some(l) = srv.sessions[i].loader():
        if srv.world.loader_has_chunk(l, cp):
            srv.sessions[i].view_block(pos, srv.world.block(pos))


def break_block(mut srv: Server, i: Int, pos: Pos):
    """Go `BreakBlock`: removes the block with break particles, drops what
    the held item harvests as item entities and wears the tool."""
    var br = srv.world.block_registry()
    var rid = srv.world.block(pos)
    if rid == br[].air_runtime_id():
        return
    ref p = srv.sessions[i].player
    if not p.can_reach(pos.vec3_centre()) or not p.game_mode().allows_editing():
        resend_block(srv, i, pos)
        return
    var kind = br[].kind(rid)
    var hash = br[].state_hash(rid)
    var info = VanillaBlocks.break_info_at(kind, pos, srv.world)
    var creative = p.game_mode().creative_inventory()
    if not info and not creative:
        resend_block(srv, i, pos)
        return
    var drops = block_drops(srv, i, rid, info)
    var xp = 0
    if case .Some(bi) = info:
        var silk = (
            srv.sessions[i].invs.held_item().enchantment(Int16(SILK_TOUCH_ID))
        )
        if not creative and not silk:
            # Go `XPDropRange.RandomValue` on its global source.
            var r = bi.xp_drops
            xp = srv.world.global_rand().int_n(r.max - r.min + 1) + r.min
    swing_arm(srv, i)
    # Go's break handler runs before the block is removed.
    VanillaBlocks.handle_break(kind, pos, srv.world, not creative)
    srv.world.set_block_runtime_id(pos, br[].air_runtime_id())
    _level_event(srv, pos, LEVEL_EVENT_PARTICLES_DESTROY_BLOCK, Int32(rid))
    if info:
        spawn_experience_orbs(srv.world, pos.vec3_centre(), xp)
    for ref d in drops:
        var x = srv.world.rand().float64() * 0.2 - 0.1
        var z = srv.world.rand().float64() * 0.2 - 0.1
        var vel = Vec3(x, 0.2, z)
        srv.spawn_item(pos.vec3_centre(), vel, d)
    var ctx = survival_context(srv, i)
    srv.sessions[i].player.living.exhaust(0.005, ctx)
    flush_living(srv, i)
    # Only blocks that break instantly by nature cost no durability.
    if breaks_instantly(info):
        return
    var held = srv.sessions[i].invs.held_item()
    if held.empty():
        return
    var it = held.item().value()
    if case .Some(d) = VanillaItems.durability_info(it.kind, it.hash):
        var damaged = damage_item(srv, i, held, d.break_durability)
        srv.sessions[i].invs.set_held_item(damaged)


def block_drops(
    srv: Server, i: Int, rid: UInt32, info: Optional[BreakInfo]
) -> List[Stack]:
    """Go `drops`: what breaking a block with the held item drops; nothing
    in creative, nothing if the tool cannot harvest it. Blocks without a
    `Dropper` drop themselves when they are items."""
    var out = List[Stack]()
    if srv.sessions[i].player.game_mode().creative_inventory():
        return out^
    var br = srv.world.block_registry()
    var kind = br[].kind(rid)
    var hash = br[].state_hash(rid)
    var tool = _held_tool(srv, i, rid)
    if case .Some(b) = info:
        if not b.harvestable.matches(tool.tool_type, tool.harvest_level):
            return out^
        var silk = Bool(
            srv.sessions[i].invs.held_item().enchantment(Int16(SILK_TOUCH_ID))
        )
        if case .Some(d) = VanillaBlocks.drops(kind, hash, tool, silk):
            return d.copy()
    if case .Some(it) = VanillaBlocks.block_item(kind, hash):
        out.append(Stack(it, 1))
    return out^


def resend_nearby_blocks(mut srv: Server, i: Int, pos: Pos, faces: List[Face]):
    """Go `resendNearbyBlocks`."""
    resend_block(srv, i, pos)
    for f in faces:
        resend_block(srv, i, pos.side(f))


def _all_faces() -> List[Face]:
    var out = List[Face]()
    for f in range(6):
        out.append(Face(f))
    return out^


def use_item_on_block(mut srv: Server, i: Int, u: UseOnBlock):
    """Go `UseItemOnBlock` for block items: places the held block on the
    clicked face, or into the clicked block if that is replaceable by it,
    and takes it from the stack outside creative."""
    var pos = u.pos
    var face = Face(u.face)
    var br = srv.world.block_registry()
    var rid = srv.world.block(pos)
    if rid == br[].air_runtime_id() or not srv.sessions[i].player.can_reach(
        pos.vec3_centre()
    ):
        resend_nearby_blocks(srv, i, pos, [face])
        return
    var held = srv.sessions[i].invs.held_item()
    var kind = br[].kind(rid)
    if VanillaBlocks.is_activatable(kind) and (
        not srv.sessions[i].player.sneaking() or held.empty()
    ):
        # Blocks such as doors take precedence over the held item; a
        # sneaking player with an item in hand uses the item instead.
        var ctx = use_context(srv, i)
        if VanillaBlocks.activate(kind, pos, face, srv.world, ctx):
            swing_arm(srv, i)
            apply_use_context(srv, i, ctx, pos)
            return
    if held.empty():
        return
    var it = held.item().value()
    if not it.block:
        return
    ref pl = srv.sessions[i].player
    var user = User(pl.rotation(), pl.position(), EYE_HEIGHT, held)
    var placements = VanillaBlocks.use_on_block(
        it.kind, it.hash, pos, face, u.click, user, srv.world
    )
    if case .Some(list) = placements:
        # The block places itself (Go `item.UsableOnBlock`).
        var placed = False
        for ref pl in list:
            var prid = br[].runtime_id_of(pl.block.kind, pl.block.state)
            if not prid:
                continue
            if pl.update:
                # Go's plain `tx.SetBlock` after `place`.
                if placed:
                    srv.world.set_block_runtime_id(pl.pos, prid.value())
                    if case .Some(ref t) = pl.nbt:
                        srv.world.set_block_entity_nbt(
                            pl.pos, t.copy(), pl.contents
                        )
                continue
            if place_block(srv, i, pl.pos, prid.value(), pl.ignore_bbox):
                placed = True
                if case .Some(ref t) = pl.nbt:
                    srv.world.set_block_entity_nbt(
                        pl.pos, t.copy(), pl.contents
                    )
        if (
            placed
            and not srv.sessions[i].player.game_mode().creative_inventory()
        ):
            srv.sessions[i].invs.set_held_item(held.grow(-1))
        return
    var by = AnyBlock(it.kind, it.hash)
    var replaced = pos
    if not VanillaBlocks.replaceable_by(
        br[].kind(rid), br[].state_hash(rid), by
    ):
        replaced = pos.side(face)
    var r = srv.world.range()
    if replaced.y() < r.min() or replaced.y() > r.max():
        return
    var at = srv.world.block(replaced)
    if not VanillaBlocks.replaceable_by(br[].kind(at), br[].state_hash(at), by):
        return
    # Go `world.StateDeriver`: stairs corners, fences and panes.
    var derived = VanillaBlocks.derive_state(
        it.kind, it.hash, replaced, srv.world
    )
    var place = br[].runtime_id_of(derived.kind, derived.state)
    if not place:
        return
    if not place_block(srv, i, replaced, place.value()):
        return
    if srv.sessions[i].player.game_mode().creative_inventory():
        return
    srv.sessions[i].invs.set_held_item(held.grow(-1))


def use_context(mut srv: Server, i: Int) -> UseContext:
    """Builds the context a block's `activate` gets (Go `useContext` with
    the player as `item.User`)."""
    ref p = srv.sessions[i].player
    var ctx = UseContext()
    ctx.user = p.uuid()
    ctx.user_pos = p.position()
    ctx.user_rot = p.rotation()
    ctx.held = srv.sessions[i].invs.held_item()
    ctx.sneaking = p.sneaking()
    ctx.creative = p.game_mode().creative_inventory()
    return ctx^


def apply_use_context(mut srv: Server, i: Int, ctx: UseContext, pos: Pos):
    """Applies what an activated block asked of its user (Go's
    `SetHeldItems(subtractItem(damageItem(...)))`, `addNewItem` and the
    `item.User` interfaces)."""
    var creative = srv.sessions[i].player.game_mode().creative_inventory()
    var held = srv.sessions[i].invs.held_item()
    if not creative and not held.empty():
        if ctx.damage != 0 and held.max_durability() != -1:
            held = held.damage(ctx.damage)
        if ctx.count_sub != 0:
            held = held.grow(-ctx.count_sub)
        srv.sessions[i].invs.set_held_item(held)
    if not ctx.new_item.empty() and not (
        ctx.new_item_survival_only and creative
    ):
        if srv.sessions[i].invs.held_item().empty():
            srv.sessions[i].invs.set_held_item(ctx.new_item)
        else:
            var n = srv.sessions[i].invs.inv.add_item(ctx.new_item.copy())
            if n < ctx.new_item.count():
                srv.drop_item(i, ctx.new_item.grow(-n))
    for m in ctx.messages:
        srv.sessions[i].send_translation(m, List[String]())
    if ctx.popup.byte_length() != 0:
        srv.sessions[i].send_jukebox_popup(ctx.popup)
    if ctx.food != 0 or ctx.saturation != 0:
        # Go `Saturate` of the user, such as eating a cake slice.
        srv.sessions[i].player.living.saturate(ctx.food, ctx.saturation)
    if ctx.open_container:
        srv.sessions[i].open_block_container(pos, srv.world)


def place_block(
    mut srv: Server, i: Int, pos: Pos, rid: UInt32, ignore_bbox: Bool = False
) -> Bool:
    """Go `placeBlock`: places a block if the player may and no entity is in
    the way; plays the place sound to viewers."""
    ref p = srv.sessions[i].player
    if not p.can_reach(pos.vec3_centre()) or not p.game_mode().allows_editing():
        resend_nearby_blocks(srv, i, pos, _all_faces())
        return False
    var o = obstructed(srv, i, pos, rid)
    if o[0] and not ignore_bbox:
        if not o[1]:
            # Resending blocks placed inside the player itself desyncs it.
            resend_nearby_blocks(srv, i, pos, _all_faces())
        return False
    srv.world.set_block_runtime_id(pos, rid)
    for j in viewers(srv, pos):
        srv.sessions[j].view_sound(SOUND_EVENT_PLACE, pos.vec3(), Int32(rid))
    swing_arm(srv, i)
    return True


def obstructed(
    mut srv: Server, i: Int, pos: Pos, rid: UInt32
) -> Tuple[Bool, Bool]:
    """Go `obstructedPos`: whether a player would be inside the block, and
    whether that player is only the placer. Item entities never obstruct;
    other world entities are not checked yet."""
    var br = srv.world.block_registry()
    var boxes = VanillaBlocks.model_bbox(
        br[].kind(rid), br[].state_hash(rid), pos, srv.world.source()
    )
    var hit = False
    for j in range(len(srv.sessions)):
        ref p = srv.sessions[j].player
        if p.game_mode() == GAME_MODE_SPECTATOR:
            continue
        var pbox = (
            BBox.box(
                -BBOX_WIDTH / 2,
                0,
                -BBOX_WIDTH / 2,
                BBOX_WIDTH / 2,
                BBOX_HEIGHT,
                BBOX_WIDTH / 2,
            )
            .translate(p.position())
            .grow(-1e-4)
        )
        for b in boxes:
            if b.translate(pos.vec3()).intersects_with(pbox):
                if j != i:
                    return (True, False)
                hit = True
    return (hit, True)
