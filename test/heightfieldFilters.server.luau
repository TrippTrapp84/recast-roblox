if false then return end

local navMesh = require(script.Parent.Parent["recast-roblox"]["nav-mesh"])
local geometry = require(script.Parent.Parent["recast-roblox"].util.geometry)

local mesh = navMesh.new({
    heightFieldCellHeight = 0.1,
    heightFieldCellSize = 0.5,
    walkableStepHeight = 10,
    walkableHeight = 20,
    walkableSlope = math.rad(60),
})

local vertices, indices = geometry.unwrap(workspace.Parts:GetChildren())

mesh:calculateBounds(vertices, indices)

mesh:markWalkableTriangles(vertices, indices)

mesh:rasterizeTriangles(vertices, indices)

mesh:filterLowHangingWalkableObstacles()
mesh:filterLedgeSpans()
mesh:filterWalkableLowHeightSpans()

local tempBlock = Instance.new("Part")
tempBlock.Anchored = true
tempBlock.CFrame = CFrame.new()
tempBlock.Color = Color3.new(1,1,1)

local spanBlocks: {{
    span: typeof(mesh.spans[1]),
    block: Part,
    x: number,
    z: number
}} = table.create(1000)

for i,v in pairs(mesh.spans) do
    local currentSpan = v

    local z = math.floor((i-1) / mesh.heightFieldSize.X)
    local x = i - z * mesh.heightFieldSize.X - 1

    while currentSpan do
        local block = tempBlock:Clone()

        block.Position = Vector3.new(
            mesh.boundLow.X + x * mesh.config.heightFieldCellSize,
            mesh.boundLow.Y + mesh.config.heightFieldCellHeight * (currentSpan.max - currentSpan.min)/2 + mesh.config.heightFieldCellHeight * currentSpan.min,
            mesh.boundLow.Z + z * mesh.config.heightFieldCellSize
        )

        block.Color = Color3.new(1 - currentSpan.areaId / 64,currentSpan.areaId / 64)

        block.Size = Vector3.new(
            mesh.config.heightFieldCellSize,
            (currentSpan.max - currentSpan.min) * mesh.config.heightFieldCellHeight,
            mesh.config.heightFieldCellSize
        )

        block.Name = `{x}, {z}`

        block.Parent = workspace

        table.insert(spanBlocks,{
            block = block,
            span = currentSpan,
            x = x,
            z = z
        })

        currentSpan = currentSpan.next
    end
end