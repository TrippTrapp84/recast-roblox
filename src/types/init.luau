--[=[
   @class Types
]=]
local Types = {}

--[=[
   @type VertexArray {Vector3}
   @within Types

   An array of vertices, usually to be indexed using an `IndexArray`.
]=]
export type VertexArray = { Vector3 }

--[=[
   @type IndexArray {number}
   @within Types

   An array of indices, usually used to index a `VertexArray`.
]=]
export type IndexArray = { number }

--[=[
	@type AreaId number
	@within Types

	An enum identifier for the walkability of a surface.
]=]
export type AreaId = number
Types.AreaId = {
	Walkable = 63,
	Null = 0,
}

Types.DirectionX = {
	-1,
	0,
	1,
	0,
}
Types.DirectionY = {
	0,
	1,
	0,
	-1,
}

export type AxisId = "X" | "Y" | "Z"

export type HeightFieldSpan = {
	min: number,
	max: number,
	areaId: number,
	next: HeightFieldSpan?,
}

export type CompactCell = {
	index: number,
	count: number
}

export type CompactSpan = {
	min: number,
	height: number,
	region: number,
	neighbors: {[number]: number},
}

export type CompactHeightField = {
	spanCount: number,
	maxRegions: number,
	cells: { CompactCell },
	spans: { CompactSpan },
	areas: { AreaId },

	boundHigh: Vector3,
	boundLow: Vector3,
	heightFieldSize: Vector3,
}

export type HeightField = {
	triAreaIds: { AreaId },

	spans: { HeightFieldSpan? },
	boundHigh: Vector3,
	boundLow: Vector3,
	heightFieldSize: Vector3,

	calculateBounds: (self: HeightField, vertices: VertexArray, indices: IndexArray, cellSize: number) -> (),
	markWalkableTriangles: (
		self: HeightField,
		vertices: VertexArray,
		indices: IndexArray,
		walkableThreshold: number
	) -> (),
	clearWalkableTriangles: (self: HeightField) -> (),
	rasterizeTriangles: (
		self: HeightField,
		vertices: VertexArray,
		indices: IndexArray,
		cellSize: number,
		cellHeight: number,
		walkableStepHeight: number
	) -> (),
	rasterizeTriangle: (
		self: HeightField,
		p0: Vector3,
		p1: Vector3,
		p2: Vector3,
		areaId: AreaId,
		cellSize: number,
		cellHeight: number,
		walkableStepHeight: number
	) -> (),
	addSpan: (
		self: HeightField,
		x: number,
		z: number,
		spanMin: number,
		spanMax: number,
		areaId: AreaId,
		heightMergeThreshold: number
	) -> (),
	allocSpan: (self: HeightField, areaId: AreaId, max: number, min: number) -> HeightFieldSpan,
	freeSpan: (self: HeightField, span: HeightFieldSpan) -> (),
	countSpans: (self: HeightField) -> number,

	compactHeightField: (self: HeightField, walkableHeight: number, walkableClimb: number) -> CompactHeightField,
}

export type NavigationMesh = {
	heightField: HeightField,
	compactHeightField: CompactHeightField,

	config: NavigationMeshConfig,
	walkableThreshold: number,

	filterLowHangingWalkableObstacles: (self: NavigationMesh) -> (),
	filterLedgeSpans: (self: NavigationMesh) -> (),
	filterWalkableLowHeightSpans: (self: NavigationMesh) -> (),
	buildCompactHeightField: (self: NavigationMesh) -> (),
}

export type NavigationMeshConfig = {
	walkableSlope: number,
	heightFieldCellSize: number,
	heightFieldCellHeight: number,
	walkableStepHeight: number,
	walkableHeight: number,
}

export type CompactHeightFieldConfig = {
    spanCount: number,

    boundHigh: Vector3,
    boundLow: Vector3,
    heightFieldSize: Vector3,
}

return Types
