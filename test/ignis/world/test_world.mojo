from ignis.block.air import Air
from ignis.block.carpet import Carpet
from ignis.block.cube.bbox import BBox
from ignis.block.cube.pos import Pos
from ignis.block.cube.rotation import Rotation
from ignis.block.cube.face import Face
from ignis.block.dirt import Dirt
from ignis.block.grass import Grass
from ignis.block.register import block_at, block_model_face_solid
from ignis.block.stone import Stone
from ignis.entity.text import Text, new_text
from ignis.mgl64 import Vec3
from ignis.world.entity import EntityHandle, EntitySpawnOpts
from ignis.world.position import ChunkPos
from ignis.world.tx import SetOpts
from ignis.world.world import World
from minecraft.protocol.uuid import UUID
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_true,
)
from support.world_runtime import (
    NeighbourProbe,
    RandomProbe,
    RecordingHandler,
    RecordingViewer,
    ScheduledProbe,
    TestEntities,
    TestWorld,
    Walker,
    new_world,
)


def _viewing(mut w: World[TestWorld], radius: Int) -> UInt64:
    """A loader at the origin with every chunk in its radius loaded."""
    var id = w.add_loader(radius, RecordingViewer())
    w.load(id, 1000)
    return id


def _rid(w: World[TestWorld], b: Stone) -> UInt32:
    return w.block_registry()[].block_runtime_id(b)


def test_block_get_set_notifies_viewers() raises:
    var w = new_world()
    ref br = w.block_registry()[]
    assert_equal(w.block(Pos(0, -62, 0)), br.block_runtime_id(Grass()))
    assert_equal(w.block(Pos(0, -63, 0)), br.block_runtime_id(Dirt()))
    var id = _viewing(w, 1)
    w.viewer(id).events.clear()
    w.set_block(Pos(3, 10, 3), Stone())
    assert_equal(w.block(Pos(3, 10, 3)), br.block_runtime_id(Stone()))
    var stone = br.block_runtime_id(Stone())
    assert_equal(len(w.viewer(id).events), 1)
    assert_equal(w.viewer(id).events[0], String(t"block (3,10,3) {stone} 0"))
    # A chunk the loader does not view: no update.
    w.set_block(Pos(200, 10, 200), Stone())
    assert_equal(len(w.viewer(id).events), 1)
    assert_equal(w.block(Pos(200, 10, 200)), stone)
    # Outside the world's range nothing happens.
    w.set_block(Pos(0, 400, 0), Stone())
    assert_equal(len(w.viewer(id).events), 1)
    assert_equal(w.block(Pos(0, 400, 0)), br.air_runtime_id())
    assert_equal(w.block_loaded(Pos(3, 10, 3)).value(), stone)
    assert_false(w.block_loaded(Pos(5000, 10, 5000)))
    assert_true(w.block_as[Stone](Pos(3, 10, 3)))
    assert_false(w.block_as[Dirt](Pos(3, 10, 3)))


def test_world_as_block_source() raises:
    var w = new_world()
    assert_equal(len(w.loaded_chunks()), 0)
    var src = w.source()
    # Reading through the view loads (generates) chunks, as Go's Tx does.
    var grass = block_at(src, Pos(0, -62, 0))
    assert_equal(grass.kind, Grass.BASE_HASH)
    assert_true(block_model_face_solid(grass, Pos(0, -62, 0), Face.UP, src))
    var air = block_at(src, Pos(40, 0, 40))
    assert_false(block_model_face_solid(air, Pos(40, 0, 40), Face.UP, src))
    assert_equal(len(w.loaded_chunks()), 2)


