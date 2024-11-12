local NavigationMesh = require(script["nav-mesh"])

type NavigationMesh = NavigationMesh.NavigationMesh

local Recast = {}

function Recast.GenerateMesh(): NavigationMesh
    return NavigationMesh.new()
end

return Recast