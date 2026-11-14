from ignis.block.bedrock import Bedrock
from ignis.block.dirt import Dirt
from ignis.block.grass import Grass
from ignis.block.register import vanilla_block_registry
from ignis.block.register import VanillaBlocks
from ignis.entity.effect import SECOND, new
from ignis.entity.effect.poison import Poison
from ignis.entity.register import VanillaEntities
from ignis.item.stack import Stack
from ignis.item.stick import Stick
from ignis.mgl64 import Vec3
from ignis.player.player import Player
from ignis.session.session import (
    SELF_ENTITY_RUNTIME_ID,
    Config,
    Session,
    game_type_from_mode,
)
from ignis.world.biome.plains import Plains
from ignis.world.game_mode import (
    GAME_MODE_ADVENTURE,
    GAME_MODE_CREATIVE,
    GAME_MODE_SPECTATOR,
    GAME_MODE_SURVIVAL,
)
from ignis.session.viewer import SessionViewer
from ignis.world.conf import Config as WorldConfig
from ignis.world.generator.flat import Flat
from ignis.world.handler import NopHandler
from ignis.world.position import ChunkPos
from ignis.world.provider import MemoryProvider
from ignis.world.world import World, WorldTypes
from std.memory import ArcPointer
from minecraft.protocol.block_pos import SubChunkPos as ProtocolSubChunkPos
from minecraft.protocol.math import Vec3 as ProtocolVec3
from minecraft.protocol.packet.add_player import AddPlayer
from minecraft.protocol.packet.mob_effect import (
    MOB_EFFECT_ADD,
    MOB_EFFECT_REMOVE,
    MobEffect,
)
from minecraft.protocol.packet.respawn import (
    RESPAWN_STATE_CLIENT_READY_TO_SPAWN,
    RESPAWN_STATE_READY_TO_SPAWN,
    Respawn,
)
from minecraft.protocol.packet.update_attributes import UpdateAttributes
from minecraft.protocol.packet.chunk_radius_updated import ChunkRadiusUpdated
from minecraft.protocol.packet.container_close import ContainerClose
from minecraft.protocol.packet.container_open import ContainerOpen
from minecraft.protocol.packet.interact import (
    INTERACT_ACTION_NPC_OPEN,
    INTERACT_ACTION_OPEN_INVENTORY,
    Interact,
)
from minecraft.protocol.packet.id import (
    ID_CONTAINER_CLOSE,
    ID_CONTAINER_OPEN,
    ID_ADD_PLAYER,
    ID_AVAILABLE_ACTOR_IDENTIFIERS,
    ID_CHUNK_RADIUS_UPDATED,
    ID_LEVEL_CHUNK,
    ID_NETWORK_CHUNK_PUBLISHER_UPDATE,
    ID_PLAYER_LIST,
    ID_INVENTORY_CONTENT,
    ID_SET_ACTOR_DATA,
    ID_SET_PLAYER_GAME_TYPE,
    ID_UPDATE_ABILITIES,
    ID_UPDATE_ATTRIBUTES,
)
from minecraft.protocol.packet.level_chunk import LevelChunk
from minecraft.protocol.packet.move_actor_absolute import MoveActorAbsolute
from minecraft.protocol.packet.packet import Packet, PacketData, encode_packet
from minecraft.protocol.packet.player_auth_input import PlayerAuthInput
from minecraft.protocol.packet.player_list import PlayerList
from minecraft.protocol.packet.remove_actor import RemoveActor
from minecraft.protocol.packet.request_chunk_radius import RequestChunkRadius
from minecraft.protocol.packet.set_player_game_type import (
    GAME_TYPE_CREATIVE,
    GAME_TYPE_SPECTATOR,
    GAME_TYPE_SURVIVAL,
    SetPlayerGameType,
)
from minecraft.protocol.packet.sub_chunk import SubChunk
from minecraft.protocol.packet.sub_chunk_request import SubChunkRequest
from minecraft.protocol.packet.text import TEXT_TYPE_CHAT, Text
from minecraft.protocol.player import (
    PLAYER_LIST_ACTION_ADD,
    PLAYER_LIST_ACTION_REMOVE,
)
from minecraft.protocol.skin import Skin
from minecraft.protocol.sub_chunk import (
    SUB_CHUNK_RESULT_CHUNK_NOT_FOUND,
    SUB_CHUNK_RESULT_SUCCESS,
    SUB_CHUNK_RESULT_SUCCESS_ALL_AIR,
    SubChunkOffset,
)
from minecraft.protocol.uuid import UUID
from std.utils.numerics import nan
from std.testing import (
    TestSuite,
    assert_almost_equal,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)
from support.fake_conn import FakeConn


