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
	GRASS,
	DIRT,
	STONE,
	SNOW,
	WOOD,
	FOLIAGE,
	AIR
}

const BLOCK_TILES := {
	BlockType.GRASS: {
		Face.POS_Y: 3,
		Face.NEG_Y: 1,
		Face.POS_Z: 0,
		Face.NEG_Z: 0,
		Face.POS_X: 0,
		Face.NEG_X: 0
	},
	
	BlockType.DIRT: {
		Face.POS_Y: 1,
		Face.NEG_Y: 1,
		Face.POS_Z: 1,
		Face.NEG_Z: 1,
		Face.POS_X: 1,
		Face.NEG_X: 1
	},
	
	BlockType.STONE: {
		Face.POS_Y: 2,
		Face.NEG_Y: 2,
		Face.POS_Z: 2,
		Face.NEG_Z: 2,
		Face.POS_X: 2,
		Face.NEG_X: 2
	},
	
	BlockType.SNOW: {
		Face.POS_Y: 5,
		Face.NEG_Y: 1,
		Face.POS_Z: 4,
		Face.NEG_Z: 4,
		Face.POS_X: 4,
		Face.NEG_X: 4
	},
	
	BlockType.WOOD: {
		Face.POS_Y: 7,
		Face.NEG_Y: 7,
		Face.POS_Z: 6,
		Face.NEG_Z: 6,
		Face.POS_X: 6,
		Face.NEG_X: 6
	},
	
	BlockType.FOLIAGE: {
		Face.POS_Y: 8,
		Face.NEG_Y: 8,
		Face.POS_Z: 8,
		Face.NEG_Z: 8,
		Face.POS_X: 8,
		Face.NEG_X: 8
	}
}
