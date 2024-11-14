local Types = require(script.Parent.types)

type AreaID = Types.AreaId
local AreaId = Types.AreaId

type CompactHeightField = Types.CompactHeightField

local CompactHeightField = {}
CompactHeightField.__index = CompactHeightField

type CompactHeightFieldConfig = Types.CompactHeightFieldConfig

function CompactHeightField.new(config: CompactHeightFieldConfig): CompactHeightField
    local self = (setmetatable({}, CompactHeightField) :: never) :: CompactHeightField

    self.spanCount = config.spanCount
    self.boundHigh = config.boundHigh
    self.boundLow = config.boundLow
    self.heightFieldSize = config.heightFieldSize

    self.cells = table.create(self.heightFieldSize.X * self.heightFieldSize.Z)
    for i = 1,self.heightFieldSize.X * self.heightFieldSize.Z do
        self.cells[i] = {
            count = 0,
            index = 0
        }
    end

    self.spans = table.create(self.spanCount)
    for i = 1, self.spanCount do
        self.spans[i] = {
            height = 0,
            min = 0,
            neighbors = {},
            region = 0,
        }
    end

    self.areas = table.create(self.spanCount,AreaId.Null)

    return self
end

function CompactHeightField:erodeWalkableArea(erosionRadius: number)
    
end

return CompactHeightField