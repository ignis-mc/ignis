"""The fields of a `level.dat`, ported from Dragonfly
`server/world/mcdb/leveldat/data.go`.

Go decodes `level.dat` into the `Data` struct through reflection and fails
on any field the struct lacks, so Dragonfly cannot open a world whose
`level.dat` carries a field it does not know. Here such fields are kept in
`Data.extra` and written back after the known ones; for a `level.dat`
Dragonfly can read, the encoded bytes are the same as Go's (fields in
struct order, booleans as bytes, `[]int32` as lists of ints, maps as
compounds).
"""

from minecraft.nbt.nbt import (
    TAG_BYTE,
    TAG_COMPOUND,
    TAG_END,
    TAG_FLOAT,
    TAG_INT,
    TAG_LIST,
    TAG_LONG,
    TAG_STRING,
)
from minecraft.nbt.tree import Tag, Tree
from minecraft.protocol.info import CURRENT_PROTOCOL, CURRENT_VERSION
from nethernet.os.time import unix_time_s

from ....block.cube.pos import Pos
from ...difficulty import Difficulty, difficulty_by_id, DIFFICULTY_NORMAL
from ...game_mode import GameMode, game_mode_by_id, GAME_MODE_SURVIVAL
from ...settings import Settings
from .version import minimum_compatible_client_version


def _expect(t: Tree, e: Tag, tag: UInt8) raises:
    if t.type_of(e) != tag:
        raise Error(
            t"level.dat: field {t.name(e)} has tag {t.type_of(e)}, want {tag}"
        )


def _put_int_list(mut t: Tree, c: Tag, key: StringSlice, v: List[Int32]) raises:
    var l = t.put_list(c, key, TAG_INT)
    for x in v:
        _ = t.append_int(l, x)


def _get_int_list(t: Tree, e: Tag) raises -> List[Int32]:
    _expect(t, e, TAG_LIST)
    var out = List[Int32]()
    for c in t.children(e):
        out.append(t.as_int(c))
    return out^


def _put_map(mut t: Tree, c: Tag, key: StringSlice, m: Tree) raises:
    var dst = t.put_compound(c, key)
    if m.is_empty():
        return
    for e in m.children(m.root()):
        _ = t.put_tree(dst, m.name(e), m, e)


def _get_map(t: Tree, e: Tag) raises -> Tree:
    var out = Tree()
    for c in t.children(e):
        _ = out.put_tree(out.root(), t.name(c), t, c)
    return out^


struct Abilities(Copyable, Defaultable, Movable):
    """The default player abilities of a world (the `abilities` compound)."""

    var attack_mobs: Bool
    """NBT `attackmobs`."""
    var attack_players: Bool
    """NBT `attackplayers`."""
    var build: Bool
    """NBT `build`."""
    var mine: Bool
    """NBT `mine`."""
    var doors_and_switches: Bool
    """NBT `doorsandswitches`."""
    var fly_speed: Float32
    """NBT `flySpeed`."""
    var flying: Bool
    """NBT `flying`."""
    var instant_build: Bool
    """NBT `instabuild`."""
    var invulnerable: Bool
    """NBT `invulnerable`."""
    var lightning: Bool
    """NBT `lightning`."""
    var may_fly: Bool
    """NBT `mayfly`."""
    var op: Bool
    """NBT `op`."""
    var open_containers: Bool
    """NBT `opencontainers`."""
    var permissions_level: Int32
    """NBT `permissionsLevel`."""
    var player_permissions_level: Int32
    """NBT `playerPermissionsLevel`."""
    var teleport: Bool
    """NBT `teleport`."""
    var walk_speed: Float32
    """NBT `walkSpeed`."""
    var vertical_fly_speed: Float32
    """NBT `verticalFlySpeed`."""

    def __init__(out self):
        """Creates zero values, like a Go zero value."""
        self.attack_mobs = False
        self.attack_players = False
        self.build = False
        self.mine = False
        self.doors_and_switches = False
        self.fly_speed = 0
        self.flying = False
        self.instant_build = False
        self.invulnerable = False
        self.lightning = False
        self.may_fly = False
        self.op = False
        self.open_containers = False
        self.permissions_level = 0
        self.player_permissions_level = 0
        self.teleport = False
        self.walk_speed = 0
        self.vertical_fly_speed = 0

    def marshal_into(self, mut t: Tree, c: Tag) raises:
        """Writes the fields into a compound in Go's field order.

        Args:
            t: The tree.
            c: The compound to fill.

        Raises:
            If the tree rejects a value.
        """
        _ = t.put_bool(c, "attackmobs", self.attack_mobs)
        _ = t.put_bool(c, "attackplayers", self.attack_players)
        _ = t.put_bool(c, "build", self.build)
        _ = t.put_bool(c, "mine", self.mine)
        _ = t.put_bool(c, "doorsandswitches", self.doors_and_switches)
        _ = t.put_float(c, "flySpeed", self.fly_speed)
        _ = t.put_bool(c, "flying", self.flying)
        _ = t.put_bool(c, "instabuild", self.instant_build)
        _ = t.put_bool(c, "invulnerable", self.invulnerable)
        _ = t.put_bool(c, "lightning", self.lightning)
        _ = t.put_bool(c, "mayfly", self.may_fly)
        _ = t.put_bool(c, "op", self.op)
        _ = t.put_bool(c, "opencontainers", self.open_containers)
        _ = t.put_int(c, "permissionsLevel", self.permissions_level)
        _ = t.put_int(
            c, "playerPermissionsLevel", self.player_permissions_level
        )
        _ = t.put_bool(c, "teleport", self.teleport)
        _ = t.put_float(c, "walkSpeed", self.walk_speed)
        _ = t.put_float(c, "verticalFlySpeed", self.vertical_fly_speed)

    def unmarshal_from(mut self, t: Tree, c: Tag) raises:
        """Reads the fields present in a compound (Go `nbt.Unmarshal`).

        Args:
            t: The tree.
            c: The compound.

        Raises:
            If a known field has the wrong type or a field is unknown.
        """
        for e in t.children(c):
            var n = t.name(e)
            if n == "attackmobs":
                _expect(t, e, TAG_BYTE)
                self.attack_mobs = t.as_bool(e)
            elif n == "attackplayers":
                _expect(t, e, TAG_BYTE)
                self.attack_players = t.as_bool(e)
            elif n == "build":
                _expect(t, e, TAG_BYTE)
                self.build = t.as_bool(e)
            elif n == "mine":
                _expect(t, e, TAG_BYTE)
                self.mine = t.as_bool(e)
            elif n == "doorsandswitches":
                _expect(t, e, TAG_BYTE)
                self.doors_and_switches = t.as_bool(e)
            elif n == "flySpeed":
                _expect(t, e, TAG_FLOAT)
                self.fly_speed = t.as_float(e)
            elif n == "flying":
                _expect(t, e, TAG_BYTE)
                self.flying = t.as_bool(e)
            elif n == "instabuild":
                _expect(t, e, TAG_BYTE)
                self.instant_build = t.as_bool(e)
            elif n == "invulnerable":
                _expect(t, e, TAG_BYTE)
                self.invulnerable = t.as_bool(e)
            elif n == "lightning":
                _expect(t, e, TAG_BYTE)
                self.lightning = t.as_bool(e)
            elif n == "mayfly":
                _expect(t, e, TAG_BYTE)
                self.may_fly = t.as_bool(e)
            elif n == "op":
                _expect(t, e, TAG_BYTE)
                self.op = t.as_bool(e)
            elif n == "opencontainers":
                _expect(t, e, TAG_BYTE)
                self.open_containers = t.as_bool(e)
            elif n == "permissionsLevel":
                _expect(t, e, TAG_INT)
                self.permissions_level = t.as_int(e)
            elif n == "playerPermissionsLevel":
                _expect(t, e, TAG_INT)
                self.player_permissions_level = t.as_int(e)
            elif n == "teleport":
                _expect(t, e, TAG_BYTE)
                self.teleport = t.as_bool(e)
            elif n == "walkSpeed":
                _expect(t, e, TAG_FLOAT)
                self.walk_speed = t.as_float(e)
            elif n == "verticalFlySpeed":
                _expect(t, e, TAG_FLOAT)
                self.vertical_fly_speed = t.as_float(e)
            else:
                raise Error(t"level.dat: unexpected field abilities.{n}")


