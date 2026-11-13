"""Base hashes of the block types, ported from Dragonfly `server/block/hash.go`.

Go generates these with `cmd/blockhash` as an `iota` sequence; the values
here are the same, so `BlockRegistry.block_hash` matches Dragonfly's
`BlockHash` for every ported block. Each block type uses its constant as
`BASE_HASH`.

`AnyBlock` and `hash_block` serve the blocks that wrap another block (Go
`Slab.Block`, `Stairs.Block`, `Wall.Block` are `world.Block` values).
"""

from ..world.block import Block

comptime HASH_AIR: UInt64 = 0
"""Base hash of `Air` (Go `hashAir`)."""
comptime HASH_AMETHYST: UInt64 = 1
"""Base hash of `Amethyst` (Go `hashAmethyst`)."""
comptime HASH_ANCIENT_DEBRIS: UInt64 = 2
"""Base hash of `AncientDebris` (Go `hashAncientDebris`)."""
comptime HASH_ANDESITE: UInt64 = 3
"""Base hash of `Andesite` (Go `hashAndesite`)."""
comptime HASH_ANVIL: UInt64 = 4
"""Base hash of `Anvil` (Go `hashAnvil`)."""
comptime HASH_BAMBOO: UInt64 = 5
"""Base hash of `Bamboo` (Go `hashBamboo`)."""
comptime HASH_BAMBOO_BLOCK: UInt64 = 6
"""Base hash of `BambooBlock` (Go `hashBambooBlock`)."""
comptime HASH_BAMBOO_MOSAIC: UInt64 = 7
"""Base hash of `BambooMosaic` (Go `hashBambooMosaic`)."""
comptime HASH_BAMBOO_SAPLING: UInt64 = 8
"""Base hash of `BambooSapling` (Go `hashBambooSapling`)."""
comptime HASH_BANNER: UInt64 = 9
"""Base hash of `Banner` (Go `hashBanner`)."""
comptime HASH_BARREL: UInt64 = 10
"""Base hash of `Barrel` (Go `hashBarrel`)."""
comptime HASH_BARRIER: UInt64 = 11
"""Base hash of `Barrier` (Go `hashBarrier`)."""
comptime HASH_BASALT: UInt64 = 12
"""Base hash of `Basalt` (Go `hashBasalt`)."""
comptime HASH_BEACON: UInt64 = 13
"""Base hash of `Beacon` (Go `hashBeacon`)."""
comptime HASH_BED: UInt64 = 14
"""Base hash of `Bed` (Go `hashBed`)."""
comptime HASH_BEDROCK: UInt64 = 15
"""Base hash of `Bedrock` (Go `hashBedrock`)."""
comptime HASH_BEETROOT_SEEDS: UInt64 = 16
"""Base hash of `BeetrootSeeds` (Go `hashBeetrootSeeds`)."""
comptime HASH_BLACKSTONE: UInt64 = 17
"""Base hash of `Blackstone` (Go `hashBlackstone`)."""
comptime HASH_BLAST_FURNACE: UInt64 = 18
"""Base hash of `BlastFurnace` (Go `hashBlastFurnace`)."""
comptime HASH_BLUE_ICE: UInt64 = 19
"""Base hash of `BlueIce` (Go `hashBlueIce`)."""
comptime HASH_BONE: UInt64 = 20
"""Base hash of `Bone` (Go `hashBone`)."""
comptime HASH_BOOKSHELF: UInt64 = 21
"""Base hash of `Bookshelf` (Go `hashBookshelf`)."""
comptime HASH_BREWING_STAND: UInt64 = 22
"""Base hash of `BrewingStand` (Go `hashBrewingStand`)."""
comptime HASH_BRICKS: UInt64 = 23
"""Base hash of `Bricks` (Go `hashBricks`)."""
comptime HASH_CACTUS: UInt64 = 24
"""Base hash of `Cactus` (Go `hashCactus`)."""
comptime HASH_CAKE: UInt64 = 25
"""Base hash of `Cake` (Go `hashCake`)."""
comptime HASH_CALCITE: UInt64 = 26
"""Base hash of `Calcite` (Go `hashCalcite`)."""
comptime HASH_CAMPFIRE: UInt64 = 27
"""Base hash of `Campfire` (Go `hashCampfire`)."""
comptime HASH_CANDLE: UInt64 = 28
"""Base hash of `Candle` (Go `hashCandle`)."""
comptime HASH_CARPET: UInt64 = 29
"""Base hash of `Carpet` (Go `hashCarpet`)."""
comptime HASH_CARROT: UInt64 = 30
"""Base hash of `Carrot` (Go `hashCarrot`)."""
comptime HASH_CHEST: UInt64 = 31
"""Base hash of `Chest` (Go `hashChest`)."""
comptime HASH_CHISELED_QUARTZ: UInt64 = 32
"""Base hash of `ChiseledQuartz` (Go `hashChiseledQuartz`)."""
comptime HASH_CINNABAR: UInt64 = 33
"""Base hash of `Cinnabar` (Go `hashCinnabar`)."""
comptime HASH_CINNABAR_BRICKS: UInt64 = 34
"""Base hash of `CinnabarBricks` (Go `hashCinnabarBricks`)."""
comptime HASH_CLAY: UInt64 = 35
"""Base hash of `Clay` (Go `hashClay`)."""
comptime HASH_COAL: UInt64 = 36
"""Base hash of `Coal` (Go `hashCoal`)."""
comptime HASH_COAL_ORE: UInt64 = 37
"""Base hash of `CoalOre` (Go `hashCoalOre`)."""
comptime HASH_COBBLESTONE: UInt64 = 38
"""Base hash of `Cobblestone` (Go `hashCobblestone`)."""
comptime HASH_COBWEB: UInt64 = 39
"""Base hash of `Cobweb` (Go `hashCobweb`)."""
comptime HASH_COCOA_BEAN: UInt64 = 40
"""Base hash of `CocoaBean` (Go `hashCocoaBean`)."""
comptime HASH_COMPOSTER: UInt64 = 41
"""Base hash of `Composter` (Go `hashComposter`)."""
comptime HASH_CONCRETE: UInt64 = 42
"""Base hash of `Concrete` (Go `hashConcrete`)."""
comptime HASH_CONCRETE_POWDER: UInt64 = 43
"""Base hash of `ConcretePowder` (Go `hashConcretePowder`)."""
comptime HASH_COPPER: UInt64 = 44
"""Base hash of `Copper` (Go `hashCopper`)."""
comptime HASH_COPPER_BARS: UInt64 = 45
"""Base hash of `CopperBars` (Go `hashCopperBars`)."""
comptime HASH_COPPER_CHAIN: UInt64 = 46
"""Base hash of `CopperChain` (Go `hashCopperChain`)."""
comptime HASH_COPPER_DOOR: UInt64 = 47
"""Base hash of `CopperDoor` (Go `hashCopperDoor`)."""
comptime HASH_COPPER_GOLEM_STATUE: UInt64 = 48
"""Base hash of `CopperGolemStatue` (Go `hashCopperGolemStatue`)."""
comptime HASH_COPPER_GRATE: UInt64 = 49
"""Base hash of `CopperGrate` (Go `hashCopperGrate`)."""
comptime HASH_COPPER_LANTERN: UInt64 = 50
"""Base hash of `CopperLantern` (Go `hashCopperLantern`)."""
comptime HASH_COPPER_ORE: UInt64 = 51
"""Base hash of `CopperOre` (Go `hashCopperOre`)."""
comptime HASH_COPPER_TORCH: UInt64 = 52
"""Base hash of `CopperTorch` (Go `hashCopperTorch`)."""
comptime HASH_COPPER_TRAPDOOR: UInt64 = 53
"""Base hash of `CopperTrapdoor` (Go `hashCopperTrapdoor`)."""
comptime HASH_CORAL: UInt64 = 54
"""Base hash of `Coral` (Go `hashCoral`)."""
comptime HASH_CORAL_BLOCK: UInt64 = 55
"""Base hash of `CoralBlock` (Go `hashCoralBlock`)."""
comptime HASH_CRAFTING_TABLE: UInt64 = 56
"""Base hash of `CraftingTable` (Go `hashCraftingTable`)."""
comptime HASH_DEAD_BUSH: UInt64 = 57
"""Base hash of `DeadBush` (Go `hashDeadBush`)."""
comptime HASH_DECORATED_POT: UInt64 = 58
"""Base hash of `DecoratedPot` (Go `hashDecoratedPot`)."""
comptime HASH_DEEPSLATE: UInt64 = 59
"""Base hash of `Deepslate` (Go `hashDeepslate`)."""
comptime HASH_DEEPSLATE_BRICKS: UInt64 = 60
"""Base hash of `DeepslateBricks` (Go `hashDeepslateBricks`)."""
comptime HASH_DEEPSLATE_TILES: UInt64 = 61
"""Base hash of `DeepslateTiles` (Go `hashDeepslateTiles`)."""
comptime HASH_DIAMOND: UInt64 = 62
"""Base hash of `Diamond` (Go `hashDiamond`)."""
comptime HASH_DIAMOND_ORE: UInt64 = 63
"""Base hash of `DiamondOre` (Go `hashDiamondOre`)."""
comptime HASH_DIORITE: UInt64 = 64
"""Base hash of `Diorite` (Go `hashDiorite`)."""
comptime HASH_DIRT: UInt64 = 65
"""Base hash of `Dirt` (Go `hashDirt`)."""
comptime HASH_DIRT_PATH: UInt64 = 66
"""Base hash of `DirtPath` (Go `hashDirtPath`)."""
comptime HASH_DOUBLE_FLOWER: UInt64 = 67
"""Base hash of `DoubleFlower` (Go `hashDoubleFlower`)."""
comptime HASH_DOUBLE_TALL_GRASS: UInt64 = 68
"""Base hash of `DoubleTallGrass` (Go `hashDoubleTallGrass`)."""
comptime HASH_DRAGON_EGG: UInt64 = 69
"""Base hash of `DragonEgg` (Go `hashDragonEgg`)."""
comptime HASH_DRIED_KELP: UInt64 = 70
"""Base hash of `DriedKelp` (Go `hashDriedKelp`)."""
comptime HASH_DRIPSTONE: UInt64 = 71
"""Base hash of `Dripstone` (Go `hashDripstone`)."""
comptime HASH_EMERALD: UInt64 = 72
"""Base hash of `Emerald` (Go `hashEmerald`)."""
comptime HASH_EMERALD_ORE: UInt64 = 73
"""Base hash of `EmeraldOre` (Go `hashEmeraldOre`)."""
comptime HASH_ENCHANTING_TABLE: UInt64 = 74
"""Base hash of `EnchantingTable` (Go `hashEnchantingTable`)."""
comptime HASH_END_BRICKS: UInt64 = 75
"""Base hash of `EndBricks` (Go `hashEndBricks`)."""
comptime HASH_END_PORTAL: UInt64 = 76
"""Base hash of `EndPortal` (Go `hashEndPortal`)."""
comptime HASH_END_PORTAL_FRAME: UInt64 = 77
"""Base hash of `EndPortalFrame` (Go `hashEndPortalFrame`)."""
comptime HASH_END_ROD: UInt64 = 78
"""Base hash of `EndRod` (Go `hashEndRod`)."""
comptime HASH_END_STONE: UInt64 = 79
"""Base hash of `EndStone` (Go `hashEndStone`)."""
comptime HASH_ENDER_CHEST: UInt64 = 80
"""Base hash of `EnderChest` (Go `hashEnderChest`)."""
comptime HASH_FARMLAND: UInt64 = 81
"""Base hash of `Farmland` (Go `hashFarmland`)."""
comptime HASH_FERN: UInt64 = 82
"""Base hash of `Fern` (Go `hashFern`)."""
comptime HASH_FIRE: UInt64 = 83
"""Base hash of `Fire` (Go `hashFire`)."""
comptime HASH_FLETCHING_TABLE: UInt64 = 84
"""Base hash of `FletchingTable` (Go `hashFletchingTable`)."""
comptime HASH_FLOWER: UInt64 = 85
"""Base hash of `Flower` (Go `hashFlower`)."""
comptime HASH_FROGLIGHT: UInt64 = 86
"""Base hash of `Froglight` (Go `hashFroglight`)."""
comptime HASH_FURNACE: UInt64 = 87
"""Base hash of `Furnace` (Go `hashFurnace`)."""
comptime HASH_GLASS: UInt64 = 88
"""Base hash of `Glass` (Go `hashGlass`)."""
comptime HASH_GLASS_PANE: UInt64 = 89
"""Base hash of `GlassPane` (Go `hashGlassPane`)."""
comptime HASH_GLAZED_TERRACOTTA: UInt64 = 90
"""Base hash of `GlazedTerracotta` (Go `hashGlazedTerracotta`)."""
comptime HASH_GLOWSTONE: UInt64 = 91
"""Base hash of `Glowstone` (Go `hashGlowstone`)."""
comptime HASH_GOLD: UInt64 = 92
"""Base hash of `Gold` (Go `hashGold`)."""
comptime HASH_GOLD_ORE: UInt64 = 93
"""Base hash of `GoldOre` (Go `hashGoldOre`)."""
comptime HASH_GRANITE: UInt64 = 94
"""Base hash of `Granite` (Go `hashGranite`)."""
comptime HASH_GRASS: UInt64 = 95
"""Base hash of `Grass` (Go `hashGrass`)."""
comptime HASH_GRAVEL: UInt64 = 96
"""Base hash of `Gravel` (Go `hashGravel`)."""
comptime HASH_GRINDSTONE: UInt64 = 97
"""Base hash of `Grindstone` (Go `hashGrindstone`)."""
comptime HASH_HAY_BALE: UInt64 = 98
"""Base hash of `HayBale` (Go `hashHayBale`)."""
comptime HASH_HONEYCOMB: UInt64 = 99
"""Base hash of `Honeycomb` (Go `hashHoneycomb`)."""
comptime HASH_HOPPER: UInt64 = 100
"""Base hash of `Hopper` (Go `hashHopper`)."""
comptime HASH_ICE: UInt64 = 101
"""Base hash of `Ice` (Go `hashIce`)."""
comptime HASH_INFESTED_COBBLESTONE: UInt64 = 102
"""Base hash of `InfestedCobblestone` (Go `hashInfestedCobblestone`)."""
comptime HASH_INFESTED_DEEPSLATE: UInt64 = 103
"""Base hash of `InfestedDeepslate` (Go `hashInfestedDeepslate`)."""
comptime HASH_INFESTED_STONE: UInt64 = 104
"""Base hash of `InfestedStone` (Go `hashInfestedStone`)."""
comptime HASH_INFESTED_STONE_BRICKS: UInt64 = 105
"""Base hash of `InfestedStoneBricks` (Go `hashInfestedStoneBricks`)."""
comptime HASH_INVISIBLE_BEDROCK: UInt64 = 106
"""Base hash of `InvisibleBedrock` (Go `hashInvisibleBedrock`)."""
comptime HASH_IRON: UInt64 = 107
"""Base hash of `Iron` (Go `hashIron`)."""
comptime HASH_IRON_BARS: UInt64 = 108
"""Base hash of `IronBars` (Go `hashIronBars`)."""
comptime HASH_IRON_CHAIN: UInt64 = 109
"""Base hash of `IronChain` (Go `hashIronChain`)."""
comptime HASH_IRON_ORE: UInt64 = 110
"""Base hash of `IronOre` (Go `hashIronOre`)."""
comptime HASH_ITEM_FRAME: UInt64 = 111
"""Base hash of `ItemFrame` (Go `hashItemFrame`)."""
comptime HASH_JUKEBOX: UInt64 = 112
"""Base hash of `Jukebox` (Go `hashJukebox`)."""
comptime HASH_KELP: UInt64 = 113
"""Base hash of `Kelp` (Go `hashKelp`)."""
comptime HASH_LADDER: UInt64 = 114
"""Base hash of `Ladder` (Go `hashLadder`)."""
comptime HASH_LANTERN: UInt64 = 115
"""Base hash of `Lantern` (Go `hashLantern`)."""
comptime HASH_LAPIS: UInt64 = 116
"""Base hash of `Lapis` (Go `hashLapis`)."""
comptime HASH_LAPIS_ORE: UInt64 = 117
"""Base hash of `LapisOre` (Go `hashLapisOre`)."""
comptime HASH_LAVA: UInt64 = 118
"""Base hash of `Lava` (Go `hashLava`)."""
comptime HASH_LEAVES: UInt64 = 119
"""Base hash of `Leaves` (Go `hashLeaves`)."""
comptime HASH_LECTERN: UInt64 = 120
"""Base hash of `Lectern` (Go `hashLectern`)."""
comptime HASH_LEVER: UInt64 = 121
"""Base hash of `Lever` (Go `hashLever`)."""
comptime HASH_LIGHT: UInt64 = 122
"""Base hash of `Light` (Go `hashLight`)."""
comptime HASH_LILY_PAD: UInt64 = 123
"""Base hash of `LilyPad` (Go `hashLilyPad`)."""
comptime HASH_LIT_PUMPKIN: UInt64 = 124
"""Base hash of `LitPumpkin` (Go `hashLitPumpkin`)."""
comptime HASH_LOG: UInt64 = 125
"""Base hash of `Log` (Go `hashLog`)."""
comptime HASH_LOOM: UInt64 = 126
"""Base hash of `Loom` (Go `hashLoom`)."""
comptime HASH_MAGMA: UInt64 = 127
"""Base hash of `Magma` (Go `hashMagma`)."""
comptime HASH_MELON: UInt64 = 128
"""Base hash of `Melon` (Go `hashMelon`)."""
comptime HASH_MELON_SEEDS: UInt64 = 129
"""Base hash of `MelonSeeds` (Go `hashMelonSeeds`)."""
comptime HASH_MOSS_CARPET: UInt64 = 130
"""Base hash of `MossCarpet` (Go `hashMossCarpet`)."""
comptime HASH_MUD: UInt64 = 131
"""Base hash of `Mud` (Go `hashMud`)."""
comptime HASH_MUD_BRICKS: UInt64 = 132
"""Base hash of `MudBricks` (Go `hashMudBricks`)."""
comptime HASH_MUDDY_MANGROVE_ROOTS: UInt64 = 133
"""Base hash of `MuddyMangroveRoots` (Go `hashMuddyMangroveRoots`)."""
comptime HASH_MYCELIUM: UInt64 = 134
"""Base hash of `Mycelium` (Go `hashMycelium`)."""
comptime HASH_NETHER_BRICK_FENCE: UInt64 = 135
"""Base hash of `NetherBrickFence` (Go `hashNetherBrickFence`)."""
comptime HASH_NETHER_BRICKS: UInt64 = 136
"""Base hash of `NetherBricks` (Go `hashNetherBricks`)."""
comptime HASH_NETHER_GOLD_ORE: UInt64 = 137
"""Base hash of `NetherGoldOre` (Go `hashNetherGoldOre`)."""
comptime HASH_NETHER_QUARTZ_ORE: UInt64 = 138
"""Base hash of `NetherQuartzOre` (Go `hashNetherQuartzOre`)."""
comptime HASH_NETHER_SPROUTS: UInt64 = 139
"""Base hash of `NetherSprouts` (Go `hashNetherSprouts`)."""
comptime HASH_NETHER_WART: UInt64 = 140
"""Base hash of `NetherWart` (Go `hashNetherWart`)."""
comptime HASH_NETHER_WART_BLOCK: UInt64 = 141
"""Base hash of `NetherWartBlock` (Go `hashNetherWartBlock`)."""
comptime HASH_NETHERITE: UInt64 = 142
"""Base hash of `Netherite` (Go `hashNetherite`)."""
comptime HASH_NETHERRACK: UInt64 = 143
"""Base hash of `Netherrack` (Go `hashNetherrack`)."""
comptime HASH_NOTE: UInt64 = 144
"""Base hash of `Note` (Go `hashNote`)."""
comptime HASH_OBSIDIAN: UInt64 = 145
"""Base hash of `Obsidian` (Go `hashObsidian`)."""
comptime HASH_PACKED_ICE: UInt64 = 146
"""Base hash of `PackedIce` (Go `hashPackedIce`)."""
comptime HASH_PACKED_MUD: UInt64 = 147
"""Base hash of `PackedMud` (Go `hashPackedMud`)."""
comptime HASH_PINK_PETALS: UInt64 = 148
"""Base hash of `PinkPetals` (Go `hashPinkPetals`)."""
comptime HASH_PLANKS: UInt64 = 149
"""Base hash of `Planks` (Go `hashPlanks`)."""
comptime HASH_PODZOL: UInt64 = 150
"""Base hash of `Podzol` (Go `hashPodzol`)."""
comptime HASH_POLISHED_BLACKSTONE_BRICK: UInt64 = 151
"""Base hash of `PolishedBlackstoneBrick` (Go `hashPolishedBlackstoneBrick`)."""
comptime HASH_POLISHED_CINNABAR: UInt64 = 152
"""Base hash of `PolishedCinnabar` (Go `hashPolishedCinnabar`)."""
comptime HASH_POLISHED_SULFUR: UInt64 = 153
"""Base hash of `PolishedSulfur` (Go `hashPolishedSulfur`)."""
comptime HASH_POLISHED_TUFF: UInt64 = 154
"""Base hash of `PolishedTuff` (Go `hashPolishedTuff`)."""
comptime HASH_PORTAL: UInt64 = 155
"""Base hash of `Portal` (Go `hashPortal`)."""
comptime HASH_POTATO: UInt64 = 156
"""Base hash of `Potato` (Go `hashPotato`)."""
comptime HASH_PRISMARINE: UInt64 = 157
"""Base hash of `Prismarine` (Go `hashPrismarine`)."""
comptime HASH_PUMPKIN: UInt64 = 158
"""Base hash of `Pumpkin` (Go `hashPumpkin`)."""
comptime HASH_PUMPKIN_SEEDS: UInt64 = 159
"""Base hash of `PumpkinSeeds` (Go `hashPumpkinSeeds`)."""
comptime HASH_PURPUR: UInt64 = 160
"""Base hash of `Purpur` (Go `hashPurpur`)."""
comptime HASH_PURPUR_PILLAR: UInt64 = 161
"""Base hash of `PurpurPillar` (Go `hashPurpurPillar`)."""
comptime HASH_QUARTZ: UInt64 = 162
"""Base hash of `Quartz` (Go `hashQuartz`)."""
comptime HASH_QUARTZ_BRICKS: UInt64 = 163
"""Base hash of `QuartzBricks` (Go `hashQuartzBricks`)."""
comptime HASH_QUARTZ_PILLAR: UInt64 = 164
"""Base hash of `QuartzPillar` (Go `hashQuartzPillar`)."""
comptime HASH_RAW_COPPER: UInt64 = 165
"""Base hash of `RawCopper` (Go `hashRawCopper`)."""
comptime HASH_RAW_GOLD: UInt64 = 166
"""Base hash of `RawGold` (Go `hashRawGold`)."""
comptime HASH_RAW_IRON: UInt64 = 167
"""Base hash of `RawIron` (Go `hashRawIron`)."""
comptime HASH_RED_SHRUB: UInt64 = 168
"""Base hash of `RedShrub` (Go `hashRedShrub`)."""
comptime HASH_REDSTONE_BLOCK: UInt64 = 169
"""Base hash of `RedstoneBlock` (Go `hashRedstoneBlock`)."""
comptime HASH_REDSTONE_ORE: UInt64 = 170
"""Base hash of `RedstoneOre` (Go `hashRedstoneOre`)."""
comptime HASH_REDSTONE_TORCH: UInt64 = 171
"""Base hash of `RedstoneTorch` (Go `hashRedstoneTorch`)."""
comptime HASH_REDSTONE_WIRE: UInt64 = 172
"""Base hash of `RedstoneWire` (Go `hashRedstoneWire`)."""
comptime HASH_REINFORCED_DEEPSLATE: UInt64 = 173
"""Base hash of `ReinforcedDeepslate` (Go `hashReinforcedDeepslate`)."""
comptime HASH_RESIN: UInt64 = 174
"""Base hash of `Resin` (Go `hashResin`)."""
comptime HASH_RESIN_BRICKS: UInt64 = 175
"""Base hash of `ResinBricks` (Go `hashResinBricks`)."""
comptime HASH_SAND: UInt64 = 176
"""Base hash of `Sand` (Go `hashSand`)."""
comptime HASH_SANDSTONE: UInt64 = 177
"""Base hash of `Sandstone` (Go `hashSandstone`)."""
comptime HASH_SAPLING: UInt64 = 178
"""Base hash of `Sapling` (Go `hashSapling`)."""
comptime HASH_SEA_LANTERN: UInt64 = 179
"""Base hash of `SeaLantern` (Go `hashSeaLantern`)."""
comptime HASH_SEA_PICKLE: UInt64 = 180
"""Base hash of `SeaPickle` (Go `hashSeaPickle`)."""
comptime HASH_SHELF_MUSHROOM: UInt64 = 181
"""Base hash of `ShelfMushroom` (Go `hashShelfMushroom`)."""
comptime HASH_SHORT_GRASS: UInt64 = 182
"""Base hash of `ShortGrass` (Go `hashShortGrass`)."""
comptime HASH_SHROOMLIGHT: UInt64 = 183
"""Base hash of `Shroomlight` (Go `hashShroomlight`)."""
comptime HASH_SHULKER_BOX: UInt64 = 184
"""Base hash of `ShulkerBox` (Go `hashShulkerBox`)."""
comptime HASH_SIGN: UInt64 = 185
"""Base hash of `Sign` (Go `hashSign`)."""
comptime HASH_SKULL: UInt64 = 186
"""Base hash of `Skull` (Go `hashSkull`)."""
comptime HASH_SLAB: UInt64 = 187
"""Base hash of `Slab` (Go `hashSlab`)."""
comptime HASH_SLIME: UInt64 = 188
"""Base hash of `Slime` (Go `hashSlime`)."""
comptime HASH_SMITHING_TABLE: UInt64 = 189
"""Base hash of `SmithingTable` (Go `hashSmithingTable`)."""
comptime HASH_SMOKER: UInt64 = 190
"""Base hash of `Smoker` (Go `hashSmoker`)."""
comptime HASH_SMOOTH_BASALT: UInt64 = 191
"""Base hash of `SmoothBasalt` (Go `hashSmoothBasalt`)."""
comptime HASH_SNOW: UInt64 = 192
"""Base hash of `Snow` (Go `hashSnow`)."""
comptime HASH_SOUL_SAND: UInt64 = 193
"""Base hash of `SoulSand` (Go `hashSoulSand`)."""
comptime HASH_SOUL_SOIL: UInt64 = 194
"""Base hash of `SoulSoil` (Go `hashSoulSoil`)."""
comptime HASH_SPONGE: UInt64 = 195
"""Base hash of `Sponge` (Go `hashSponge`)."""
comptime HASH_SPORE_BLOSSOM: UInt64 = 196
"""Base hash of `SporeBlossom` (Go `hashSporeBlossom`)."""
comptime HASH_STAINED_GLASS: UInt64 = 197
"""Base hash of `StainedGlass` (Go `hashStainedGlass`)."""
comptime HASH_STAINED_GLASS_PANE: UInt64 = 198
"""Base hash of `StainedGlassPane` (Go `hashStainedGlassPane`)."""
comptime HASH_STAINED_TERRACOTTA: UInt64 = 199
"""Base hash of `StainedTerracotta` (Go `hashStainedTerracotta`)."""
comptime HASH_STAIRS: UInt64 = 200
"""Base hash of `Stairs` (Go `hashStairs`)."""
comptime HASH_STONE: UInt64 = 201
"""Base hash of `Stone` (Go `hashStone`)."""
comptime HASH_STONE_BRICKS: UInt64 = 202
"""Base hash of `StoneBricks` (Go `hashStoneBricks`)."""
comptime HASH_STONECUTTER: UInt64 = 203
"""Base hash of `Stonecutter` (Go `hashStonecutter`)."""
comptime HASH_STRAW_BED: UInt64 = 204
"""Base hash of `StrawBed` (Go `hashStrawBed`)."""
comptime HASH_STRING: UInt64 = 205
"""Base hash of `String` (Go `hashString`)."""
comptime HASH_SUGAR_CANE: UInt64 = 206
"""Base hash of `SugarCane` (Go `hashSugarCane`)."""
comptime HASH_SULFUR: UInt64 = 207
"""Base hash of `Sulfur` (Go `hashSulfur`)."""
comptime HASH_SULFUR_BRICKS: UInt64 = 208
"""Base hash of `SulfurBricks` (Go `hashSulfurBricks`)."""
comptime HASH_TNT: UInt64 = 209
"""Base hash of `TNT` (Go `hashTNT`)."""
comptime HASH_TERRACOTTA: UInt64 = 210
"""Base hash of `Terracotta` (Go `hashTerracotta`)."""
comptime HASH_TINTED_GLASS: UInt64 = 211
"""Base hash of `TintedGlass` (Go `hashTintedGlass`)."""
comptime HASH_TORCH: UInt64 = 212
"""Base hash of `Torch` (Go `hashTorch`)."""
comptime HASH_TUFF: UInt64 = 213
"""Base hash of `Tuff` (Go `hashTuff`)."""
comptime HASH_TUFF_BRICKS: UInt64 = 214
"""Base hash of `TuffBricks` (Go `hashTuffBricks`)."""
comptime HASH_VINES: UInt64 = 215
"""Base hash of `Vines` (Go `hashVines`)."""
comptime HASH_WALL: UInt64 = 216
"""Base hash of `Wall` (Go `hashWall`)."""
comptime HASH_WATER: UInt64 = 217
"""Base hash of `Water` (Go `hashWater`)."""
comptime HASH_WHEAT_SEEDS: UInt64 = 218
"""Base hash of `WheatSeeds` (Go `hashWheatSeeds`)."""
comptime HASH_WOOD: UInt64 = 219
"""Base hash of `Wood` (Go `hashWood`)."""
comptime HASH_WOOD_DOOR: UInt64 = 220
"""Base hash of `WoodDoor` (Go `hashWoodDoor`)."""
comptime HASH_WOOD_FENCE: UInt64 = 221
"""Base hash of `WoodFence` (Go `hashWoodFence`)."""
comptime HASH_WOOD_FENCE_GATE: UInt64 = 222
"""Base hash of `WoodFenceGate` (Go `hashWoodFenceGate`)."""
comptime HASH_WOOD_TRAPDOOR: UInt64 = 223
"""Base hash of `WoodTrapdoor` (Go `hashWoodTrapdoor`)."""
comptime HASH_WOOL: UInt64 = 224
"""Base hash of `Wool` (Go `hashWool`)."""
comptime HASH_CUSTOM_BLOCK_BASE: UInt64 = 225
"""The first base hash after the vanilla ones (Go `hashCustomBlockBase`)."""


