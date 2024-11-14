local Root = script.Parent
local Util = Root.util
local Geometry = require(Util.geometry)
local Filters = require(Root["heightfield-filters"])
local HeightField = require(Root["heightfield"])
local Types = require(Root.types)

local NavigationMesh = {}
NavigationMesh.__index = NavigationMesh

type NavigationMesh = Types.NavigationMesh
type NavigationMeshConfig = Types.NavigationMeshConfig
type HeightFieldSpan = Types.HeightFieldSpan

function NavigationMesh.new(config: NavigationMeshConfig?): NavigationMesh
    local self = (setmetatable({}, NavigationMesh) :: never) :: NavigationMesh


    self.heightField = HeightField.new()

    self.config = if config then table.clone(config) else {
        walkableSlope = math.rad((89)),
        heightFieldCellHeight = 0.2,
        heightFieldCellSize = 10,
        walkableStepHeight = 1,
        agentRadius = 1,
        walkableHeight = 5,
    }

    self.compactHeightField = {
        heightFieldSize = Vector3.zero,
        boundHigh = Vector3.zero,
        boundLow = Vector3.zero,
        maxRegions = 0,
        spanCount = 0,
        cells = {},
        spans = {},
        areas = {},
    }

    self.walkableThreshold = math.cos(self.config.walkableSlope);

    return self
end

function NavigationMesh.fromParts(parts: {BasePart}, config: NavigationMeshConfig?): NavigationMesh
    local self = NavigationMesh.new(config);

    local vertices, indices = Geometry.unwrap(parts)

    self.heightField:calculateBounds(vertices, indices, self.config.heightFieldCellSize)

    self.heightField:markWalkableTriangles(vertices, indices, self.walkableThreshold)

    self.heightField:rasterizeTriangles(vertices, indices, self.config.heightFieldCellSize, self.config.heightFieldCellHeight, self.config.walkableStepHeight)

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

function NavigationMesh:filterLowHangingWalkableObstacles()
    Filters.filterLowHangingWalkableObstacles(self)
end
function NavigationMesh:filterLedgeSpans()
    Filters.filterLedgeSpans(self)
end
function NavigationMesh:filterWalkableLowHeightSpans()
    Filters.filterWalkableLowHeightSpans(self)
end

function NavigationMesh:buildCompactHeightField()
    local self = self :: NavigationMesh
    
    self.compactHeightField = self.heightField:compactHeightField(self.config.walkableHeight, self.config.walkableStepHeight)
end

return (table.freeze(NavigationMesh) :: never) :: {
    new: (config: NavigationMeshConfig?) -> NavigationMesh,
    fromParts: (parts: {BasePart}, config: NavigationMeshConfig?) -> NavigationMesh
}