extends Node


enum Face {
	POS_X,
	NEG_X,
	POS_Y,
	NEG_Y,
	POS_Z,
	NEG_Z
}

enum BlockType {
	AIR,
	GRASS_V1,
	COBBLESTONE_V1,
	GRASS_V2,
	COBBLESTONE_V2,
	STONE_V1,
	PLANK_V1,
	DIRT_V1
}

const BLOCK_TILES := {
	BlockType.GRASS_V1: {
		Face.POS_Y: 0,
		Face.NEG_Y: 0,
		Face.POS_Z: 0,
		Face.NEG_Z: 0,
		Face.POS_X: 0,
		Face.NEG_X: 0
	},
	BlockType.COBBLESTONE_V1: {
		Face.POS_Y: 1,
		Face.NEG_Y: 1,
		Face.POS_Z: 1,
		Face.NEG_Z: 1,
		Face.POS_X: 1,
		Face.NEG_X: 1
	},
	BlockType.GRASS_V2: {
		Face.POS_Y: 6,
		Face.NEG_Y: 2,
		Face.POS_Z: 3,
		Face.NEG_Z: 3,
		Face.POS_X: 3,
		Face.NEG_X: 3
	},
	BlockType.COBBLESTONE_V2: {
		Face.POS_Y: 4,
		Face.NEG_Y: 4,
		Face.POS_Z: 4,
		Face.NEG_Z: 4,
		Face.POS_X: 4,
		Face.NEG_X: 4
	},
	BlockType.STONE_V1: {
		Face.POS_Y: 5,
		Face.NEG_Y: 5,
		Face.POS_Z: 5,
		Face.NEG_Z: 5,
		Face.POS_X: 5,
		Face.NEG_X: 5
	},
	BlockType.PLANK_V1: {
		Face.POS_Y: 7,
		Face.NEG_Y: 7,
		Face.POS_Z: 7,
		Face.NEG_Z: 7,
		Face.POS_X: 7,
		Face.NEG_X: 7
	},
	BlockType.DIRT_V1: {
		Face.POS_Y: 2,
		Face.NEG_Y: 2,
		Face.POS_Z: 2,
		Face.NEG_Z: 2,
		Face.POS_X: 2,
		Face.NEG_X: 2
	}
}
