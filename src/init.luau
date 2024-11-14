local Types = require(script.types)
local NavigationMesh = require(script["nav-mesh"])

type NavigationMesh = Types.NavigationMesh

local Recast = {}

function Recast.GenerateMesh(): NavigationMesh
    return NavigationMesh.new()
end

return Recast