def test_removing_a_block_keeps_its_layer_one_block() raises:
    var w = new_world()
    var stone = _rid(w, Stone())
    var dirt = w.block_registry()[].block_runtime_id(Dirt())
    var air = w.block_registry()[].air_runtime_id()
    var id = _viewing(w, 0)
    w.set_block(Pos(1, 5, 1), Stone())
    # Something on layer 1 (liquids live there).
    w.chunk(ChunkPos(0, 0)).set_block(1, 5, 1, 1, dirt)
    w.viewer(id).events.clear()
    w.set_block_runtime_id(Pos(1, 5, 1), air)
    assert_equal(w.block(Pos(1, 5, 1)), dirt)
    assert_equal(w.chunk(ChunkPos(0, 0)).block(1, 5, 1, 1), air)
    assert_equal(w.viewer(id).events[0], String(t"block (1,5,1) {air} 1"))
    assert_equal(w.viewer(id).events[1], String(t"block (1,5,1) {dirt} 0"))
    # Setting a block that does not displace liquids clears layer 1.
    w.chunk(ChunkPos(0, 0)).set_block(1, 6, 1, 1, dirt)
    w.set_block(Pos(1, 6, 1), Stone())
    assert_equal(w.chunk(ChunkPos(0, 0)).block(1, 6, 1, 1), air)
    _ = stone


def test_loader_loads_nearest_first_and_follows() raises:
    var w = new_world()
    var id = w.add_loader(2, RecordingViewer())
    # The world viewer gets time, time cycle, weather and spawn at once.
    assert_equal(w.viewer(id).count("time "), 1)
    assert_equal(w.viewer(id).count("time_cycle"), 1)
    assert_equal(w.viewer(id).count("weather"), 1)
    assert_equal(w.viewer(id).count("spawn"), 1)
    w.load(id, 1)
    assert_equal(w.viewer(id).events[4], "chunk (0, 0)")
    w.load(id, 100)
    # Chunks within a rounded distance of 2: 21 of them.
    assert_equal(w.viewer(id).count("chunk"), 21)
    assert_true(w.loader_has_chunk(id, ChunkPos(2, 0)))
    assert_true(w.loader_has_chunk(id, ChunkPos(1, 1)))
    assert_false(w.loader_has_chunk(id, ChunkPos(2, 2)))
    assert_equal(len(w.viewers_of_chunk(ChunkPos(0, 0))), 1)

    # Move 10 chunks east: the old chunks stop being viewed.
    w.move_loader(id, Vec3(160, 0, 0))
    assert_equal(w.loader_position(id), ChunkPos(10, 0))
    assert_false(w.loader_has_chunk(id, ChunkPos(0, 0)))
    assert_equal(len(w.viewers_of_chunk(ChunkPos(0, 0))), 0)
    w.load(id, 1)
    var n = len(w.viewer(id).events)
    assert_equal(w.viewer(id).events[n - 1], "chunk (10, 0)")
    w.load(id, 100)
    assert_equal(w.viewer(id).count("chunk"), 42)
    # Moving within the same chunk changes nothing.
    w.move_loader(id, Vec3(170, 0, 3))
    w.load(id, 100)
    assert_equal(w.viewer(id).count("chunk"), 42)
    # Moving one chunk loads only the new edge.
    w.move_loader(id, Vec3(176, 0, 0))
    w.load(id, 100)
    assert_equal(w.viewer(id).count("chunk"), 47)
    # Shrinking the radius evicts.
    w.change_loader_radius(id, 0)
    assert_false(w.loader_has_chunk(id, ChunkPos(12, 0)))
    assert_true(w.loader_has_chunk(id, ChunkPos(11, 0)))


def test_close_loader_returns_the_viewer() raises:
    var w = new_world()
    var id = _viewing(w, 1)
    assert_equal(len(w.loaders()), 1)
    var closed = w.close_loader(id)
    var v = closed.take()
    # A rounded distance of 1 includes the diagonals (Go `chunkDistance`).
    assert_equal(v.count("chunk"), 9)
    assert_equal(len(w.loaders()), 0)
    assert_equal(len(w.viewers_of_chunk(ChunkPos(0, 0))), 0)
    assert_false(w.close_loader(id))
    # A new loader reuses the slot with a new ID.
    var id2 = w.add_loader(0, v^)
    assert_true(id2 != id)
    assert_equal(len(w.loaders()), 1)