struct _Types(WorldTypes):
    comptime Generator = Flat
    comptime Provider = MemoryProvider
    comptime Viewer = SessionViewer
    comptime Handler = NopHandler
    comptime Blocks = VanillaBlocks
    comptime Entities = VanillaEntities


def _world() raises -> World[_Types]:
    var br = vanilla_block_registry()
    var layers: List[UInt32] = [
        br.block_runtime_id(Grass()),
        br.block_runtime_id(Dirt()),
        br.block_runtime_id(Dirt()),
        br.block_runtime_id(Bedrock()),
    ]
    var conf = WorldConfig[_Types](
        Flat(Plains(), layers^), MemoryProvider(), ArcPointer(br^)
    )
    conf.seed = (UInt64(1), UInt64(2))
    return conf^.new(0)


def _spawn(mut s: Session[FakeConn], mut w: World[_Types]):
    var id = w.add_loader(Int(s.chunk_radius), SessionViewer(s.queue()))
    s.spawn(w, id)


def _player(name: String, n: UInt8) raises -> Player:
    var raw = List[UInt8](length=16, fill=n)
    return Player(
        name, "", UUID(Span(raw)), Vec3(0.5, -59, 0.5), GAME_MODE_CREATIVE
    )


def _session(
    name: String, n: UInt8, radius: Int = 2
) raises -> Session[FakeConn]:
    var conf = Config()
    conf.max_chunk_radius = 4
    return Session(FakeConn(name, radius), _player(name, n), Skin(), conf)


def _packet[P: Packet](mut pk: P) raises -> PacketData:
    var raw = encode_packet(pk)
    return PacketData.parse(Span(raw))


def test_game_type_from_mode() raises:
    assert_equal(game_type_from_mode(GAME_MODE_SURVIVAL), GAME_TYPE_SURVIVAL)
    assert_equal(game_type_from_mode(GAME_MODE_CREATIVE), GAME_TYPE_CREATIVE)
    assert_equal(game_type_from_mode(GAME_MODE_ADVENTURE), GAME_TYPE_SURVIVAL)
    assert_equal(game_type_from_mode(GAME_MODE_SPECTATOR), GAME_TYPE_SPECTATOR)


def test_new_clamps_radius() raises:
    var s = _session("Steve", 1, radius=12)
    assert_equal(s.chunk_radius, 4)
    assert_equal(s.conn.last[ChunkRadiusUpdated]().chunk_radius, 4)
    assert_equal(s.conn.count(ID_UPDATE_ATTRIBUTES), 1)


def test_spawn_packets() raises:
    var w = _world()
    var s = _session("Steve", 1)
    s.conn.clear()
    _spawn(s, w)
    var ids = s.conn.ids()
    # Go `Spawn`: health, experience and food first.
    for i in range(3):
        assert_equal(ids[i], ID_UPDATE_ATTRIBUTES)
    assert_equal(ids[3], ID_NETWORK_CHUNK_PUBLISHER_UPDATE)
    assert_equal(ids[4], ID_AVAILABLE_ACTOR_IDENTIFIERS)
    assert_equal(ids[5], ID_SET_PLAYER_GAME_TYPE)
    assert_equal(ids[6], ID_UPDATE_ABILITIES)
    assert_equal(ids[7], ID_SET_ACTOR_DATA)
    # Go's sendInv: inventory, UI, off-hand, armour.
    for i in range(8, 12):
        assert_equal(ids[i], ID_INVENTORY_CONTENT)
    assert_equal(s.conn.last[SetPlayerGameType]().game_type, GAME_TYPE_CREATIVE)


def test_living_attributes() raises:
    # Go `SendHealth`, `SendFood` and `SendExperience`.
    var s = _session("Steve", 1)
    s.conn.clear()
    s.send_health(12.25, 20, 3.5)
    var h = s.conn.last[UpdateAttributes]()
    assert_equal(h.entity_runtime_id, 1)
    assert_equal(h.attributes[0].name, "minecraft:health")
    assert_equal(h.attributes[0].value, 13)
    assert_equal(h.attributes[0].max, 20)
    assert_equal(h.attributes[0].default, 20)
    assert_equal(h.attributes[1].name, "minecraft:absorption")
    assert_equal(h.attributes[1].value, 4)
    s.send_food(17, 2.5, 1.25)
    var f = s.conn.last[UpdateAttributes]()
    assert_equal(f.attributes[0].name, "minecraft:player.hunger")
    assert_equal(f.attributes[0].value, 17)
    assert_equal(f.attributes[1].name, "minecraft:player.saturation")
    assert_equal(f.attributes[1].value, 2.5)
    assert_equal(f.attributes[2].name, "minecraft:player.exhaustion")
    assert_equal(f.attributes[2].value, 1.25)
    assert_equal(f.attributes[2].max, 5)
    s.send_experience(5, 0.5)
    var x = s.conn.last[UpdateAttributes]()
    assert_equal(x.attributes[0].name, "minecraft:player.level")
    assert_equal(x.attributes[0].value, 5)
    assert_equal(x.attributes[1].name, "minecraft:player.experience")
    assert_equal(x.attributes[1].value, 0.5)


