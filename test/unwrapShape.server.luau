if true then return end

local geometry = require(script.Parent.Parent["recast-roblox"].util.geometry)
local gizmo = require(script.Parent.Parent.packages.gizmo)

local sphere = Instance.new("Part")
sphere.Size = Vector3.one * 10
sphere.Anchored = true
sphere.CFrame = CFrame.Angles(math.random(),math.random(),math.random())
sphere.Position = Vector3.new(0,20,0)
sphere.Shape = Enum.PartType.Block
sphere.Parent = workspace

local spherePoints,sphereInds = geometry.unwrapSphere(sphere)

sphere.Position += Vector3.new(0,sphere.Size.Y * 2,0)

local normals: {{center: Vector3, normal: Vector3}} = {}
for i = 1,math.floor(#sphereInds / 3) do
    local index = i * 3 - 2

    local p1 = spherePoints[sphereInds[index]]
    local p2 = spherePoints[sphereInds[index + 1]]
    local p3 = spherePoints[sphereInds[index + 2]]

    table.insert(normals,{center = (p1 + p2 + p3)/3, normal = geometry.calcTriNormal(p1, p2, p3)})

    local w1, w2 = geometry.generateTriangle(p1,p2,p3)

    w1.Parent = workspace
    w2.Parent = workspace

    w1.Transparency = 0
    w2.Transparency = 0

    local color = Color3.new(math.random(),math.random(),math.random())
    w1.Color = color
    w2.Color = color
end

while task.wait() do
    for i,v in pairs(spherePoints) do
        gizmo.setColor(Color3.new(1,1,1))
        -- gizmo.drawSphere(CFrame.new(v),0.5)
        
        gizmo.setColor(Color3.new(0,0,0))
        gizmo.setScale(2)
        -- gizmo.drawText(v, tostring(i))
    end

    for i,v in pairs(normals) do
        gizmo.setColor(Color3.new(1.000000, 0.5, 0.000000))
        gizmo.setScale(5)
        gizmo.drawRay(v.center, v.normal * 4)
    end
end
