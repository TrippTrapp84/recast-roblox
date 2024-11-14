if false then return end

local navMesh = require(script.Parent.Parent["recast-roblox"]["nav-mesh"])
-- local gizmo = require(script.Parent.Parent.packages.gizmo)

local mesh = navMesh.fromParts(workspace.Parts:GetChildren(),{
    heightFieldCellHeight = 0.2,
    heightFieldCellSize = 0.5,
    walkableStepHeight = 10,
    walkableHeight = 20,
    walkableSlope = math.rad(60),
})

mesh:filterLowHangingWalkableObstacles()
mesh:filterLedgeSpans()
mesh:filterWalkableLowHeightSpans()

mesh:buildCompactHeightField()

local tempBlock = Instance.new("Part")
tempBlock.Anchored = true
tempBlock.CFrame = CFrame.new()
tempBlock.Color = Color3.new(1,1,1)

local spanBlocks: {{
    span: typeof(mesh.compactHeightField.spans[1]),
    block: Part,
    x: number,
    z: number
}} = table.create(1000)

local compactHeightfield = mesh.compactHeightField

for x = 0, compactHeightfield.heightFieldSize.X - 1 do
    for z = 0, compactHeightfield.heightFieldSize.Z - 1 do
        local cellIndex = x + z * compactHeightfield.heightFieldSize.X + 1

        local cell = compactHeightfield.cells[cellIndex]

        for spanIndex = cell.index, cell.index + cell.count - 1 do
            local span = compactHeightfield.spans[spanIndex]
            local block = tempBlock:Clone()

            local clampedHeight = math.min(span.height,100)

            block.Position = Vector3.new(
                mesh.heightField.boundLow.X + x * mesh.config.heightFieldCellSize,
                mesh.heightField.boundLow.Y + mesh.config.heightFieldCellHeight * (span.min + (clampedHeight)/2),
                mesh.heightField.boundLow.Z + z * mesh.config.heightFieldCellSize
            )

            block.Color = Color3.new(1,0.5,0)

            block.Size = Vector3.new(
                mesh.config.heightFieldCellSize,
                clampedHeight * mesh.config.heightFieldCellHeight,
                mesh.config.heightFieldCellSize
            )

            block.Parent = workspace

            table.insert(spanBlocks,{
                block = block,
                span = span,
                x = x,
                z = z
            })
        end
    end
end