def test_scheduled_tick_fires_on_the_right_tick() raises:
    var w = new_world()
    _ = _viewing(w, 0)
    var air = w.block_registry()[].air_runtime_id()
    var dirt = w.block_registry()[].block_runtime_id(Dirt())
    var pos = Pos(2, 0, 2)
    var above = Pos(2, 1, 2)
    w.set_block(pos, ScheduledProbe())
    var start = w.current_tick()
    w.schedule_block_update(pos, ScheduledProbe(), 150)
    assert_equal(len(w.scheduled_updates()), 1)
    assert_equal(w.scheduled_updates()[0].t, start + 3)
    w.advance_tick()
    w.advance_tick()
    assert_equal(w.block(above), air)
    w.advance_tick()
    assert_equal(w.current_tick(), start + 3)
    assert_equal(w.block(above), dirt)
    assert_equal(len(w.scheduled_updates()), 0)


def test_scheduled_ticks_are_unique_and_need_the_same_block() raises:
    var w = new_world()
    _ = _viewing(w, 0)
    var air = w.block_registry()[].air_runtime_id()
    var pos = Pos(4, 0, 4)
    w.set_block(pos, ScheduledProbe())
    w.schedule_block_update(pos, ScheduledProbe(), 500)
    # An earlier update for the same block and position is dropped while a
    # later one is pending (Go `schedule`).
    w.schedule_block_update(pos, ScheduledProbe(), 100)
    assert_equal(len(w.scheduled_updates()), 1)
    # Delays below a tick still take one tick.
    w.schedule_block_update(Pos(5, 0, 5), ScheduledProbe(), 0)
    assert_equal(w.scheduled_updates()[1].t, w.current_tick() + 1)
    # The block changes before the update is due: it does not run.
    w.set_block(pos, Stone())
    for _ in range(12):
        w.advance_tick()
    assert_equal(w.block(Pos(4, 1, 4)), air)
    assert_equal(len(w.scheduled_updates()), 0)


def test_neighbour_updates() raises:
    var w = new_world()
    var id = _viewing(w, 0)
    var probe = Pos(6, 0, 6)
    w.set_block(probe, NeighbourProbe())
    # Its own placement updates it with itself as the neighbour: no change.
    w.advance_tick()
    assert_true(w.block_as[NeighbourProbe](probe))
    w.set_block(Pos(7, 0, 6), Dirt())
    assert_true(w.block_as[NeighbourProbe](probe))
    w.viewer(id).events.clear()
    w.advance_tick()
    assert_true(w.block_as[Stone](probe))
    var stone = _rid(w, Stone())
    assert_equal(w.viewer(id).count(String(t"block (6,0,6) {stone}")), 1)
    # Updates can be disabled.
    w.set_block(probe, NeighbourProbe())
    w.advance_tick()
    var opts = SetOpts()
    opts.disable_block_updates = True
    w.set_block(Pos(7, 0, 6), Stone(), opts)
    w.advance_tick()
    assert_true(w.block_as[NeighbourProbe](probe))


def test_random_ticks() raises:
    var w = new_world(synchronous=True)
    ref br = w.block_registry()[]
    var probe = br.block_runtime_id(RandomProbe())
    # Fill sub-chunk 4 (y 0 to 15) of chunk (0, 0) with random tickers.
    for x in range(16):
        for y in range(16):
            for z in range(16):
                w.chunk(ChunkPos(0, 0)).set_block(
                    UInt8(x), Int16(y), UInt8(z), 0, probe
                )
    w.advance_tick()
    # Each tick picks 3 random positions per sub-chunk; every one holds a
    # probe, which turns into stone.
    var stone = 0
    for x in range(16):
        for y in range(16):
            for z in range(16):
                if w.block_as[Stone](Pos(x, y, z)):
                    stone += 1
    assert_true(stone >= 1 and stone <= 3)
    w.settings().tick_range = 0
    w.advance_tick()
    var after = 0
    for x in range(16):
        for y in range(16):
            for z in range(16):
                if w.block_as[Stone](Pos(x, y, z)):
                    after += 1
    assert_equal(after, stone)


