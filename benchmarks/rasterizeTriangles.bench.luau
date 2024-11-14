--!native
--!optimize 2

local ServerScriptService = game:GetService("ServerScriptService")

local RecastModule = ServerScriptService["recast-roblox"]
local Packages = ServerScriptService.packages

local navMesh = require(RecastModule["nav-mesh"])
local geometry = require(RecastModule.util.geometry)
local Benchmarker = require(Packages.benchmarker)

local mesh = navMesh.new({
    heightFieldCellHeight = 0.1,
    heightFieldCellSize = 0.5,
    walkableStepHeight = 1,
    walkableHeight = 5,
    walkableSlope = math.rad(60),
})

local Parts: {BasePart} = {
    (function()
        local part = Instance.new("Part")
        part.Size = Vector3.new(10,10,40)

        return part
    end)(),

    (function()
        local part = Instance.new("Part")
        part.Size = Vector3.new(10,10,40)
        part.Position = Vector3.new(100)

        return part
    end)(),

    (function()
        local part = Instance.new("Part")
        part.Size = Vector3.new(10,10,40)
        part.Position = Vector3.new(200)

        return part
    end)(),

    (function()
        local part = Instance.new("Part")
        part.Shape = Enum.PartType.Ball
        part.Size = Vector3.new(10,10,40)
        part.Position = Vector3.new(300)

        return part
    end)(),
}

local vertices, indices = geometry.unwrap(Parts)

mesh:calculateBounds(vertices, indices)

mesh:markWalkableTriangles(vertices, indices)

return {
	Functions = {
		Rasterization = function(Profiler: Benchmarker.Profiler)
            Profiler.Begin("rasterize")
            mesh:rasterizeTriangles(vertices, indices)
            Profiler.End()
        end,
	},
}
