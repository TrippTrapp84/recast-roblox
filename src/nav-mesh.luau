local Root = script.Parent
local Util = Root.util
local Geometry = require(Util.geometry)
local Types = require(Root.types)

local NavigationMesh = {}
NavigationMesh.__index = NavigationMesh

export type AreaId = number
local AreaId = {
    Walkable = 63
}

export type HeightFieldSpan = {
    min: number,
    max: number,
    id: number,
}

export type NavigationMesh = {
    heightField: {{HeightFieldSpan}},
    triAreaIds: {AreaId},

    boundHigh: Vector3,
    boundLow: Vector3,
    heightFieldSize: Vector2,

    config: NavigationMeshConfig,
    walkableThreshold: number,

    calculateBounds: (self: NavigationMesh, vertices: Types.VertexArray, indices: Types.IndexArray) -> (),
    markWalkableTriangles: (self: NavigationMesh, vertices: Types.VertexArray, indices: Types.IndexArray) -> (),
    clearWalkableTriangles: (self: NavigationMesh) -> (),
    rasterizeTriangles: (self: NavigationMesh, vertices: Types.VertexArray, indices: Types.IndexArray) -> (),
    rasterizeTriangle: (self : NavigationMesh, p0: Vector3, p1: Vector3, p2: Vector3, areaId: AreaId) -> (),
}
export type NavigationMeshConfig = {
    walkableSlope: number,
    heightFieldCellSize: number
}

function NavigationMesh.new(config: NavigationMeshConfig?): NavigationMesh
    local self = (setmetatable({}, NavigationMesh) :: never) :: NavigationMesh


    self.heightField = {}
    self.triAreaIds = {}
    self.boundHigh = Vector3.zero
    self.boundLow = Vector3.zero
    self.heightFieldSize = Vector2.zero

    self.config = if config then table.clone(config) else {
        walkableSlope = math.rad((89)),
        heightFieldCellSize = 10
    }

    self.walkableThreshold = math.cos(self.config.walkableSlope);

    return self
end

function NavigationMesh.fromParts(parts: {BasePart}, config: NavigationMeshConfig?): NavigationMesh
    local self = NavigationMesh.new(config);

    local vertices, indices = Geometry.unwrap(parts)

    self:calculateBounds(vertices, indices)

    self:markWalkableTriangles(vertices, indices)

    self:rasterizeTriangles(vertices, indices)

    --[[
        // Figure out how big the raster voxel grid will be based on the input geometry bounds.
        rcCalcGridSize
        
        // Voxelize the input geometry
        rcAllocHeightfield
        rcCreateHeightfield
        rcMarkWalkableTriangles
        rcRasterizeTriangles
        
        // Clean up the voxel data and filter out non-walkable areas.
        rcFilterLowHangingWalkableObstacles
        rcFilterLedgeSpans
        rcFilterWalkableLowHeightSpans
        
        // Consolidate the voxel data into a more compact representation
        rcAllocCompactHeightfield
        rcBuildCompactHeightfield
        
        // Further refine the voxel representation
        rcErodeWalkableArea
        rcBuildDistanceField
        rcBuildRegions
        
        // Triangulate the navmesh polygons from the voxel data
        rcAllocContourSet
        rcBuildContours
        rcAllocPolyMesh
        rcBuildPolyMesh
        
        // Package the mesh with additional metadata that's useful at runtime.
        rcAllocPolyMeshDetail
        rcBuildPolyMeshDetail
        
        // Cleanup
        rcFreeHeightField
        rcFreeCompactHeightfield
        rcFreeContourSet
    ]]

    return self
end

function NavigationMesh:rasterizeTriangles(vertices: Types.VertexArray, indices: Types.IndexArray)
    local self = self :: NavigationMesh

    for i = 1,math.floor(#indices / 3) do
        local vertIndex = i * 3 - 2
        self:rasterizeTriangle(
            vertices[vertIndex],
            vertices[vertIndex + 1],
            vertices[vertIndex + 2],
            self.triAreaIds[i]
        )
    end
end

function NavigationMesh:rasterizeTriangle(p1: Vector3, p2: Vector3, p3: Vector3, areaId: AreaId)
    local self = self :: NavigationMesh

    local cellSize = self.config.heightFieldCellSize
    local hSize = self.heightFieldSize
    local hBoundHigh = self.boundHigh
    local hBoundLow = self.boundLow

    local boundHigh, boundLow = Geometry.calcBounds({p1,p2,p3})

    if not Geometry.overlapBounds(boundHigh, boundLow, hBoundHigh, hBoundLow) then
        return
    end

    local zMin = math.clamp(math.floor((boundLow.Z - hBoundLow.Z) / cellSize),-1,hSize.Y-1);
	local zMax = math.clamp(math.floor((boundHigh.Z - hBoundLow.Z) / cellSize),0,hSize.Y-1);

    local currentTriangle = {p1,p2,p3}

    for z = zMin, zMax do
        local cellZ = hBoundLow.Z + z * cellSize
    end
end

function NavigationMesh:markWalkableTriangles(vertices: Types.VertexArray, indices: Types.IndexArray)
    local self = self :: NavigationMesh

    self:clearWalkableTriangles()
    
    --// We expect that the indices array's size is a multiple of 3, because we can't handle partial triangles
    self.triAreaIds = table.create(math.floor(#indices / 3), 0)

    for i = 1,math.floor(#indices / 3) do
        local vertIndex = (i) * 3 - 2

        local p1 = vertices[indices[vertIndex]]
        local p2 = vertices[indices[vertIndex + 1]]
        local p3 = vertices[indices[vertIndex + 2]]

        local normal = Geometry.calcTriNormal(p1, p2, p3)
        if normal.Y > self.walkableThreshold then
            self.triAreaIds[i] = AreaId.Walkable
        end
    end
end

function NavigationMesh:clearWalkableTriangles()
    local self = self :: NavigationMesh

    table.clear(self.triAreaIds)
end

function NavigationMesh:calculateBounds(vertices: Types.VertexArray, indices: Types.IndexArray)
    local self = self :: NavigationMesh

    self.boundHigh, self.boundLow = Geometry.calcBounds(vertices)

    self.heightFieldSize = Vector2.new(
        math.round((self.boundHigh.X - self.boundLow.X) / self.config.heightFieldCellSize),
        math.round((self.boundHigh.Z - self.boundLow.Z) / self.config.heightFieldCellSize)
    )
end

return NavigationMesh :: {
    new: (config: NavigationMeshConfig?) -> NavigationMesh
}