def test_entity_add_move_remove() raises:
    var w = new_world()
    w.handle(RecordingHandler())
    var id = _viewing(w, 1)
    w.viewer(id).events.clear()
    var e = new_text[TestEntities]("hello", Vec3(8, 0, 8))
    var uuid = w.add_entity(e^)
    assert_true(uuid != UUID())
    # Go: entity UUIDs only have the last 8 bytes set.
    for i in range(8):
        assert_equal(uuid.bytes[i], 0)
    assert_equal(w.entity_count(), 1)
    assert_equal(w.viewer(id).events[0], "entity dragonfly:text hello")
    assert_equal(w.handler().value().spawned, 1)

    w.move_entity(uuid, Vec3(9, 0, 8), Rotation(90, 0), True)
    assert_equal(w.viewer(id).events[1], "move dragonfly:text [9.0 0.0 8.0]")
    assert_equal(w.entity(uuid).value().position(), Vec3(9, 0, 8))
    w.teleport_entity(uuid, Vec3(10, 0, 8))
    assert_equal(
        w.viewer(id).events[2], "teleport dragonfly:text [10.0 0.0 8.0]"
    )
    assert_equal(len(w.entities_within(BBox.box(0, -1, 0, 16, 1, 16))), 1)
    assert_equal(len(w.entities_within(BBox.box(20, -1, 0, 30, 1, 16))), 0)

    var back = w.remove_entity(uuid)
    assert_true(back)
    assert_equal(w.viewer(id).events[3], "hide dragonfly:text hello")
    assert_equal(w.handler().value().despawned, 1)
    assert_equal(w.entity_count(), 0)
    assert_false(w.remove_entity(uuid))
    # The handle can join another world, keeping its UUID.
    var w2 = new_world()
    assert_true(w2.add_entity(back.take()) == uuid)
    assert_true(w2.has_entity(uuid))


def test_entity_seen_by_loaders_that_load_its_chunk_later() raises:
    var w = new_world()
    _ = w.add_entity(new_text[TestEntities]("far", Vec3(100, 0, 100)))
    var id = w.add_loader(0, RecordingViewer())
    w.move_loader(id, Vec3(100, 0, 100))
    w.load(id, 10)
    assert_equal(w.viewer(id).count("entity dragonfly:text far"), 1)
    w.move_loader(id, Vec3(0, 0, 0))
    assert_equal(w.viewer(id).count("hide dragonfly:text far"), 1)


def test_entity_ticks_move_it_across_chunks() raises:
    var w = new_world()
    w.handle(RecordingHandler())
    var id = _viewing(w, 0)
    var opts = EntitySpawnOpts()
    opts.position = Vec3(14.5, 0, 8)
    var uuid = w.add_entity(
        EntityHandle[TestEntities](opts, TestEntities.wrap(Walker(4)))
    )
    w.viewer(id).events.clear()
    w.advance_tick()  # 15.5, still in chunk (0, 0)
    assert_equal(w.viewer(id).events[0], "move ignis:walker [15.5 0.0 8.0]")
    w.advance_tick()  # 16.5: the movement is still shown from chunk (0, 0)
    assert_equal(w.viewer(id).events[1], "move ignis:walker [16.5 0.0 8.0]")
    # The next tick moves it to chunk (1, 0), which the loader does not
    # view: it is hidden, and its movement there is not shown.
    _ = w.chunk(ChunkPos(1, 0)).range()  # loaded, but not viewed
    w.advance_tick()
    assert_equal(w.viewer(id).events[2], "hide ignis:walker ")
    assert_equal(len(w.viewer(id).events), 3)
    # Without viewers in its chunk it no longer ticks.
    var before = w.entity(uuid).value().position()
    w.advance_tick()
    assert_equal(w.entity(uuid).value().position(), before)


def test_entity_removing_itself_while_ticking() raises:
    var w = new_world()
    w.handle(RecordingHandler())
    var id = _viewing(w, 0)
    var opts = EntitySpawnOpts()
    opts.position = Vec3(2, 0, 2)
    var uuid = w.add_entity(
        EntityHandle[TestEntities](opts, TestEntities.wrap(Walker(1)))
    )
    w.advance_tick()  # walks
    assert_true(w.has_entity(uuid))
    w.advance_tick()  # out of steps: removes itself
    assert_false(w.has_entity(uuid))
    assert_equal(w.entity_count(), 0)
    assert_equal(w.handler().value().despawned, 1)
    assert_equal(w.viewer(id).count("hide ignis:walker"), 1)


