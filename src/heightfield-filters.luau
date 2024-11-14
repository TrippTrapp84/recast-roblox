local Types = require(script.Parent.types)

local AreaId = Types.AreaId

local Filters = {}

type NavigationMesh = Types.NavigationMesh
type HeightFieldSpan = Types.HeightFieldSpan

function Filters.filterLowHangingWalkableObstacles(navMesh: NavigationMesh)
    local heightField = navMesh.heightField
    
    local rowSize = heightField.heightFieldSize.X
    local walkableStepHeight = navMesh.config.walkableStepHeight
    
    for z = 0,heightField.heightFieldSize.Z-1 do
        --// We normally have to do +1 to our indicies to make the math for these work out since recast is in C++ originally,
        --// but instead I have x starting and ending 1 later to compensate.
        for x = 1,heightField.heightFieldSize.X do
            local previousSpan: HeightFieldSpan? = heightField.spans[x + z * rowSize]
            if not previousSpan then continue end

            local currentSpan = previousSpan.next

            local previousWalkable = false

            while currentSpan do
                local walkable = currentSpan.areaId ~= AreaId.Null

                if (not walkable) and previousWalkable and (currentSpan.max - previousSpan.max < walkableStepHeight) then
                    currentSpan.areaId = previousSpan.areaId
                end

                previousWalkable = walkable
                
                previousSpan = currentSpan
                currentSpan = currentSpan.next
            end
        end
    end
end

function Filters.filterLedgeSpans(navMesh: NavigationMesh)
    local heightField = navMesh.heightField

    local hSize = heightField.heightFieldSize
    local walkableStepHeight = navMesh.config.walkableStepHeight / navMesh.config.heightFieldCellHeight

    for z = 0,hSize.Z-1 do
        for x = 0, hSize.X do
            local currentSpan = heightField.spans[x + z * hSize.X + 1]

            while currentSpan do
                if currentSpan.areaId == AreaId.Null then
                    currentSpan = currentSpan.next
                    continue
                end

                local floor = currentSpan.max
                local ceiling = math.huge
                if currentSpan.next then
                    ceiling = currentSpan.next.min
                end

                local lowestNeighborFloorDifference = math.huge
                local lowestTraversableNeighborFloor = currentSpan.max
                local highestTraversableNeighborFloor = currentSpan.max

                for direction = 1,4 do
                    local neighborX = x + Types.DirectionX[direction]
                    local neighborZ = z + Types.DirectionY[direction]

                    if neighborX < 0 or  neighborZ < 0 or neighborX >= hSize.X or neighborZ >= hSize.Z then
                        lowestNeighborFloorDifference = -walkableStepHeight - 1
                        break
                    end

                    local neighborSpan = heightField.spans[neighborX + neighborZ * hSize.X + 1]
                    if not neighborSpan then
                        lowestNeighborFloorDifference = -walkableStepHeight - 1
                        break
                    end

                    local neighborCeiling = neighborSpan.min

                    if math.min(ceiling, neighborCeiling) - floor > walkableStepHeight then
                        lowestNeighborFloorDifference = -walkableStepHeight - 1
                        break
                    end

                    while neighborSpan do
                        local nextNeighborSpan = neighborSpan.next

                        local neighborFloor = neighborSpan.max
                        neighborCeiling = if nextNeighborSpan then nextNeighborSpan.min else math.huge

                        if math.min(ceiling, neighborCeiling) - math.max(floor, neighborFloor) < walkableStepHeight then
                            neighborSpan = neighborSpan.next
                            continue
                        end

                        local neighborFloorDistance = neighborFloor - floor
                        lowestNeighborFloorDifference = math.min(lowestNeighborFloorDifference, neighborFloorDistance)

                        if math.abs(neighborFloorDistance) <= walkableStepHeight then
                            lowestTraversableNeighborFloor = math.min(lowestTraversableNeighborFloor, neighborFloor)
                            highestTraversableNeighborFloor = math.min(highestTraversableNeighborFloor, neighborFloor)
                        elseif neighborFloorDistance < -walkableStepHeight then
                            break
                        end

                        neighborSpan = neighborSpan.next
                    end
                end

                if lowestNeighborFloorDifference < -walkableStepHeight then
                    currentSpan.areaId = AreaId.Null
                elseif highestTraversableNeighborFloor - lowestTraversableNeighborFloor > walkableStepHeight then
                    currentSpan.areaId = AreaId.Null
                end
                
                currentSpan = currentSpan.next
            end
        end
    end
end

function Filters.filterWalkableLowHeightSpans(navMesh: NavigationMesh)
    local heightField = navMesh.heightField

    local hSize = heightField.heightFieldSize
    local walkableHeight = navMesh.config.walkableHeight / navMesh.config.heightFieldCellHeight

    for z = 0, hSize.Z - 1 do
        for x = 0, hSize.Z - 1 do
            local currentSpan = heightField.spans[x + z * hSize.X + 1]

            while currentSpan do
                local nextSpan = currentSpan.next
                if not nextSpan then
                    currentSpan = currentSpan.next
                    continue
                end

                if nextSpan.min - currentSpan.max < walkableHeight then
                    currentSpan.areaId = AreaId.Null
                end

                currentSpan = currentSpan.next
            end
        end
    end
end

return Filters