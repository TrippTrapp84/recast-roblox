if true then return end

local geometry = require(script.Parent.Parent["recast-roblox"].util.geometry)
local gizmo = require(script.Parent.Parent.packages.gizmo)

local points: {Vector3} = {}
local av = Vector3.zero
for i,v in pairs(workspace.Points:GetChildren()) do
    points[tonumber(v.Name) :: number] = v.Position
    av += v.Position
end

av /= #points

local polyInside = table.create(21)
local polyOutside = table.create(21)

task.spawn(function()
    geometry.dividePolygonOnGridAxis(points, #points, "X", av.X, polyInside, polyOutside)
end)

task.spawn(function()
    while task.wait() do
        for i,v in pairs(polyOutside) do
            gizmo.setColor(Color3.new(1,0,1))
            gizmo.drawSphere(CFrame.new(v), 0.25)
        end

        for i,v in pairs(polyInside) do
            gizmo.setColor(Color3.new(0,1,0))
            gizmo.drawSphere(CFrame.new(v + Vector3.new(0,1,0)), 0.25)
        end
    end
end)

local inParts = geometry.generatePolygon(polyInside, geometry.makeGuaranteedIndexArray(polyInside))
local outParts = geometry.generatePolygon(polyOutside, geometry.makeGuaranteedIndexArray(polyOutside))

for i,v in pairs(inParts) do
    for _,p in pairs(v) do
        p.Parent = workspace
        p.Transparency = 0
        p.Color = Color3.new(0,1,0) 
    end
end

for i,v in pairs(outParts) do
    for _,p in pairs(v) do
        p.Parent = workspace
        p.Transparency = 0
        p.Color = Color3.new(1,0,0) 
    end
end
