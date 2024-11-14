local Types = require(script.Parent.types)
local Geometry = require(script.Parent.util.geometry)
local CompactHeightField = require(script.Parent["compact-heightfield"])

type HeightField = Types.HeightField
type CompactHeightField = Types.CompactHeightField
type HeightFieldSpan = Types.HeightFieldSpan

type AreaId = Types.AreaId
local AreaId = Types.AreaId

local MAX_SPAN_HEIGHT = math.huge

--// This limit is probably a byproduct of the way the original C++ code used only 6 bits for the layer,
--// but I'm using full ints so this could probably be removed?
--// TODO: Test removing or increasing this layer limit.
local MAX_COMPACT_LAYERS = 63 - 1

local HeightField = {}
HeightField.__index = HeightField

function HeightField.new()
    local self = (setmetatable({}, HeightField) :: never) :: HeightField

    self.boundHigh = Vector3.zero
    self.boundLow = Vector3.zero
    self.heightFieldSize = Vector3.zero
    self.spans = {}
    self.triAreaIds = {}

    return self
end

function HeightField:rasterizeTriangles(vertices: Types.VertexArray, indices: Types.IndexArray, cellSize: number, cellHeight: number, walkableStepHeight: number)
    local self = self :: HeightField

    for i = 1,math.floor(#indices / 3) do
        local vertIndex = i * 3 - 2
        self:rasterizeTriangle(
            vertices[indices[vertIndex]],
            vertices[indices[vertIndex + 1]],
            vertices[indices[vertIndex + 2]],
            self.triAreaIds[i],
            cellSize,
            cellHeight,
            walkableStepHeight
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
    
    function HeightField:rasterizeTriangle(p1: Vector3, p2: Vector3, p3: Vector3, areaId: AreaId, cellSize: number, cellHeight: number, walkableStepHeight: number)
        local self = self :: HeightField
    
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
        currentTriangle[2] = p2
        currentTriangle[3] = p3

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
                
                self:addSpan(x,z,spanMinCellIndex,spanMaxCellIndex,areaId, walkableStepHeight)
            end
        end
    end
end

do
    local spanPool: {HeightFieldSpan} = (setmetatable(table.create(2^12), {__mode = "v"}) :: never) :: {HeightFieldSpan}

    function HeightField:allocSpan(areaId: AreaId, max: number, min: number): HeightFieldSpan
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

    function HeightField:freeSpan(span: HeightFieldSpan)
        table.insert(spanPool,span)
    end
end

function HeightField:addSpan(x: number, z: number, newSpanMin: number, newSpanMax: number, areaId: AreaId, heightMergeThreshold: number)
    local self = self :: HeightField
    
    local newSpan: HeightFieldSpan = { areaId = areaId,max = newSpanMax,min = newSpanMin}

    local columnIndex = x + z * self.heightFieldSize.X + 1
    local currentSpan: HeightFieldSpan? = self.spans[columnIndex]
    local previousSpan: HeightFieldSpan? = nil

    while currentSpan do
        if currentSpan.min > newSpan.max then break end

        if currentSpan.max < newSpan.min then
            previousSpan = currentSpan
            currentSpan = currentSpan.next

            continue
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
        -- self:freeSpan(currentSpan)

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

function HeightField:markWalkableTriangles(vertices: Types.VertexArray, indices: Types.IndexArray, walkableThreshold: number)
    local self = self :: HeightField

    self:clearWalkableTriangles()
    
    --// We expect that the indices array's size is a multiple of 3, because we can't handle partial triangles
    self.triAreaIds = table.create(math.floor(#indices / 3), 0)

    for i = 1,math.floor(#indices / 3) do
        local vertIndex = (i) * 3 - 2

        local p1 = vertices[indices[vertIndex]]
        local p2 = vertices[indices[vertIndex + 1]]
        local p3 = vertices[indices[vertIndex + 2]]

        local normal = Geometry.calcTriNormal(p1, p2, p3)
        if normal.Y > walkableThreshold then
            self.triAreaIds[i] = AreaId.Walkable
        end
    end
end

function HeightField:clearWalkableTriangles()
    local self = self :: HeightField

    table.clear(self.triAreaIds)
end

function HeightField:countSpans(): number
    local self = self :: HeightField
    
    local count = 0

    for column = 1,self.heightFieldSize.X * self.heightFieldSize.Z do
        local currentSpan = self.spans[column]

        while currentSpan do
            if currentSpan.areaId ~= AreaId.Null then
                count += 1
            end
            
            currentSpan = currentSpan.next
        end
    end

    return count
end

--[=[
    Constructs a `CompactHeightField` using the data of this `HeightField`.

    @return CompactHeightField
]=]
function HeightField:compactHeightField(walkableHeight: number, walkableClimb: number): CompactHeightField
    local self = self :: HeightField
    
    local spanCount = self:countSpans()
    local compactHeightfield = CompactHeightField.new({
        boundHigh = self.boundHigh,
        boundLow = self.boundLow,
        heightFieldSize = self.heightFieldSize,
        spanCount = spanCount
    })

    local xSize = self.heightFieldSize.X
    local zSize = self.heightFieldSize.Z

    local cellIndex = 1
    for column = 1, zSize * zSize do
        local currentSpan = self.spans[column]
        if not currentSpan then continue end

        local cell: Types.CompactCell = compactHeightfield.cells[column]
        cell.index = cellIndex

        while currentSpan do
            if currentSpan.areaId == AreaId.Null then
                currentSpan = currentSpan.next
                continue
            end

            --// Remember we're getting empty space here, so it's from the top of the lower span to the bottom of the upper span
            local bottom = currentSpan.max
            local top = if currentSpan.next then currentSpan.next.min else MAX_SPAN_HEIGHT

            local span = compactHeightfield.spans[cellIndex]
            span.min = math.clamp(bottom,0,MAX_SPAN_HEIGHT)
            span.height = math.clamp(top - bottom, 0, MAX_SPAN_HEIGHT)
            compactHeightfield.areas[cellIndex] = currentSpan.areaId

            cellIndex += 1
            cell.count += 1

            currentSpan = currentSpan.next
        end
    end

    local maxLayerIndex = 0
    for z = 0, zSize-1 do
        for x = 0, xSize-1 do
            local cell = compactHeightfield.cells[x + z * xSize + 1]

            for spanIndex = cell.index, cell.index + cell.count - 1 do
                local span = compactHeightfield.spans[spanIndex]

                for d = 1,4 do
                    --// TODO: figure out what this enum is supposed to represent and reorganize it
                    span.neighbors[d] = MAX_COMPACT_LAYERS + 1

                    local neighborX = x + Types.DirectionX[d]
                    local neighborZ = z + Types.DirectionY[d]

                    if neighborX < 0 or neighborX >= xSize or neighborZ < 0 or neighborZ >= zSize then
                        continue
                    end

                    local neighborCell = compactHeightfield.cells[neighborX + neighborZ * xSize + 1]
                    for neighborSpanIndex = neighborCell.index, neighborCell.index + neighborCell.count - 1 do
                        local neighborSpan = compactHeightfield.spans[neighborSpanIndex]
                        
                        local bottom = math.max(span.min, neighborSpan.min)
                        local top = math.max(span.min + span.height, neighborSpan.min + neighborSpan.height)

                        if (top - bottom) >= walkableHeight and math.abs(neighborSpan.min - span.min) >= walkableClimb then
                            local layerIndex = neighborSpanIndex - neighborCell.index
                            if layerIndex < 0 or layerIndex >= MAX_COMPACT_LAYERS then
                                maxLayerIndex = math.max(maxLayerIndex, layerIndex)
                                continue
                            end

                            span.neighbors[d] = layerIndex
                        end
                        
                    end
                    
                end
            end
        end
    end

    if maxLayerIndex > MAX_COMPACT_LAYERS then
        warn(`Recast: Heightfield has too many layers! (Found {maxLayerIndex} layers, maximum is {MAX_COMPACT_LAYERS})`)
    end

    return compactHeightfield
end

function HeightField:calculateBounds(vertices: Types.VertexArray, indices: Types.IndexArray, cellSize: number)
    local self = self :: HeightField

    self.boundHigh, self.boundLow = Geometry.calcBounds(vertices)

    -- self.boundHigh += Vector3.one * 5
    -- self.boundLow -= Vector3.one * 5

    self.heightFieldSize = Vector3.new(
        math.round((self.boundHigh.X - self.boundLow.X) / cellSize),
        0,
        math.round((self.boundHigh.Z - self.boundLow.Z) / cellSize)
    )
end

return HeightField :: {
    new: () -> HeightField
}