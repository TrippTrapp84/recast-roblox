if true then return end

local navMesh = require(script.Parent.Parent["recast-roblox"]["nav-mesh"])
local geometry = require(script.Parent.Parent["recast-roblox"].util.geometry)
-- local gizmo = require(script.Parent.Parent.packages.gizmo)

local mesh = navMesh.new({
    heightFieldCellHeight = 0.2,
    heightFieldCellSize = 0.5,
    walkableStepHeight = 1,
    walkableHeight = 5,
    walkableSlope = math.rad(60),
})

local vertices, indices = geometry.unwrap(workspace.Parts:GetChildren())

mesh:calculateBounds(vertices, indices)

mesh:markWalkableTriangles(vertices, indices)

mesh:rasterizeTriangles(vertices, indices)

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

-- local camera = workspace.CurrentCamera

-- while task.wait() do
--     for i,v in pairs(spanBlocks) do
--         if not v.span then continue end
--         if (camera.CFrame.Position - v.block.Position - Vector3.new(0, v.block.Size.Y/2, 0)).Magnitude > 5 then continue end

--         gizmo.setScale(2)
--         gizmo.setColor(Color3.new(0,0,0))
--         gizmo.drawText(v.block.Position + Vector3.new(0,v.block.Size.Y/2,0),`({v.span.min}, {v.span.max}), ({v.x}, {v.z})`)
--     end
-- end



--// Some spare debug code I used to debug the nav-mesh divideOnGridAxis stuff.
--[[
    if numColumn > 2 then
        local color = Color3.new(math.random(),math.random(),math.random())
        local exactColumnPoly = table.create(numColumn)
        table.move(columnPolygon,1,numColumn,1,exactColumnPoly)
        for i,v in pairs(Geometry.generatePolygon(exactColumnPoly, Geometry.makeGuaranteedIndexArray(exactColumnPoly))) do
            for _,p in pairs({v.w1,v.w2}) do
                p.Parent = workspace
                p.Color = color
                p.Transparency = 0.5
            end
        end
    end
]]