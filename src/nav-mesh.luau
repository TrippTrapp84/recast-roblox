local Root = script.Parent
local Util = Root.util
local Geometry = require(Util.geometry)
local Types = require(Root.types)

local NavigationMesh = {}
NavigationMesh.__index = NavigationMesh

export type AreaId = Types.AreaId
local AreaId = Types.AreaId

local MAX_SPAN_HEIGHT = math.huge

export type HeightFieldSpan = {
    min: number,
    max: number,
    areaId: number,
    next: HeightFieldSpan?
}

export type NavigationMesh = {
    heightField: {{HeightFieldSpan}},
    triAreaIds: {AreaId},

    spans: {HeightFieldSpan?},
    boundHigh: Vector3,
    boundLow: Vector3,
    heightFieldSize: Vector3,

    config: NavigationMeshConfig,
    walkableThreshold: number,

    calculateBounds: (self: NavigationMesh, vertices: Types.VertexArray, indices: Types.IndexArray) -> (),
    markWalkableTriangles: (self: NavigationMesh, vertices: Types.VertexArray, indices: Types.IndexArray) -> (),
    clearWalkableTriangles: (self: NavigationMesh) -> (),
    rasterizeTriangles: (self: NavigationMesh, vertices: Types.VertexArray, indices: Types.IndexArray) -> (),
    rasterizeTriangle: (self : NavigationMesh, p0: Vector3, p1: Vector3, p2: Vector3, areaId: AreaId) -> (),
    addSpan: (self: NavigationMesh, x: number, z: number, spanMin: number, spanMax: number, areaId: AreaId) -> (),
    allocSpan: (self: NavigationMesh, areaId: AreaId, max: number, min: number) -> HeightFieldSpan,
    freeSpan: (self: NavigationMesh, span: HeightFieldSpan) -> (),
}
export type NavigationMeshConfig = {
    walkableSlope: number,
    heightFieldCellSize: number,
    heightFieldCellHeight: number,
    walkableStepHeight: number,
    walkableHeight: number,
}

function NavigationMesh.new(config: NavigationMeshConfig?): NavigationMesh
    local self = (setmetatable({}, NavigationMesh) :: never) :: NavigationMesh


    self.heightField = {}
    self.triAreaIds = {}
    self.spans = {}
    self.boundHigh = Vector3.zero
    self.boundLow = Vector3.zero
    self.heightFieldSize = Vector3.zero

    self.config = if config then table.clone(config) else {
        walkableSlope = math.rad((89)),
        heightFieldCellSize = 10,
        heightFieldCellHeight = 0.2,
        walkableStepHeight = 1,
        walkableHeight = 5,
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
            vertices[indices[vertIndex]],
            vertices[indices[vertIndex + 1]],
            vertices[indices[vertIndex + 2]],
            self.triAreaIds[i]
        )
    end
end