def test_effect_packets() raises:
    # Go `SendEffect`: the removal first, the duration in ticks.
    var s = _session("Steve", 1)
    s.conn.clear()
    s.send_effect(new(Poison(), 2, 3 * SECOND))
    var all = s.conn.all[MobEffect]()
    assert_equal(len(all), 2)
    assert_equal(all[0].operation, MOB_EFFECT_REMOVE)
    assert_equal(all[0].effect_type, 19)
    assert_equal(all[1].operation, MOB_EFFECT_ADD)
    assert_equal(all[1].effect_type, 19)
    assert_equal(all[1].amplifier, 1)
    assert_equal(all[1].duration, 60)
    assert_true(all[1].particles)


def test_respawn() raises:
    var w = _world()
    var s = _session("Steve", 1)
    s.conn.clear()
    s.send_respawn(Vec3(0.5, -60, 0.5))
    var r = s.conn.last[Respawn]()
    assert_equal(r.state, RESPAWN_STATE_READY_TO_SPAWN)
    assert_equal(r.entity_runtime_id, 1)
    assert_almost_equal(r.position.y, Float32(-60 + 1.62))
    # Go `RespawnHandler`.
    var req = Respawn()
    req.entity_runtime_id = 1
    req.state = RESPAWN_STATE_CLIENT_READY_TO_SPAWN
    assert_true(s.handle_packet(_packet(req), w).respawn)
    req.state = RESPAWN_STATE_READY_TO_SPAWN
    with assert_raises():
        _ = s.handle_packet(_packet(req), w)


def test_send_chunks_and_sub_chunks() raises:
    var w = _world()
    var s = _session("Steve", 1)
    _spawn(s, w)
    s.conn.clear()
    s.send_chunks(w)
    var chunks = s.conn.all[LevelChunk]()
    assert_equal(len(chunks), 4)
    assert_equal(chunks[0].position.x, 0)
    assert_equal(chunks[0].position.z, 0)
    for _ in range(10):
        s.send_chunks(w)
    # Radius 2 holds 21 chunks.
    assert_equal(s.conn.count(ID_LEVEL_CHUNK), 21)

    var req = SubChunkRequest()
    req.dimension = 0
    req.position = ProtocolSubChunkPos()
    req.position.x = 0
    req.position.y = -4
    req.position.z = 0
    req.offsets.append(SubChunkOffset(0, 0, 0))
    req.offsets.append(SubChunkOffset(0, 1, 0))
    req.offsets.append(SubChunkOffset(9, 0, 0))
    _ = s.handle_packet(_packet(req), w)
    var sub = s.conn.last[SubChunk]()
    assert_equal(len(sub.sub_chunk_entries), 3)
    assert_equal(sub.sub_chunk_entries[0].result, SUB_CHUNK_RESULT_SUCCESS)
    assert_equal(
        sub.sub_chunk_entries[1].result, SUB_CHUNK_RESULT_SUCCESS_ALL_AIR
    )
    assert_equal(
        sub.sub_chunk_entries[2].result, SUB_CHUNK_RESULT_CHUNK_NOT_FOUND
    )


def test_request_chunk_radius() raises:
    var w = _world()
    var s = _session("Steve", 1)
    _spawn(s, w)
    var req = RequestChunkRadius()
    req.chunk_radius = 16
    _ = s.handle_packet(_packet(req), w)
    assert_equal(s.chunk_radius, 4)
    assert_equal(s.conn.last[ChunkRadiusUpdated]().chunk_radius, 4)
    s.send_chunks(w)
    for _ in range(20):
        s.send_chunks(w)
    # Radius 4 holds 69 chunks (rounded distance at most 4).
    assert_equal(s.conn.count(ID_LEVEL_CHUNK), 69)


def test_player_auth_input_moves() raises:
    var w = _world()
    var s = _session("Steve", 1)
    _spawn(s, w)
    var pk = PlayerAuthInput()
    pk.position = ProtocolVec3(3.5, Float32(-59 + 1.62), -2.25)
    pk.yaw = 90
    pk.pitch = 10
    pk.head_yaw = 90
    var res = s.handle_packet(_packet(pk), w)
    assert_true(res.moved)
    assert_almost_equal(res.movement.value().x(), 3.0)
    assert_almost_equal(s.player.position().x(), 3.5)
    assert_almost_equal(s.player.position().y(), -59, atol=1e-5)
    assert_almost_equal(s.player.position().z(), -2.25)
    assert_almost_equal(s.player.rotation().yaw(), 90)
    assert_almost_equal(s.player.rotation().pitch(), 10)
    # The same input again is no movement.
    var again = s.handle_packet(_packet(pk), w)
    assert_false(again.moved)