def test_text_entity_expires() raises:
    var w = new_world()
    _ = _viewing(w, 0)
    var opts = EntitySpawnOpts()
    opts.position = Vec3(2, 0, 2)
    var t = Text()
    t.existence_duration_ms = 100
    var uuid = w.add_entity(
        EntityHandle[TestEntities](opts, TestEntities.wrap(t^))
    )
    for _ in range(3):
        w.advance_tick()
    assert_true(w.has_entity(uuid))
    assert_equal(w.entity(uuid).value().data.age_ms, 150)
    w.advance_tick()  # age 150 > 100: marked to close
    w.advance_tick()  # closes
    assert_false(w.has_entity(uuid))


def test_time_and_weather() raises:
    var w = new_world()
    var id = _viewing(w, 0)
    var t0 = w.time()
    w.advance_tick()
    assert_equal(w.time(), t0 + 1)
    # Viewers see the time and weather every 20 ticks.
    w.viewer(id).events.clear()
    for _ in range(40):
        w.advance_tick()
    assert_equal(w.viewer(id).count("time "), 2)
    assert_equal(w.viewer(id).count("weather"), 2)
    w.set_time(1000)
    assert_equal(w.time(), 1000)
    assert_equal(w.viewer(id).count("time 1000"), 1)
    w.stop_time()
    assert_false(w.time_cycle())
    assert_equal(w.viewer(id).count("time_cycle False"), 1)
    w.advance_tick()
    assert_equal(w.time(), 1000)
    w.start_time()
    assert_true(w.time_cycle())

    assert_false(w.raining())
    w.start_raining(10_000)
    assert_true(w.raining())
    assert_equal(w.settings().rain_time, 200)
    w.start_thundering(5000)
    assert_true(w.thundering())
    w.stop_thundering()
    assert_false(w.thundering())
    assert_true(w.raining())
    w.stop_raining()
    assert_false(w.raining())
    # The rain timer toggles rain when it runs out.
    w.start_raining(100)
    w.advance_tick()
    assert_true(w.raining())
    w.advance_tick()
    assert_false(w.raining())
    w.stop_weather_cycle()
    w.start_raining(50)
    w.advance_tick()
    w.advance_tick()
    assert_true(w.raining())


def test_spawn_and_settings() raises:
    var w = new_world()
    # Flat's default spawn: above its 3 layers.
    assert_equal(w.spawn(), Pos(0, -60, 0))
    var id = _viewing(w, 0)
    w.set_spawn(Pos(5, 0, 5))
    assert_equal(w.spawn(), Pos(5, 0, 5))
    assert_equal(w.viewer(id).count("spawn (5,0,5)"), 1)
    assert_equal(w.player_spawn(UUID()), Pos(5, 0, 5))
    w.set_player_spawn(UUID(), Pos(1, 2, 3))
    assert_equal(w.player_spawn(UUID()), Pos(1, 2, 3))
    assert_equal(w.name(), "World")
    assert_equal(String(w.default_game_mode()), "survival")
    assert_equal(String(w.difficulty()), "normal")
    # Spawning above the world means "on the highest block with a solid
    # top or bottom face" (Go `highestObstructingBlock`).
    w.set_spawn(Pos(0, 1000, 0))
    w.advance_tick()
    assert_equal(w.spawn(), Pos(0, -61, 0))
    assert_equal(w.highest_obstructing_block(0, 0), -62)
    # A carpet is the highest block but has no solid face.
    w.set_block(Pos(0, -61, 0), Carpet())
    assert_equal(w.highest_block(0, 0), -61)
    assert_equal(w.highest_obstructing_block(0, 0), -62)