do
    --// Define these up here to prevent as many allocations as possible
    local currentTriangle = table.create(21)
    local rowPolygon = table.create(21)
    local columnPolygon = table.create(21)
    local columnCutTemp = table.create(21)

    local boundsVertsList = table.create(3)
    
    function NavigationMesh:rasterizeTriangle(p1: Vector3, p2: Vector3, p3: Vector3, areaId: AreaId)
        local self = self :: NavigationMesh
    
        local cellSize, cellHeight = self.config.heightFieldCellSize, self.config.heightFieldCellHeight
        local hSize = self.heightFieldSize
        local boundLow = self.boundLow
        local boundHigh = self.boundHigh
    
        local hHeight = boundHigh.Y - boundLow.Y
    
        boundsVertsList[1] = p1
        boundsVertsList[2] = p2
        boundsVertsList[3] = p3
        local triBoundHigh, triBoundLow = Geometry.calcBounds(boundsVertsList)
    
        if not Geometry.overlapBounds(triBoundHigh, triBoundLow, boundHigh, boundLow) then
            return
        end
    
        local zMin = math.clamp(math.floor((triBoundLow.Z - boundLow.Z) / cellSize),-1,hSize.Z-1);
        local zMax = math.clamp(math.floor((triBoundHigh.Z - boundLow.Z) / cellSize),0,hSize.Z-1);
    
        local numCurrent = 3
        local numRow = 0
        local numColumn = 0
    
        currentTriangle[1] = p1
        currentTriangle[2] = p1
        currentTriangle[3] = p1

        for z = zMin, zMax do
            local cellZ = boundLow.Z + (z + 1) * cellSize
    
            numRow, numCurrent = Geometry.dividePolygonOnGridAxis(currentTriangle, numCurrent, "Z", cellZ, rowPolygon, columnPolygon)
    
            --// Use the outside polygons as the start for the next row instead. Swap to avoid multiple references.
            local _temp1 = currentTriangle; currentTriangle = columnPolygon; columnPolygon = _temp1
    
            if numRow < 3 then continue end
            if z < 0 then continue end
    
            local triMinX, triMaxX = math.huge, -math.huge
            for i = 1,numRow do
                local rowX = rowPolygon[i].X
                triMinX = math.min(rowX,triMinX)
                triMaxX = math.max(rowX,triMaxX)
            end
    
            local xMin = math.floor((triMinX - boundLow.X) / cellSize)
            local xMax = math.floor((triMaxX - boundLow.X) / cellSize)
            if xMax < 0 or xMin >= hSize.X then continue end
            
            xMin = math.clamp(xMin,-1,hSize.X-1);
            xMax = math.clamp(xMax,0,hSize.X-1);
    
            for x = xMin, xMax do
                local cellX = boundLow.X + (x + 1) * cellSize
    
                numColumn, numRow = Geometry.dividePolygonOnGridAxis(rowPolygon, numRow, "X", cellX, columnPolygon, columnCutTemp)
    
                --// Use the outside polygons as the start for the next column instead. Swap to avoid multiple references.
                local _temp2 = rowPolygon; rowPolygon = columnCutTemp; columnCutTemp = _temp2
    
                if numColumn < 3 then continue end
                if x < 0 then continue end
    
                local spanMin = math.huge
                local spanMax = -math.huge
                for i = 1, numColumn do
                    local spanY = columnPolygon[i].Y
                    spanMin = math.min(spanMin,spanY)
                    spanMax = math.max(spanMax,spanY)
                end
    
                spanMin -= boundLow.Y
                spanMax -= boundLow.Y
                
                if spanMax < 0 then continue end
                if spanMin > hHeight then continue end
                
                local spanMinCellIndex = math.clamp(math.floor(spanMin / cellHeight), 0, MAX_SPAN_HEIGHT)
                local spanMaxCellIndex = math.clamp(math.ceil(spanMax / cellHeight), spanMinCellIndex + 1, MAX_SPAN_HEIGHT)
                
                self:addSpan(x,z,spanMinCellIndex,spanMaxCellIndex,areaId)
            end
        end
    end
end

do
    local spanPool: {HeightFieldSpan} = (setmetatable(table.create(2^12), {__mode = "v"}) :: never) :: {HeightFieldSpan}

    function NavigationMesh:allocSpan(areaId: AreaId, max: number, min: number): HeightFieldSpan
        local span = table.remove(spanPool)
        if not span then
            return {
                areaId = areaId,
                max = max,
                min = min
            }
        end

        span.areaId = areaId
        span.max = max
        span.min = min

        return span
    end

    function NavigationMesh:freeSpan(span: HeightFieldSpan)
        table.insert(spanPool,span)
    end
end

function NavigationMesh:addSpan(x: number, z: number, newSpanMin: number, newSpanMax: number, areaId: AreaId)
    local self = self :: NavigationMesh

    local heightMergeThreshold = self.config.walkableStepHeight
    
    local newSpan: HeightFieldSpan = self:allocSpan(areaId,newSpanMax,newSpanMin)

    local columnIndex = x + z * self.heightFieldSize.X + 1
    local currentSpan: HeightFieldSpan? = self.spans[columnIndex]
    local previousSpan: HeightFieldSpan? = nil

    while currentSpan do
        if currentSpan.min > newSpan.max then break end

        if currentSpan.max < newSpan.min then
            previousSpan = currentSpan
            currentSpan = currentSpan.next

            break
        end

        if currentSpan.min < newSpan.min then
            newSpan.min = currentSpan.min
        end

        if currentSpan.max > newSpan.max then
            newSpan.max = currentSpan.max
        end

        if math.abs(newSpan.max - currentSpan.max) <= heightMergeThreshold then
            newSpan.areaId = math.max(newSpan.areaId, currentSpan.areaId)
        end

        --// TODO: Implement object pooling for spans, this is easily reusable memory. Right now we leave freeing to the gc and just construct new spans every time
        local nextSpan = currentSpan.next
        self:freeSpan(currentSpan)

        if previousSpan then
            previousSpan.next = nextSpan
        else
            self.spans[columnIndex] = nextSpan
        end

        currentSpan = nextSpan
    end

    if previousSpan then
        newSpan.next = previousSpan.next
        previousSpan.next = newSpan
    else
        newSpan.next = self.spans[columnIndex]
        self.spans[columnIndex] = newSpan
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

    -- self.boundHigh += Vector3.one * 5
    -- self.boundLow -= Vector3.one * 5

    self.heightFieldSize = Vector3.new(
        math.round((self.boundHigh.X - self.boundLow.X) / self.config.heightFieldCellSize),
        0,
        math.round((self.boundHigh.Z - self.boundLow.Z) / self.config.heightFieldCellSize)
    )
end

return (table.freeze(NavigationMesh) :: never) :: {
    new: (config: NavigationMeshConfig?) -> NavigationMesh
}