struct Data(Copyable, Defaultable, Movable):
    """The contents of a `level.dat` (Go `Data`), field for field."""

    var base_game_version: String
    """NBT `baseGameVersion`."""
    var biome_override: String
    """NBT `BiomeOverride`."""
    var confirmed_platform_locked_content: Bool
    """NBT `ConfirmedPlatformLockedContent`."""
    var centre_maps_to_origin: Bool
    """NBT `CenterMapsToOrigin`."""
    var cheats_enabled: Bool
    """NBT `cheatsEnabled`."""
    var daylight_cycle: Int32
    """NBT `daylightCycle`."""
    var difficulty: Int32
    """NBT `Difficulty`."""
    var edu_offer: Int32
    """NBT `eduOffer`."""
    var flat_world_layers: String
    """NBT `FlatWorldLayers`."""
    var force_game_type: Bool
    """NBT `ForceGameType`."""
    var game_type: Int32
    """NBT `GameType`."""
    var generator: Int32
    """NBT `Generator`."""
    var inventory_version: String
    """NBT `InventoryVersion`."""
    var lan_broadcast: Bool
    """NBT `LANBroadcast`."""
    var lan_broadcast_intent: Bool
    """NBT `LANBroadcastIntent`."""
    var last_played: Int64
    """NBT `LastPlayed`."""
    var level_name: String
    """NBT `LevelName`."""
    var limited_world_origin_x: Int32
    """NBT `LimitedWorldOriginX`."""
    var limited_world_origin_y: Int32
    """NBT `LimitedWorldOriginY`."""
    var limited_world_origin_z: Int32
    """NBT `LimitedWorldOriginZ`."""
    var limited_world_depth: Int32
    """NBT `limitedWorldDepth`."""
    var limited_world_width: Int32
    """NBT `limitedWorldWidth`."""
    var locator_bar: Bool
    """NBT `locatorbar`."""
    var minimum_compatible_client_version: List[Int32]
    """NBT `MinimumCompatibleClientVersion`."""
    var multi_player_game: Bool
    """NBT `MultiplayerGame`."""
    var multi_player_game_intent: Bool
    """NBT `MultiplayerGameIntent`."""
    var nether_scale: Int32
    """NBT `NetherScale`."""
    var network_version: Int32
    """NBT `NetworkVersion`."""
    var platform: Int32
    """NBT `Platform`."""
    var platform_broadcast_intent: Int32
    """NBT `PlatformBroadcastIntent`."""
    var random_seed: Int64
    """NBT `RandomSeed`."""
    var show_tags: Bool
    """NBT `showtags`."""
    var single_use_world: Bool
    """NBT `isSingleUseWorld`."""
    var spawn_x: Int32
    """NBT `SpawnX`."""
    var spawn_y: Int32
    """NBT `SpawnY`."""
    var spawn_z: Int32
    """NBT `SpawnZ`."""
    var spawn_v1_villagers: Bool
    """NBT `SpawnV1Villagers`."""
    var storage_version: Int32
    """NBT `StorageVersion`."""
    var time: Int64
    """NBT `Time`."""
    var xbl_broadcast: Bool
    """NBT `XBLBroadcast`."""
    var xbl_broadcast_intent: Int32
    """NBT `XBLBroadcastIntent`."""
    var xbl_broadcast_mode: Int32
    """NBT `XBLBroadcastMode`."""
    var abilities: Abilities
    """NBT `abilities`."""
    var bonus_chest_enabled: Bool
    """NBT `bonusChestEnabled`."""
    var bonus_chest_spawned: Bool
    """NBT `bonusChestSpawned`."""
    var command_block_output: Bool
    """NBT `commandblockoutput`."""
    var command_blocks_enabled: Bool
    """NBT `commandblocksenabled`."""
    var commands_enabled: Bool
    """NBT `commandsEnabled`."""
    var current_tick: Int64
    """NBT `currentTick`."""
    var do_day_light_cycle: Bool
    """NBT `dodaylightcycle`."""
    var do_entity_drops: Bool
    """NBT `doentitydrops`."""
    var do_fire_tick: Bool
    """NBT `dofiretick`."""
    var do_immediate_respawn: Bool
    """NBT `doimmediaterespawn`."""
    var do_insomnia: Bool
    """NBT `doinsomnia`."""
    var do_mob_loot: Bool
    """NBT `domobloot`."""
    var do_mob_spawning: Bool
    """NBT `domobspawning`."""
    var do_tile_drops: Bool
    """NBT `dotiledrops`."""
    var do_weather_cycle: Bool
    """NBT `doweathercycle`."""
    var drowning_damage: Bool
    """NBT `drowningdamage`."""
    var edu_level: Bool
    """NBT `eduLevel`."""
    var education_features_enabled: Bool
    """NBT `educationFeaturesEnabled`."""
    var experimental_game_play: Bool
    """NBT `experimentalgameplay`."""
    var fall_damage: Bool
    """NBT `falldamage`."""
    var fire_damage: Bool
    """NBT `firedamage`."""
    var function_command_limit: Int32
    """NBT `functioncommandlimit`."""
    var has_been_loaded_in_creative: Bool
    """NBT `hasBeenLoadedInCreative`."""
    var has_locked_behaviour_pack: Bool
    """NBT `hasLockedBehaviorPack`."""
    var has_locked_resource_pack: Bool
    """NBT `hasLockedResourcePack`."""
    var immutable_world: Bool
    """NBT `immutableWorld`."""
    var is_created_in_editor: Bool
    """NBT `isCreatedInEditor`."""
    var is_exported_from_editor: Bool
    """NBT `isExportedFromEditor`."""
    var is_from_locked_template: Bool
    """NBT `isFromLockedTemplate`."""
    var is_from_world_template: Bool
    """NBT `isFromWorldTemplate`."""
    var is_world_template_option_locked: Bool
    """NBT `isWorldTemplateOptionLocked`."""
    var keep_inventory: Bool
    """NBT `keepinventory`."""
    var last_opened_with_version: List[Int32]
    """NBT `lastOpenedWithVersion`."""
    var lightning_level: Float32
    """NBT `lightningLevel`."""
    var lightning_time: Int32
    """NBT `lightningTime`."""
    var max_command_chain_length: Int32
    """NBT `maxcommandchainlength`."""
    var mob_griefing: Bool
    """NBT `mobgriefing`."""
    var natural_regeneration: Bool
    """NBT `naturalregeneration`."""
    var prid: String
    """NBT `prid`."""
    var pvp: Bool
    """NBT `pvp`."""
    var rain_level: Float32
    """NBT `rainLevel`."""
    var rain_time: Int32
    """NBT `rainTime`."""
    var random_tick_speed: Int32
    """NBT `randomtickspeed`."""
    var requires_copied_pack_removal_check: Bool
    """NBT `requiresCopiedPackRemovalCheck`."""
    var send_command_feedback: Bool
    """NBT `sendcommandfeedback`."""
    var server_chunk_tick_range: Int32
    """NBT `serverChunkTickRange`."""
    var show_coordinates: Bool
    """NBT `showcoordinates`."""
    var show_death_messages: Bool
    """NBT `showdeathmessages`."""
    var spawn_mobs: Bool
    """NBT `spawnMobs`."""
    var spawn_radius: Int32
    """NBT `spawnradius`."""
    var start_with_map_enabled: Bool
    """NBT `startWithMapEnabled`."""
    var texture_packs_required: Bool
    """NBT `texturePacksRequired`."""
    var tnt_explodes: Bool
    """NBT `tntexplodes`."""
    var use_msa_gamer_tags_only: Bool
    """NBT `useMsaGamertagsOnly`."""
    var world_start_count: Int64
    """NBT `worldStartCount`."""
    var experiments: Tree
    """NBT `experiments`."""
    var freeze_damage: Bool
    """NBT `freezedamage`."""
    var world_policies: Tree
    """NBT `world_policies`."""
    var world_version: Int32
    """NBT `WorldVersion`."""
    var respawn_blocks_explode: Bool
    """NBT `respawnblocksexplode`."""
    var show_border_effect: Bool
    """NBT `showbordereffect`."""
    var permissions_level: Int32
    """NBT `permissionsLevel`."""
    var player_permissions_level: Int32
    """NBT `playerPermissionsLevel`."""
    var is_random_seed_allowed: Bool
    """NBT `isRandomSeedAllowed`."""
    var do_limited_crafting: Bool
    """NBT `dolimitedcrafting`."""
    var editor_world_type: Int32
    """NBT `editorWorldType`."""
    var players_sleeping_percentage: Int32
    """NBT `playerssleepingpercentage`."""
    var recipes_unlock: Bool
    """NBT `recipesunlock`."""
    var natural_generation: Bool
    """NBT `naturalgeneration`."""
    var projectiles_can_break_blocks: Bool
    """NBT `projectilescanbreakblocks`."""
    var show_recipe_messages: Bool
    """NBT `showrecipemessages`."""
    var is_hardcore: Bool
    """NBT `IsHardcore`."""
    var show_days_played: Bool
    """NBT `showdaysplayed`."""
    var tnt_explosion_drop_decay: Bool
    """NBT `tntexplosiondropdecay`."""
    var has_uncomplete_world_file_on_disk: Bool
    """NBT `HasUncompleteWorldFileOnDisk`."""
    var player_has_died: Bool
    """NBT `PlayerHasDied`."""
    var use_allow_list: Bool
    """NBT `UseAllowList`."""
    var allow_anonymous_block_drops_in_editor_worlds: Bool
    """NBT `allowAnonymousBlockDropsInEditorWorlds`."""
    var player_waypoints: Int32
    """NBT `playerwaypoints`."""
    var server_editor_connection_policy: Int32
    """NBT `serverEditorConnectionPolicy`."""
    var extra: Tree
    """Fields Dragonfly does not know, kept and written back after the
    known ones (Go fails to decode such a `level.dat`)."""

    def __init__(out self):
        """Creates zero values, like a Go zero value."""
        self.base_game_version = String()
        self.biome_override = String()
        self.confirmed_platform_locked_content = False
        self.centre_maps_to_origin = False
        self.cheats_enabled = False
        self.daylight_cycle = 0
        self.difficulty = 0
        self.edu_offer = 0
        self.flat_world_layers = String()
        self.force_game_type = False
        self.game_type = 0
        self.generator = 0
        self.inventory_version = String()
        self.lan_broadcast = False
        self.lan_broadcast_intent = False
        self.last_played = 0
        self.level_name = String()
        self.limited_world_origin_x = 0
        self.limited_world_origin_y = 0
        self.limited_world_origin_z = 0
        self.limited_world_depth = 0
        self.limited_world_width = 0
        self.locator_bar = False
        self.minimum_compatible_client_version = List[Int32]()
        self.multi_player_game = False
        self.multi_player_game_intent = False
        self.nether_scale = 0
        self.network_version = 0
        self.platform = 0
        self.platform_broadcast_intent = 0
        self.random_seed = 0
        self.show_tags = False
        self.single_use_world = False
        self.spawn_x = 0
        self.spawn_y = 0
        self.spawn_z = 0
        self.spawn_v1_villagers = False
        self.storage_version = 0
        self.time = 0
        self.xbl_broadcast = False
        self.xbl_broadcast_intent = 0
        self.xbl_broadcast_mode = 0
        self.abilities = Abilities()
        self.bonus_chest_enabled = False
        self.bonus_chest_spawned = False
        self.command_block_output = False
        self.command_blocks_enabled = False
        self.commands_enabled = False
        self.current_tick = 0
        self.do_day_light_cycle = False
        self.do_entity_drops = False
        self.do_fire_tick = False
        self.do_immediate_respawn = False
        self.do_insomnia = False
        self.do_mob_loot = False
        self.do_mob_spawning = False
        self.do_tile_drops = False
        self.do_weather_cycle = False
        self.drowning_damage = False
        self.edu_level = False
        self.education_features_enabled = False
        self.experimental_game_play = False
        self.fall_damage = False
        self.fire_damage = False
        self.function_command_limit = 0
        self.has_been_loaded_in_creative = False
        self.has_locked_behaviour_pack = False
        self.has_locked_resource_pack = False
        self.immutable_world = False
        self.is_created_in_editor = False
        self.is_exported_from_editor = False
        self.is_from_locked_template = False
        self.is_from_world_template = False
        self.is_world_template_option_locked = False
        self.keep_inventory = False
        self.last_opened_with_version = List[Int32]()
        self.lightning_level = 0
        self.lightning_time = 0
        self.max_command_chain_length = 0
        self.mob_griefing = False
        self.natural_regeneration = False
        self.prid = String()
        self.pvp = False
        self.rain_level = 0
        self.rain_time = 0
        self.random_tick_speed = 0
        self.requires_copied_pack_removal_check = False
        self.send_command_feedback = False
        self.server_chunk_tick_range = 0
        self.show_coordinates = False
        self.show_death_messages = False
        self.spawn_mobs = False
        self.spawn_radius = 0
        self.start_with_map_enabled = False
        self.texture_packs_required = False
        self.tnt_explodes = False
        self.use_msa_gamer_tags_only = False
        self.world_start_count = 0
        self.experiments = Tree()
        self.freeze_damage = False
        self.world_policies = Tree()
        self.world_version = 0
        self.respawn_blocks_explode = False
        self.show_border_effect = False
        self.permissions_level = 0
        self.player_permissions_level = 0
        self.is_random_seed_allowed = False
        self.do_limited_crafting = False
        self.editor_world_type = 0
        self.players_sleeping_percentage = 0
        self.recipes_unlock = False
        self.natural_generation = False
        self.projectiles_can_break_blocks = False
        self.show_recipe_messages = False
        self.is_hardcore = False
        self.show_days_played = False
        self.tnt_explosion_drop_decay = False
        self.has_uncomplete_world_file_on_disk = False
        self.player_has_died = False
        self.use_allow_list = False
        self.allow_anonymous_block_drops_in_editor_worlds = False
        self.player_waypoints = 0
        self.server_editor_connection_policy = 0
        self.extra = Tree()

    def marshal_into(self, mut t: Tree, c: Tag) raises:
        """Writes the fields into a compound in Go's field order.

        Args:
            t: The tree.
            c: The compound to fill.

        Raises:
            If the tree rejects a value.
        """
        _ = t.put_string(c, "baseGameVersion", self.base_game_version)
        _ = t.put_string(c, "BiomeOverride", self.biome_override)
        _ = t.put_bool(
            c,
            "ConfirmedPlatformLockedContent",
            self.confirmed_platform_locked_content,
        )
        _ = t.put_bool(c, "CenterMapsToOrigin", self.centre_maps_to_origin)
        _ = t.put_bool(c, "cheatsEnabled", self.cheats_enabled)
        _ = t.put_int(c, "daylightCycle", self.daylight_cycle)
        _ = t.put_int(c, "Difficulty", self.difficulty)
        _ = t.put_int(c, "eduOffer", self.edu_offer)
        _ = t.put_string(c, "FlatWorldLayers", self.flat_world_layers)
        _ = t.put_bool(c, "ForceGameType", self.force_game_type)
        _ = t.put_int(c, "GameType", self.game_type)
        _ = t.put_int(c, "Generator", self.generator)
        _ = t.put_string(c, "InventoryVersion", self.inventory_version)
        _ = t.put_bool(c, "LANBroadcast", self.lan_broadcast)
        _ = t.put_bool(c, "LANBroadcastIntent", self.lan_broadcast_intent)
        _ = t.put_long(c, "LastPlayed", self.last_played)
        _ = t.put_string(c, "LevelName", self.level_name)
        _ = t.put_int(c, "LimitedWorldOriginX", self.limited_world_origin_x)
        _ = t.put_int(c, "LimitedWorldOriginY", self.limited_world_origin_y)
        _ = t.put_int(c, "LimitedWorldOriginZ", self.limited_world_origin_z)
        _ = t.put_int(c, "limitedWorldDepth", self.limited_world_depth)
        _ = t.put_int(c, "limitedWorldWidth", self.limited_world_width)
        _ = t.put_bool(c, "locatorbar", self.locator_bar)
        _put_int_list(
            t,
            c,
            "MinimumCompatibleClientVersion",
            self.minimum_compatible_client_version,
        )
        _ = t.put_bool(c, "MultiplayerGame", self.multi_player_game)
        _ = t.put_bool(
            c, "MultiplayerGameIntent", self.multi_player_game_intent
        )
        _ = t.put_int(c, "NetherScale", self.nether_scale)
        _ = t.put_int(c, "NetworkVersion", self.network_version)
        _ = t.put_int(c, "Platform", self.platform)
        _ = t.put_int(
            c, "PlatformBroadcastIntent", self.platform_broadcast_intent
        )
        _ = t.put_long(c, "RandomSeed", self.random_seed)
        _ = t.put_bool(c, "showtags", self.show_tags)
        _ = t.put_bool(c, "isSingleUseWorld", self.single_use_world)
        _ = t.put_int(c, "SpawnX", self.spawn_x)
        _ = t.put_int(c, "SpawnY", self.spawn_y)
        _ = t.put_int(c, "SpawnZ", self.spawn_z)
        _ = t.put_bool(c, "SpawnV1Villagers", self.spawn_v1_villagers)
        _ = t.put_int(c, "StorageVersion", self.storage_version)
        _ = t.put_long(c, "Time", self.time)
        _ = t.put_bool(c, "XBLBroadcast", self.xbl_broadcast)
        _ = t.put_int(c, "XBLBroadcastIntent", self.xbl_broadcast_intent)
        _ = t.put_int(c, "XBLBroadcastMode", self.xbl_broadcast_mode)
        self.abilities.marshal_into(t, t.put_compound(c, "abilities"))
        _ = t.put_bool(c, "bonusChestEnabled", self.bonus_chest_enabled)
        _ = t.put_bool(c, "bonusChestSpawned", self.bonus_chest_spawned)
        _ = t.put_bool(c, "commandblockoutput", self.command_block_output)
        _ = t.put_bool(c, "commandblocksenabled", self.command_blocks_enabled)
        _ = t.put_bool(c, "commandsEnabled", self.commands_enabled)
        _ = t.put_long(c, "currentTick", self.current_tick)
        _ = t.put_bool(c, "dodaylightcycle", self.do_day_light_cycle)
        _ = t.put_bool(c, "doentitydrops", self.do_entity_drops)
        _ = t.put_bool(c, "dofiretick", self.do_fire_tick)
        _ = t.put_bool(c, "doimmediaterespawn", self.do_immediate_respawn)
        _ = t.put_bool(c, "doinsomnia", self.do_insomnia)
        _ = t.put_bool(c, "domobloot", self.do_mob_loot)
        _ = t.put_bool(c, "domobspawning", self.do_mob_spawning)
        _ = t.put_bool(c, "dotiledrops", self.do_tile_drops)
        _ = t.put_bool(c, "doweathercycle", self.do_weather_cycle)
        _ = t.put_bool(c, "drowningdamage", self.drowning_damage)
        _ = t.put_bool(c, "eduLevel", self.edu_level)
        _ = t.put_bool(
            c, "educationFeaturesEnabled", self.education_features_enabled
        )
        _ = t.put_bool(c, "experimentalgameplay", self.experimental_game_play)
        _ = t.put_bool(c, "falldamage", self.fall_damage)
        _ = t.put_bool(c, "firedamage", self.fire_damage)
        _ = t.put_int(c, "functioncommandlimit", self.function_command_limit)
        _ = t.put_bool(
            c, "hasBeenLoadedInCreative", self.has_been_loaded_in_creative
        )
        _ = t.put_bool(
            c, "hasLockedBehaviorPack", self.has_locked_behaviour_pack
        )
        _ = t.put_bool(
            c, "hasLockedResourcePack", self.has_locked_resource_pack
        )
        _ = t.put_bool(c, "immutableWorld", self.immutable_world)
        _ = t.put_bool(c, "isCreatedInEditor", self.is_created_in_editor)
        _ = t.put_bool(c, "isExportedFromEditor", self.is_exported_from_editor)
        _ = t.put_bool(c, "isFromLockedTemplate", self.is_from_locked_template)
        _ = t.put_bool(c, "isFromWorldTemplate", self.is_from_world_template)
        _ = t.put_bool(
            c,
            "isWorldTemplateOptionLocked",
            self.is_world_template_option_locked,
        )
        _ = t.put_bool(c, "keepinventory", self.keep_inventory)
        _put_int_list(
            t, c, "lastOpenedWithVersion", self.last_opened_with_version
        )
        _ = t.put_float(c, "lightningLevel", self.lightning_level)
        _ = t.put_int(c, "lightningTime", self.lightning_time)
        _ = t.put_int(c, "maxcommandchainlength", self.max_command_chain_length)
        _ = t.put_bool(c, "mobgriefing", self.mob_griefing)
        _ = t.put_bool(c, "naturalregeneration", self.natural_regeneration)
        _ = t.put_string(c, "prid", self.prid)
        _ = t.put_bool(c, "pvp", self.pvp)
        _ = t.put_float(c, "rainLevel", self.rain_level)
        _ = t.put_int(c, "rainTime", self.rain_time)
        _ = t.put_int(c, "randomtickspeed", self.random_tick_speed)
        _ = t.put_bool(
            c,
            "requiresCopiedPackRemovalCheck",
            self.requires_copied_pack_removal_check,
        )
        _ = t.put_bool(c, "sendcommandfeedback", self.send_command_feedback)
        _ = t.put_int(c, "serverChunkTickRange", self.server_chunk_tick_range)
        _ = t.put_bool(c, "showcoordinates", self.show_coordinates)
        _ = t.put_bool(c, "showdeathmessages", self.show_death_messages)
        _ = t.put_bool(c, "spawnMobs", self.spawn_mobs)
        _ = t.put_int(c, "spawnradius", self.spawn_radius)
        _ = t.put_bool(c, "startWithMapEnabled", self.start_with_map_enabled)
        _ = t.put_bool(c, "texturePacksRequired", self.texture_packs_required)
        _ = t.put_bool(c, "tntexplodes", self.tnt_explodes)
        _ = t.put_bool(c, "useMsaGamertagsOnly", self.use_msa_gamer_tags_only)
        _ = t.put_long(c, "worldStartCount", self.world_start_count)
        _put_map(t, c, "experiments", self.experiments)
        _ = t.put_bool(c, "freezedamage", self.freeze_damage)
        _put_map(t, c, "world_policies", self.world_policies)
        _ = t.put_int(c, "WorldVersion", self.world_version)
        _ = t.put_bool(c, "respawnblocksexplode", self.respawn_blocks_explode)
        _ = t.put_bool(c, "showbordereffect", self.show_border_effect)
        _ = t.put_int(c, "permissionsLevel", self.permissions_level)
        _ = t.put_int(
            c, "playerPermissionsLevel", self.player_permissions_level
        )
        _ = t.put_bool(c, "isRandomSeedAllowed", self.is_random_seed_allowed)
        _ = t.put_bool(c, "dolimitedcrafting", self.do_limited_crafting)
        _ = t.put_int(c, "editorWorldType", self.editor_world_type)
        _ = t.put_int(
            c, "playerssleepingpercentage", self.players_sleeping_percentage
        )
        _ = t.put_bool(c, "recipesunlock", self.recipes_unlock)
        _ = t.put_bool(c, "naturalgeneration", self.natural_generation)
        _ = t.put_bool(
            c, "projectilescanbreakblocks", self.projectiles_can_break_blocks
        )
        _ = t.put_bool(c, "showrecipemessages", self.show_recipe_messages)
        _ = t.put_bool(c, "IsHardcore", self.is_hardcore)
        _ = t.put_bool(c, "showdaysplayed", self.show_days_played)
        _ = t.put_bool(
            c, "tntexplosiondropdecay", self.tnt_explosion_drop_decay
        )
        _ = t.put_bool(
            c,
            "HasUncompleteWorldFileOnDisk",
            self.has_uncomplete_world_file_on_disk,
        )
        _ = t.put_bool(c, "PlayerHasDied", self.player_has_died)
        _ = t.put_bool(c, "UseAllowList", self.use_allow_list)
        _ = t.put_bool(
            c,
            "allowAnonymousBlockDropsInEditorWorlds",
            self.allow_anonymous_block_drops_in_editor_worlds,
        )
        _ = t.put_int(c, "playerwaypoints", self.player_waypoints)
        _ = t.put_int(
            c,
            "serverEditorConnectionPolicy",
            self.server_editor_connection_policy,
        )
        for e in self.extra.children(self.extra.root()):
            _ = t.put_tree(c, self.extra.name(e), self.extra, e)

    def unmarshal_from(mut self, t: Tree, c: Tag) raises:
        """Reads the fields present in a compound (Go `nbt.Unmarshal`).

        Args:
            t: The tree.
            c: The compound.

        Raises:
            If a known field has the wrong type.
        """
        for e in t.children(c):
            var n = t.name(e)
            if n == "baseGameVersion":
                _expect(t, e, TAG_STRING)
                self.base_game_version = t.as_string(e)
            elif n == "BiomeOverride":
                _expect(t, e, TAG_STRING)
                self.biome_override = t.as_string(e)
            elif n == "ConfirmedPlatformLockedContent":
                _expect(t, e, TAG_BYTE)
                self.confirmed_platform_locked_content = t.as_bool(e)
            elif n == "CenterMapsToOrigin":
                _expect(t, e, TAG_BYTE)
                self.centre_maps_to_origin = t.as_bool(e)
            elif n == "cheatsEnabled":
                _expect(t, e, TAG_BYTE)
                self.cheats_enabled = t.as_bool(e)
            elif n == "daylightCycle":
                _expect(t, e, TAG_INT)
                self.daylight_cycle = t.as_int(e)
            elif n == "Difficulty":
                _expect(t, e, TAG_INT)
                self.difficulty = t.as_int(e)
            elif n == "eduOffer":
                _expect(t, e, TAG_INT)
                self.edu_offer = t.as_int(e)
            elif n == "FlatWorldLayers":
                _expect(t, e, TAG_STRING)
                self.flat_world_layers = t.as_string(e)
            elif n == "ForceGameType":
                _expect(t, e, TAG_BYTE)
                self.force_game_type = t.as_bool(e)
            elif n == "GameType":
                _expect(t, e, TAG_INT)
                self.game_type = t.as_int(e)
            elif n == "Generator":
                _expect(t, e, TAG_INT)
                self.generator = t.as_int(e)
            elif n == "InventoryVersion":
                _expect(t, e, TAG_STRING)
                self.inventory_version = t.as_string(e)
            elif n == "LANBroadcast":
                _expect(t, e, TAG_BYTE)
                self.lan_broadcast = t.as_bool(e)
            elif n == "LANBroadcastIntent":
                _expect(t, e, TAG_BYTE)
                self.lan_broadcast_intent = t.as_bool(e)
            elif n == "LastPlayed":
                _expect(t, e, TAG_LONG)
                self.last_played = t.as_long(e)
            elif n == "LevelName":
                _expect(t, e, TAG_STRING)
                self.level_name = t.as_string(e)
            elif n == "LimitedWorldOriginX":
                _expect(t, e, TAG_INT)
                self.limited_world_origin_x = t.as_int(e)
            elif n == "LimitedWorldOriginY":
                _expect(t, e, TAG_INT)
                self.limited_world_origin_y = t.as_int(e)
            elif n == "LimitedWorldOriginZ":
                _expect(t, e, TAG_INT)
                self.limited_world_origin_z = t.as_int(e)
            elif n == "limitedWorldDepth":
                _expect(t, e, TAG_INT)
                self.limited_world_depth = t.as_int(e)
            elif n == "limitedWorldWidth":
                _expect(t, e, TAG_INT)
                self.limited_world_width = t.as_int(e)
            elif n == "locatorbar":
                _expect(t, e, TAG_BYTE)
                self.locator_bar = t.as_bool(e)
            elif n == "MinimumCompatibleClientVersion":
                self.minimum_compatible_client_version = _get_int_list(t, e)
            elif n == "MultiplayerGame":
                _expect(t, e, TAG_BYTE)
                self.multi_player_game = t.as_bool(e)
            elif n == "MultiplayerGameIntent":
                _expect(t, e, TAG_BYTE)
                self.multi_player_game_intent = t.as_bool(e)
            elif n == "NetherScale":
                _expect(t, e, TAG_INT)
                self.nether_scale = t.as_int(e)
            elif n == "NetworkVersion":
                _expect(t, e, TAG_INT)
                self.network_version = t.as_int(e)
            elif n == "Platform":
                _expect(t, e, TAG_INT)
                self.platform = t.as_int(e)
            elif n == "PlatformBroadcastIntent":
                _expect(t, e, TAG_INT)
                self.platform_broadcast_intent = t.as_int(e)
            elif n == "RandomSeed":
                _expect(t, e, TAG_LONG)
                self.random_seed = t.as_long(e)
            elif n == "showtags":
                _expect(t, e, TAG_BYTE)
                self.show_tags = t.as_bool(e)
            elif n == "isSingleUseWorld":
                _expect(t, e, TAG_BYTE)
                self.single_use_world = t.as_bool(e)
            elif n == "SpawnX":
                _expect(t, e, TAG_INT)
                self.spawn_x = t.as_int(e)
            elif n == "SpawnY":
                _expect(t, e, TAG_INT)
                self.spawn_y = t.as_int(e)
            elif n == "SpawnZ":
                _expect(t, e, TAG_INT)
                self.spawn_z = t.as_int(e)
            elif n == "SpawnV1Villagers":
                _expect(t, e, TAG_BYTE)
                self.spawn_v1_villagers = t.as_bool(e)
            elif n == "StorageVersion":
                _expect(t, e, TAG_INT)
                self.storage_version = t.as_int(e)
            elif n == "Time":
                _expect(t, e, TAG_LONG)
                self.time = t.as_long(e)
            elif n == "XBLBroadcast":
                _expect(t, e, TAG_BYTE)
                self.xbl_broadcast = t.as_bool(e)
            elif n == "XBLBroadcastIntent":
                _expect(t, e, TAG_INT)
                self.xbl_broadcast_intent = t.as_int(e)
            elif n == "XBLBroadcastMode":
                _expect(t, e, TAG_INT)
                self.xbl_broadcast_mode = t.as_int(e)
            elif n == "abilities":
                _expect(t, e, TAG_COMPOUND)
                self.abilities.unmarshal_from(t, e)
            elif n == "bonusChestEnabled":
                _expect(t, e, TAG_BYTE)
                self.bonus_chest_enabled = t.as_bool(e)
            elif n == "bonusChestSpawned":
                _expect(t, e, TAG_BYTE)
                self.bonus_chest_spawned = t.as_bool(e)
            elif n == "commandblockoutput":
                _expect(t, e, TAG_BYTE)
                self.command_block_output = t.as_bool(e)
            elif n == "commandblocksenabled":
                _expect(t, e, TAG_BYTE)
                self.command_blocks_enabled = t.as_bool(e)
            elif n == "commandsEnabled":
                _expect(t, e, TAG_BYTE)
                self.commands_enabled = t.as_bool(e)
            elif n == "currentTick":
                _expect(t, e, TAG_LONG)
                self.current_tick = t.as_long(e)
            elif n == "dodaylightcycle":
                _expect(t, e, TAG_BYTE)
                self.do_day_light_cycle = t.as_bool(e)
            elif n == "doentitydrops":
                _expect(t, e, TAG_BYTE)
                self.do_entity_drops = t.as_bool(e)
            elif n == "dofiretick":
                _expect(t, e, TAG_BYTE)
                self.do_fire_tick = t.as_bool(e)
            elif n == "doimmediaterespawn":
                _expect(t, e, TAG_BYTE)
                self.do_immediate_respawn = t.as_bool(e)
            elif n == "doinsomnia":
                _expect(t, e, TAG_BYTE)
                self.do_insomnia = t.as_bool(e)
            elif n == "domobloot":
                _expect(t, e, TAG_BYTE)
                self.do_mob_loot = t.as_bool(e)
            elif n == "domobspawning":
                _expect(t, e, TAG_BYTE)
                self.do_mob_spawning = t.as_bool(e)
            elif n == "dotiledrops":
                _expect(t, e, TAG_BYTE)
                self.do_tile_drops = t.as_bool(e)
            elif n == "doweathercycle":
                _expect(t, e, TAG_BYTE)
                self.do_weather_cycle = t.as_bool(e)
            elif n == "drowningdamage":
                _expect(t, e, TAG_BYTE)
                self.drowning_damage = t.as_bool(e)
            elif n == "eduLevel":
                _expect(t, e, TAG_BYTE)
                self.edu_level = t.as_bool(e)
            elif n == "educationFeaturesEnabled":
                _expect(t, e, TAG_BYTE)
                self.education_features_enabled = t.as_bool(e)
            elif n == "experimentalgameplay":
                _expect(t, e, TAG_BYTE)
                self.experimental_game_play = t.as_bool(e)
            elif n == "falldamage":
                _expect(t, e, TAG_BYTE)
                self.fall_damage = t.as_bool(e)
            elif n == "firedamage":
                _expect(t, e, TAG_BYTE)
                self.fire_damage = t.as_bool(e)
            elif n == "functioncommandlimit":
                _expect(t, e, TAG_INT)
                self.function_command_limit = t.as_int(e)
            elif n == "hasBeenLoadedInCreative":
                _expect(t, e, TAG_BYTE)
                self.has_been_loaded_in_creative = t.as_bool(e)
            elif n == "hasLockedBehaviorPack":
                _expect(t, e, TAG_BYTE)
                self.has_locked_behaviour_pack = t.as_bool(e)
            elif n == "hasLockedResourcePack":
                _expect(t, e, TAG_BYTE)
                self.has_locked_resource_pack = t.as_bool(e)
            elif n == "immutableWorld":
                _expect(t, e, TAG_BYTE)
                self.immutable_world = t.as_bool(e)
            elif n == "isCreatedInEditor":
                _expect(t, e, TAG_BYTE)
                self.is_created_in_editor = t.as_bool(e)
            elif n == "isExportedFromEditor":
                _expect(t, e, TAG_BYTE)
                self.is_exported_from_editor = t.as_bool(e)
            elif n == "isFromLockedTemplate":
                _expect(t, e, TAG_BYTE)
                self.is_from_locked_template = t.as_bool(e)
            elif n == "isFromWorldTemplate":
                _expect(t, e, TAG_BYTE)
                self.is_from_world_template = t.as_bool(e)
            elif n == "isWorldTemplateOptionLocked":
                _expect(t, e, TAG_BYTE)
                self.is_world_template_option_locked = t.as_bool(e)
            elif n == "keepinventory":
                _expect(t, e, TAG_BYTE)
                self.keep_inventory = t.as_bool(e)
            elif n == "lastOpenedWithVersion":
                self.last_opened_with_version = _get_int_list(t, e)
            elif n == "lightningLevel":
                _expect(t, e, TAG_FLOAT)
                self.lightning_level = t.as_float(e)
            elif n == "lightningTime":
                _expect(t, e, TAG_INT)
                self.lightning_time = t.as_int(e)
            elif n == "maxcommandchainlength":
                _expect(t, e, TAG_INT)
                self.max_command_chain_length = t.as_int(e)
            elif n == "mobgriefing":
                _expect(t, e, TAG_BYTE)
                self.mob_griefing = t.as_bool(e)
            elif n == "naturalregeneration":
                _expect(t, e, TAG_BYTE)
                self.natural_regeneration = t.as_bool(e)
            elif n == "prid":
                _expect(t, e, TAG_STRING)
                self.prid = t.as_string(e)
            elif n == "pvp":
                _expect(t, e, TAG_BYTE)
                self.pvp = t.as_bool(e)
            elif n == "rainLevel":
                _expect(t, e, TAG_FLOAT)
                self.rain_level = t.as_float(e)
            elif n == "rainTime":
                _expect(t, e, TAG_INT)
                self.rain_time = t.as_int(e)
            elif n == "randomtickspeed":
                _expect(t, e, TAG_INT)
                self.random_tick_speed = t.as_int(e)
            elif n == "requiresCopiedPackRemovalCheck":
                _expect(t, e, TAG_BYTE)
                self.requires_copied_pack_removal_check = t.as_bool(e)
            elif n == "sendcommandfeedback":
                _expect(t, e, TAG_BYTE)
                self.send_command_feedback = t.as_bool(e)
            elif n == "serverChunkTickRange":
                _expect(t, e, TAG_INT)
                self.server_chunk_tick_range = t.as_int(e)
            elif n == "showcoordinates":
                _expect(t, e, TAG_BYTE)
                self.show_coordinates = t.as_bool(e)
            elif n == "showdeathmessages":
                _expect(t, e, TAG_BYTE)
                self.show_death_messages = t.as_bool(e)
            elif n == "spawnMobs":
                _expect(t, e, TAG_BYTE)
                self.spawn_mobs = t.as_bool(e)
            elif n == "spawnradius":
                _expect(t, e, TAG_INT)
                self.spawn_radius = t.as_int(e)
            elif n == "startWithMapEnabled":
                _expect(t, e, TAG_BYTE)
                self.start_with_map_enabled = t.as_bool(e)
            elif n == "texturePacksRequired":
                _expect(t, e, TAG_BYTE)
                self.texture_packs_required = t.as_bool(e)
            elif n == "tntexplodes":
                _expect(t, e, TAG_BYTE)
                self.tnt_explodes = t.as_bool(e)
            elif n == "useMsaGamertagsOnly":
                _expect(t, e, TAG_BYTE)
                self.use_msa_gamer_tags_only = t.as_bool(e)
            elif n == "worldStartCount":
                _expect(t, e, TAG_LONG)
                self.world_start_count = t.as_long(e)
            elif n == "experiments":
                _expect(t, e, TAG_COMPOUND)
                self.experiments = _get_map(t, e)
            elif n == "freezedamage":
                _expect(t, e, TAG_BYTE)
                self.freeze_damage = t.as_bool(e)
            elif n == "world_policies":
                _expect(t, e, TAG_COMPOUND)
                self.world_policies = _get_map(t, e)
            elif n == "WorldVersion":
                _expect(t, e, TAG_INT)
                self.world_version = t.as_int(e)
            elif n == "respawnblocksexplode":
                _expect(t, e, TAG_BYTE)
                self.respawn_blocks_explode = t.as_bool(e)
            elif n == "showbordereffect":
                _expect(t, e, TAG_BYTE)
                self.show_border_effect = t.as_bool(e)
            elif n == "permissionsLevel":
                _expect(t, e, TAG_INT)
                self.permissions_level = t.as_int(e)
            elif n == "playerPermissionsLevel":
                _expect(t, e, TAG_INT)
                self.player_permissions_level = t.as_int(e)
            elif n == "isRandomSeedAllowed":
                _expect(t, e, TAG_BYTE)
                self.is_random_seed_allowed = t.as_bool(e)
            elif n == "dolimitedcrafting":
                _expect(t, e, TAG_BYTE)
                self.do_limited_crafting = t.as_bool(e)
            elif n == "editorWorldType":
                _expect(t, e, TAG_INT)
                self.editor_world_type = t.as_int(e)
            elif n == "playerssleepingpercentage":
                _expect(t, e, TAG_INT)
                self.players_sleeping_percentage = t.as_int(e)
            elif n == "recipesunlock":
                _expect(t, e, TAG_BYTE)
                self.recipes_unlock = t.as_bool(e)
            elif n == "naturalgeneration":
                _expect(t, e, TAG_BYTE)
                self.natural_generation = t.as_bool(e)
            elif n == "projectilescanbreakblocks":
                _expect(t, e, TAG_BYTE)
                self.projectiles_can_break_blocks = t.as_bool(e)
            elif n == "showrecipemessages":
                _expect(t, e, TAG_BYTE)
                self.show_recipe_messages = t.as_bool(e)
            elif n == "IsHardcore":
                _expect(t, e, TAG_BYTE)
                self.is_hardcore = t.as_bool(e)
            elif n == "showdaysplayed":
                _expect(t, e, TAG_BYTE)
                self.show_days_played = t.as_bool(e)
            elif n == "tntexplosiondropdecay":
                _expect(t, e, TAG_BYTE)
                self.tnt_explosion_drop_decay = t.as_bool(e)
            elif n == "HasUncompleteWorldFileOnDisk":
                _expect(t, e, TAG_BYTE)
                self.has_uncomplete_world_file_on_disk = t.as_bool(e)
            elif n == "PlayerHasDied":
                _expect(t, e, TAG_BYTE)
                self.player_has_died = t.as_bool(e)
            elif n == "UseAllowList":
                _expect(t, e, TAG_BYTE)
                self.use_allow_list = t.as_bool(e)
            elif n == "allowAnonymousBlockDropsInEditorWorlds":
                _expect(t, e, TAG_BYTE)
                self.allow_anonymous_block_drops_in_editor_worlds = t.as_bool(e)
            elif n == "playerwaypoints":
                _expect(t, e, TAG_INT)
                self.player_waypoints = t.as_int(e)
            elif n == "serverEditorConnectionPolicy":
                _expect(t, e, TAG_INT)
                self.server_editor_connection_policy = t.as_int(e)
            else:
                _ = self.extra.put_tree(self.extra.root(), n, t, e)

    def fill_default(mut self):
        """Sets every default `level.dat` value Dragonfly writes for a new
        world (Go `FillDefault`); `random_seed` is the current Unix time.
        """
        self.abilities.attack_mobs = True
        self.abilities.attack_players = True
        self.abilities.build = True
        self.abilities.doors_and_switches = True
        self.abilities.fly_speed = 0.05
        self.abilities.mine = True
        self.abilities.open_containers = True
        self.abilities.player_permissions_level = 1
        self.abilities.walk_speed = 0.1
        self.abilities.vertical_fly_speed = 1.0
        self.base_game_version = "*"
        self.command_block_output = True
        self.command_blocks_enabled = True
        self.commands_enabled = True
        self.difficulty = 2
        self.do_day_light_cycle = True
        self.do_entity_drops = True
        self.do_fire_tick = True
        self.do_insomnia = True
        self.do_mob_loot = True
        self.do_mob_spawning = True
        self.do_tile_drops = True
        self.do_weather_cycle = True
        self.drowning_damage = True
        self.fall_damage = True
        self.fire_damage = True
        self.freeze_damage = True
        self.function_command_limit = 10000
        self.game_type = 1
        self.generator = 2
        self.has_been_loaded_in_creative = True
        self.inventory_version = String(CURRENT_VERSION)
        self.lan_broadcast = True
        self.lan_broadcast_intent = True
        self.last_opened_with_version = minimum_compatible_client_version()
        self.level_name = "World"
        self.lightning_level = 1.0
        self.limited_world_depth = 16
        self.limited_world_origin_y = 32767
        self.limited_world_width = 16
        self.max_command_chain_length = 65535
        self.minimum_compatible_client_version = (
            minimum_compatible_client_version()
        )
        self.mob_griefing = True
        self.multi_player_game = True
        self.multi_player_game_intent = True
        self.natural_regeneration = True
        self.nether_scale = 8
        self.network_version = CURRENT_PROTOCOL
        self.pvp = True
        self.platform = 2
        self.platform_broadcast_intent = 3
        self.rain_level = 1.0
        self.random_seed = Int64(unix_time_s())
        self.random_tick_speed = 1
        self.respawn_blocks_explode = True
        self.send_command_feedback = True
        self.server_chunk_tick_range = 6
        self.show_border_effect = True
        self.show_death_messages = True
        self.show_tags = True
        self.spawn_mobs = True
        self.spawn_radius = 5
        self.spawn_y = 32767
        self.storage_version = 9
        self.tnt_explodes = True
        self.world_version = 1
        self.xbl_broadcast_intent = 3

    def settings(mut self) -> Settings:
        """Returns the world settings stored in the data and counts a world
        start (Go `Settings`, which increments `WorldStartCount`).

        Returns:
            The settings. Unknown game mode or difficulty IDs give survival
            and normal, Go's fallbacks.
        """
        self.world_start_count += 1
        return Settings(
            name=self.level_name,
            spawn=Pos(Int(self.spawn_x), Int(self.spawn_y), Int(self.spawn_z)),
            time=self.time,
            time_cycle=self.do_day_light_cycle,
            rain_time=Int64(self.rain_time),
            raining=self.rain_level > 0,
            thunder_time=Int64(self.lightning_time),
            thundering=self.lightning_level > 0,
            weather_cycle=self.do_weather_cycle,
            required_sleep_ticks=0,
            current_tick=self.current_tick,
            default_game_mode=game_mode_by_id(Int(self.game_type)).or_else(
                GAME_MODE_SURVIVAL
            ),
            difficulty=difficulty_by_id(Int(self.difficulty)).or_else(
                DIFFICULTY_NORMAL
            ),
            tick_range=self.server_chunk_tick_range,
        )

    def put_settings(mut self, s: Settings):
        """Stores world settings in the data (Go `PutSettings`).

        Args:
            s: The settings.
        """
        self.level_name = s.name
        self.spawn_x = Int32(s.spawn.x())
        self.spawn_y = Int32(s.spawn.y())
        self.spawn_z = Int32(s.spawn.z())
        self.limited_world_origin_x = self.spawn_x
        self.limited_world_origin_y = self.spawn_y
        self.limited_world_origin_z = self.spawn_z
        self.time = s.time
        self.do_day_light_cycle = s.time_cycle
        self.do_weather_cycle = s.weather_cycle
        self.rain_time = Int32(s.rain_time)
        self.rain_level = 0
        self.lightning_time = Int32(s.thunder_time)
        self.lightning_level = 0
        if s.raining:
            self.rain_level = 1
        if s.thundering:
            self.lightning_level = 1
        self.current_tick = s.current_tick
        self.server_chunk_tick_range = s.tick_range
        self.game_type = Int32(s.default_game_mode.id)
        self.difficulty = Int32(s.difficulty.id)

    def marshal(self) raises -> Tree:
        """Encodes the data as a root compound (Go `nbt.Marshal(Data)`).

        Returns:
            The tree.

        Raises:
            If the tree rejects a value.
        """
        var t = Tree()
        self.marshal_into(t, t.root())
        return t^

    @staticmethod
    def unmarshal(t: Tree) raises -> Data:
        """Decodes a root compound (Go `nbt.Unmarshal` into `Data`).

        Args:
            t: The decoded `level.dat` payload.

        Returns:
            The data; fields absent from the compound keep zero values.

        Raises:
            If the root is not a compound or a known field has the wrong
            type.
        """
        if t.is_empty() or t.type_of(t.root()) != TAG_COMPOUND:
            raise Error("level.dat: root is not a compound")
        var d = Data()
        d.unmarshal_from(t, t.root())
        return d^