def test_tick_runs_due_ticks() raises:
    var w = new_world()
    var id = _viewing(w, 0)
    var start = w.current_tick()
    assert_equal(w.next_deadline_ms(), 50)
    assert_equal(w.tick(49), 0)
    assert_equal(w.tick(50), 1)
    assert_equal(w.tick(260), 4)
    assert_equal(w.current_tick(), start + 5)
    assert_equal(w.next_deadline_ms(), 300)
    # A loop that fell far behind catches up 10 ticks, then skips.
    assert_equal(w.tick(10_000), 10)
    assert_equal(w.next_deadline_ms(), 10_050)
    _ = id


def test_world_without_viewers_does_not_tick() raises:
    var w = new_world()
    var start = w.current_tick()
    w.advance_tick()
    assert_equal(w.current_tick(), start)
    var s = new_world(synchronous=True)
    var t = s.current_tick()
    s.advance_tick()
    assert_equal(s.current_tick(), t + 1)


def test_unloaded_chunks_are_saved_and_reloaded() raises:
    var w = new_world()
    var id = _viewing(w, 0)
    w.set_block(Pos(3, 3, 3), Stone())
    var named = new_text[TestEntities]("kept", Vec3(4.5, 0, 4.5))
    var uuid = w.add_entity(named^)
    w.set_block(Pos(9, 0, 9), ScheduledProbe())
    w.schedule_block_update(Pos(9, 0, 9), ScheduledProbe(), 1000)
    _ = w.close_loader(id)
    w.close_unused_chunks()
    assert_equal(len(w.loaded_chunks()), 0)
    assert_equal(w.entity_count(), 0)
    assert_equal(len(w.scheduled_updates()), 0)
    assert_equal(w.provider().column_count(), 1)
    # Loading the chunk again brings back blocks, entities and updates.
    assert_true(w.block_as[Stone](Pos(3, 3, 3)))
    assert_equal(w.entity_count(), 1)
    var found = w.entity(uuid)
    var e = found.take()
    assert_equal(e.data.name, "kept")
    assert_equal(e.position(), Vec3(4.5, 0, 4.5))
    assert_equal(len(w.scheduled_updates()), 1)


def test_moved_entities_are_saved() raises:
    # Dragonfly only saves chunks marked modified, and moving entities do
    # not mark them: an entity that walked into an untouched chunk was lost
    # on unload, and one that moved inside its chunk kept its old position.
    var w = new_world()
    var id = _viewing(w, 1)
    var a = w.add_entity(new_text[TestEntities]("a", Vec3(2, 0, 2)))
    var b = w.add_entity(new_text[TestEntities]("b", Vec3(3, 0, 3)))
    w.save()  # nothing is modified any more
    w.move_entity(a, Vec3(20, 0, 2), Rotation(), True)  # into chunk (1, 0)
    w.move_entity(b, Vec3(5, 0, 5), Rotation(), True)  # within (0, 0)
    w.advance_tick()
    _ = w.close_loader(id)
    w.close_unused_chunks()
    assert_equal(w.entity_count(), 0)
    _ = w.block(Pos(20, 0, 2))
    _ = w.block(Pos(5, 0, 5))
    assert_equal(w.entity_count(), 2)
    var fa = w.entity(a)
    assert_equal(fa.take().position(), Vec3(20, 0, 2))
    var fb = w.entity(b)
    assert_equal(fb.take().position(), Vec3(5, 0, 5))


def test_tick_unloads_unused_chunks() raises:
    var w = new_world()
    w.set_block(Pos(3, 3, 3), Stone())
    assert_equal(len(w.loaded_chunks()), 1)
    _ = w.tick(2 * 60 * 1000)
    assert_equal(len(w.loaded_chunks()), 0)
    assert_equal(w.provider().column_count(), 1)


def test_close() raises:
    var w = new_world()
    w.handle(RecordingHandler())
    w.set_block(Pos(3, 3, 3), Stone())
    _ = w.add_entity(new_text[TestEntities]("x", Vec3(1, 0, 1)))
    w.close()
    assert_true(w.closed())
    assert_equal(len(w.loaded_chunks()), 0)
    assert_true(w.provider().settings())
    w.close()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
