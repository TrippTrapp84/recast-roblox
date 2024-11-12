local recast = require(script.Parent.Parent["recast-roblox"])
local geometry = require(script.Parent.Parent["recast-roblox"].util.geometry)
-- local gizmo = require(game.ReplicatedStorage.gizmo)

local sphere = Instance.new("Part")
sphere.Size = Vector3.one * 10
sphere.Position = Vector3.new(0,20,0)
sphere.Shape = Enum.PartType.Ball
local spherePoints,sphereInds = geometry.unwrapSphere(sphere)

for i = 1,#sphereInds // 3 do
    local index = i * 3 - 2

    local p1 = spherePoints[sphereInds[index]]
    local p2 = spherePoints[sphereInds[index + 1]]
    local p3 = spherePoints[sphereInds[index + 2]]

    local w1, w2 = geometry.generateTriangle(p1,p2,p3)

    w1.Parent = workspace
    w2.Parent = workspace

    w1.Transparency = 0
    w2.Transparency = 0

    local color = Color3.new(math.random(),math.random(),math.random())
    w1.Color = color
    w2.Color = color
end

-- while task.wait() do
--     for i,v in pairs(spherePoints) do
--         gizmo.drawSphere(CFrame.new(v),0.5)
--     end
-- end