@fieldwise_init
struct AnyBlock(Equatable, ImplicitlyCopyable, Writable):
    """A block of any type, held as the two values of its Go `Hash()`.

    Blocks that hold another block (Go `Slab{Block: Planks{}}`) store it this
    way: unlike a runtime ID it needs no registry, and `get` rebuilds the
    typed value.
    """

    var kind: UInt64
    """The `BASE_HASH` of the block's type."""
    var state: UInt64
    """The block's `hash()`."""

    def __init__[T: Block](out self, b: T):
        """Wraps a typed block.

        Parameters:
            T: The block type.

        Args:
            b: The block.
        """
        self.kind = T.BASE_HASH
        self.state = b.hash()

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are the same block in the same state.
        """
        return self.kind == other.kind and self.state == other.state

    def is_a[T: Block](self) -> Bool:
        """Reports whether the block is a `T` (Go `_, ok := b.(T)`).

        Parameters:
            T: The block type.

        Returns:
            True if the block has type `T`.
        """
        return self.kind == T.BASE_HASH

    def get[T: Block](self) -> Optional[T]:
        """Returns the block as a `T` (Go `b, ok := b.(T)`).

        Parameters:
            T: The block type.

        Returns:
            The block, or None if it has another type.
        """
        if self.kind != T.BASE_HASH:
            return None
        return T.from_hash(self.state)

    def write_to(self, mut writer: Some[Writer]):
        """Writes the block as `kind:state`.

        Args:
            writer: The destination.
        """
        writer.write(self.kind, ":", self.state)


def hash_block(b: AnyBlock) -> UInt64:
    """Packs a block's type and state into 32 bits (Go `hashBlock`). The
    wrapped blocks of slabs, stairs and walls all fit in 16 bits each.

    Args:
        b: The block.

    Returns:
        `kind | state << 16`.
    """
    debug_assert(b.kind <= 0xFFFF and b.state <= 0xFFFF, "hash too large")
    return b.kind | (b.state << 16)


def unhash_block(h: UInt64) -> AnyBlock:
    """Unpacks a block packed with `hash_block`.

    Args:
        h: The packed value; only the low 32 bits are read.

    Returns:
        The block.
    """
    return AnyBlock(kind=h & 0xFFFF, state=(h >> 16) & 0xFFFF)