def test_player_auth_input_nan_keeps_position() raises:
    var w = _world()
    var s = _session("Steve", 1)
    var pk = PlayerAuthInput()
    pk.position = ProtocolVec3(0.5, nan[DType.float32](), 0.5)
    var res = s.handle_packet(_packet(pk), w)
    assert_false(res.moved)
    assert_almost_equal(s.player.position().y(), -59, atol=1e-5)


def test_text_chat() raises:
    var w = _world()
    var s = _session("Steve", 1)
    var pk = Text()
    pk.text_type = TEXT_TYPE_CHAT
    pk.source_name = "Steve"
    pk.message = "hello"
    var res = s.handle_packet(_packet(pk), w)
    assert_equal(res.chat.value(), "<Steve> hello")
    pk.source_name = "Alex"
    with assert_raises(contains="SourceName"):
        _ = s.handle_packet(_packet(pk), w)


def test_view_other_player() raises:
    var s = _session("Steve", 1)
    var alex = _player("Alex", 2)
    s.send_session_to_self()
    s.add_to_player_list(alex, Skin())
    var list = s.conn.last[PlayerList]()
    assert_equal(list.entries[0].action_type, PLAYER_LIST_ACTION_ADD)
    assert_equal(list.entries[0].entity_unique_id, 2)
    assert_equal(list.entries[0].username, "Alex")
    assert_equal(s.entity_runtime_id(s.player).value(), SELF_ENTITY_RUNTIME_ID)

    s.view_entity(alex)
    var add = s.conn.last[AddPlayer]()
    assert_equal(add.entity_runtime_id, 2)
    assert_equal(add.username, "Alex")
    assert_almost_equal(add.position.y, -59)

    _ = alex.move(Vec3(1, 0, 0), 45, 0)
    s.view_entity_movement(
        alex, alex.position(), alex.rotation(), alex.on_ground()
    )
    var mv = s.conn.last[MoveActorAbsolute]()
    assert_equal(mv.entity_runtime_id, 2)
    assert_almost_equal(mv.position.x, 1.5)
    assert_almost_equal(mv.position.y, Float32(-59 + 1.62), atol=1e-4)
    assert_almost_equal(mv.rotation.y, 45)

    s.hide_entity(alex)
    assert_equal(s.conn.last[RemoveActor]().entity_unique_id, 2)
    s.remove_from_player_list(alex)
    assert_equal(
        s.conn.last[PlayerList]().entries[0].action_type,
        PLAYER_LIST_ACTION_REMOVE,
    )
    assert_false(s.entity_runtime_id(alex))


def test_open_and_close_inventory() raises:
    var w = _world()
    var s = _session("Steve", 1)
    _spawn(s, w)
    var open = Interact()
    open.action_type = INTERACT_ACTION_OPEN_INVENTORY
    _ = s.handle_packet(_packet(open), w)
    var pk = s.conn.last[ContainerOpen]()
    assert_equal(pk.window_id, 0)
    assert_equal(pk.container_type, 0xFF)
    assert_equal(pk.container_entity_unique_id, -1)
    assert_equal(pk.container_position.y, -59)
    # A second ContainerOpen would crash the client.
    _ = s.handle_packet(_packet(open), w)
    assert_equal(s.conn.count(ID_CONTAINER_OPEN), 1)
    # Closing moves what the UI holds back into the inventory.
    s.invs.ui.set_item(0, Stack(Stick(), 5))
    var close = ContainerClose()
    var res = s.handle_packet(_packet(close), w)
    assert_equal(s.conn.last[ContainerClose]().window_id, 0)
    assert_true(s.invs.ui.empty())
    assert_equal(s.invs.inv.item(0).count(), 5)
    assert_equal(len(res.dropped), 0)
    _ = s.handle_packet(_packet(open), w)
    assert_equal(s.conn.count(ID_CONTAINER_OPEN), 2)
    # Window 0xFF (with the chat) gets no reply.
    close.window_id = 0xFF
    _ = s.handle_packet(_packet(close), w)
    assert_equal(s.conn.count(ID_CONTAINER_CLOSE), 1)
    open.action_type = INTERACT_ACTION_NPC_OPEN
    with assert_raises(contains="interact"):
        _ = s.handle_packet(_packet(open), w)


def test_write_error_kept() raises:
    var s = _session("Steve", 1)
    s.conn.closed = True
    s.send_message("hi")
    assert_true(s.write_error())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
