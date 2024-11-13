local Root = script.Parent.Parent
local Types = require(Root.types)

local GOLDEN_RATIO = 1.618033988749895

local sphereTesselationResolution = 4
local sphereCoordinateLookupvertices: Types.VertexArray, sphereCoordinateLookupindices: Types.IndexArray = {}, {}

--[=[
    @class Geometry
]=]
local Geometry = {}

local triangleTemplateWedge = Instance.new("Part")
triangleTemplateWedge.Anchored = true
triangleTemplateWedge.CanCollide = false
triangleTemplateWedge.CanQuery = false
triangleTemplateWedge.CanTouch = false
triangleTemplateWedge.Transparency = 1
triangleTemplateWedge.Shape = Enum.PartType.Wedge
triangleTemplateWedge.Size = Vector3.one
function Geometry.generateTriangle(p1: Vector3, p2: Vector3, p3: Vector3): (Part, Part)
	local a, b, c = (p1 - p2).Magnitude, (p1 - p3).Magnitude, (p2 - p3).Magnitude

    --// These checks makes sure we're splitting our triangle on the longest side,
    --// that way our dividing line always lies inside the triangle.
	if b > c and b > a then
		local cb = b
		local cp = p3
		b = a ; p3 = p1
		a = c ; p1 = p2
		c = cb ; p2 = cp 
	elseif a > c then
		local ca = a
		local cp = p3
		a = b ; p3 = p2
		b = c ; p2 = p1
		c = ca ; p1 = cp
	end

    local d3 = (p3 - p2)
    local dot = (p1 - p2).Unit:Dot(d3.Unit)
	local x1,x2 = dot * a, (p1 - p3).Unit:Dot(-d3.Unit) * b
	local Ph = d3 * (x1/c) + p2
	local y = math.sin(math.acos(dot)) * a
	local Pos1,Pos2 = (p1 + p2) / 2,(p1 + p3) / 2
	local f1P4,f2P4 = (Pos1 - Ph) + Pos1,(Pos2 - Ph) + Pos2
	local zVec1,zVec2 = ((f1P4 + p1) / 2 - Pos1).Unit,((f2P4 + p1) / 2 - Pos2).Unit
	local yVec1,yVec2 = ((f1P4 + p2) / 2 - Pos1).Unit,((f2P4 + p3) / 2 - Pos2).Unit
	local xVec1,xVec2 = zVec1:Cross(yVec1),zVec2:Cross(yVec2)

	local Part1 = triangleTemplateWedge:Clone()
	Part1.Size = Vector3.new(0, x1, y)
	Part1.CFrame = CFrame.fromMatrix(Pos1,xVec1,yVec1)

	local Part2 = Part1:Clone()
	Part2.Size = Vector3.new(0,x2, y)
	Part2.CFrame = CFrame.fromMatrix(Pos2,xVec2,yVec2)

	return Part1, Part2
end

function Geometry.generatePolygon(vertices: Types.VertexArray, indices: Types.IndexArray): {Part}
    local parts = table.create(math.floor(#indices / 3) * 2)
    
    for i = 1,math.floor(#indices / 3) do
        local index = i * 3 - 2

        local p1 = vertices[indices[index]]
        local p2 = vertices[indices[index + 1]]
        local p3 = vertices[indices[index + 2]]

        local w1, w2 = Geometry.generateTriangle(p1, p2, p3)
        table.insert(parts,w1)
        table.insert(parts,w2)
    end

    return parts
end

--[=[
    @param vertices VertexArray -- The vertices of a convex polygon to generate an `IndexArray` for.

    @return IndexArray -- An index array corresponding to the `vertices`.

    **`NOTE`**: This function only works as intended when given clockwise-winding `VertexArray`s.
    If you need a winding-independent function, use `makeGuaranteedIndexArray` instead.
]=]
function Geometry.makeIndexArray(vertices: Types.VertexArray): Types.IndexArray
    local indices = table.create((#vertices-2) * 3)

    for i = 2,#vertices-1 do
        table.insert(indices, 1)
        table.insert(indices, i)
        table.insert(indices, i + 1)
    end

    return indices
end

--[=[
    @param vertices VertexArray -- The vertices of a convex polygon to generate an `IndexArray` for.

    @return IndexArray -- An index array corresponding to the `vertices`.

    This function is winding-independent but less performant than `makeIndexArray` as it requires sorting verticies in winding order.
]=]
function Geometry.makeGuaranteedIndexArray(vertices: Types.VertexArray): Types.IndexArray
    local center = Vector3.zero
    for i,v in pairs(vertices) do
        center += v
    end
    center /= #vertices

    local planeParallel = (vertices[1] - center).Unit
    local planeNormal = (vertices[1] - center):Cross(vertices[2] - center).Unit
    
    local sortedVertices = table.create(#vertices)
    local vertAngles = table.create(#vertices)
    for vertInd,v in pairs(vertices) do
        local offset = (v - center).Unit
        local angle = offset:Angle(planeParallel, planeNormal)

        local foundIndex = false
        for i,vertAngle in pairs(vertAngles) do
            if vertAngle > angle then
                table.insert(vertAngles, i, angle)
                table.insert(sortedVertices, i, vertInd)

                foundIndex = true
                break
            end
        end

        if foundIndex then continue end
        table.insert(vertAngles, angle)
        table.insert(sortedVertices, vertInd)
    end
    
    local indices = table.create((#vertices-2) * 3)

    for i = 2,#vertices-1 do
        table.insert(indices, sortedVertices[1])
        table.insert(indices, sortedVertices[i])
        table.insert(indices, sortedVertices[i + 1])
    end

    return indices
end

--[=[
    @param vertices VertexArray -- The vertices to divide along the grid axis.
    @param axis AxisId -- The grid axis to divide on. This is a grid axis for performance reasons, see `dividePolygonOnAxis` for a more general option.
    @param offset number -- The offset of the axis from the world origin. Think of this as the distance from the origin to the closest point on the axis plane.
    @param outPoly1 VertexArray -- An output destination for the verticies on the positive distance side of the axis. It is recommended to allocate a table of size `21` for this.
    @param outPoly2 VertexArray -- An output destination for the verticies on the negative distance side of the axis. It is recommended to allocate a table of size `21` for this.
]=]
function Geometry.dividePolygonOnGridAxis(vertices: Types.VertexArray, axis: Types.AxisId, offset: number, outPoly1: Types.VertexArray, outPoly2: Types.VertexArray)
    --// So I did actually benchmark this, using this outvar system is actually faster because lets you reuse the existing memory, the allocations along trigger a whole
    --// Host of garbage collection and cache misses. Weird to see in lua? Fair enough, but it's still more performant.

    local deltas: {number} = table.create(#vertices)

    for i,v in ipairs(vertices) do
        --// Yeah this typecast stupidity is dumb but I do it to avoid linting errors. The correct line would be:
        --// deltas[i] = offset - v[axis]
        deltas[i] = offset - ((v :: never) :: {})[axis:: never]
    end

    local vertex2Ind = #vertices
    for vertex1Ind, vertex1 in ipairs(vertices) do
        local sameSide = (deltas[vertex1Ind] >= 0) == (deltas[vertex2Ind] >= 0)

        if sameSide then
            vertex2Ind = vertex1Ind

            if deltas[vertex1Ind] >= 0 then
                table.insert(outPoly1,vertex1)
                if deltas[vertex1Ind] ~= 0 then continue end
            end

            table.insert(outPoly2,vertex1)
        else
            local vertex2 = vertices[vertex2Ind]

            local s = deltas[vertex2Ind] / (deltas[vertex2Ind] - deltas[vertex1Ind])
            local outVert = vertex2 + (vertex1 - vertex2) * s
            table.insert(outPoly1,outVert)
            table.insert(outPoly2,outVert)

            if deltas[vertex1Ind] > 0 then
                table.insert(outPoly1,vertex1)
            elseif deltas[vertex1Ind] < 0 then
                table.insert(outPoly2,vertex1)
            end

            vertex2Ind = vertex1Ind
        end
    end
end

--[=[
    @param vertices VertexArray
    @param indices IndexArray

    Optimizes a vertex and index array pair to remove duplicate vertices.
    Operates on `vertices` and `indices` in-place, so be careful not to accidentally
    mutate data another part of your program depended on
]=]
function Geometry.optimizeArrayPair(vertices: Types.VertexArray, indices: Types.IndexArray)
    local indexRemap = {}

    local vertsSet = {}
    local verts = {}
    for i,v in pairs(vertices) do
        if vertsSet[v] then continue end

        vertsSet[v] = #verts + 1
        table.insert(verts,v)
    end

    for i,v in pairs(indices) do
        local vert = vertices[indices[v]]
        indices[i] = vertsSet[vert]
    end

    table.clear(vertices)
    table.move(verts, 1, #verts, 1,vertices)
    
    --// I will come back to reimplement this for performance reasons, but right now
    --// I cannot make this code function without destroying the mesh data.

    -- for i = #vertices, 2, -1 do
    --     local iVert = vertices[i]
        
    --     for j = i-1, 1, -1 do
    --         local jVert = vertices[j]
    --         if iVert ~= jVert then continue end

    --         for from,to in pairs(indexRemap) do
	-- 			if to == i then
	-- 				indexRemap[from] = j
    --             elseif #vertices == to then
    --                 indexRemap[from] = i
    --             end
	-- 		end

    --         indexRemap[#vertices] = i
    --         indexRemap[i] = j
            
    --         vertices[i] = vertices[#vertices]
    --         table.remove(vertices)

    --         break
    --     end
    -- end

    -- for i,v in pairs(indices) do
    --     local remap = indexRemap[v]
    --     if not remap then continue end
    --     indices[i] = remap
    -- end
end

function Geometry.calcBounds(vertices: Types.VertexArray): (Vector3,Vector3)
    local boundHigh = Vector3.new(-math.huge,-math.huge,-math.huge)
    local boundLow = Vector3.new(math.huge,math.huge,math.huge)

    for i,v in pairs(vertices) do
        boundHigh = boundHigh:Max(v)
        boundLow = boundLow:Min(v)
    end
    
    return boundHigh, boundLow
end

function Geometry.subdivideTriangle(p1: Vector3, p2: Vector3, p3: Vector3, divides: number?): Types.VertexArray
    if divides < 1 then return {p1,p2,p3},{1,2,3} end

    local divides = divides or 1
    local segments = divides + 1
    local triCount = segments * segments

    local verts = table.create(triCount * 3)

    local dStep1 = (p1 - p2) / segments
    local dStep2 = (p3 - p2) / segments

    for i = 0,divides do
        local strip1Start = p2 + dStep1*i
        local strip1End = p2 + dStep2*i
        local strip2Start = p2 + dStep1*(i + 1)
        local strip2End = p2 + dStep2*(i + 1)

        local strip1Step = (strip1End-strip1Start) / (i)
        local strip2Step = (strip2End - strip2Start) / (i+1)

        table.insert(verts,strip2Start)
        table.insert(verts,strip1Start)
        table.insert(verts,strip2Start + strip2Step)

        for j = 1,i do
            do
                local p1 = strip2Start + strip2Step * (j)
                local p2 = strip1Start + strip1Step * (j-1)
                local p3 = p2 + strip1Step

                table.insert(verts,p1)
                table.insert(verts,p2)
                table.insert(verts,p3)
            end

            do
                local p1 = strip2Start + strip2Step * (j)
                local p2 = strip1Start + strip1Step * (j)
                local p3 = p1 + strip2Step

                table.insert(verts,p1)
                table.insert(verts,p2)
                table.insert(verts,p3)
            end
        end
    end

    return verts
end

--[=[
   @return boolean -- `true` if the bounds overlap, `false` if they do not.
]=]
function Geometry.overlapBounds(max1: Vector3, min1: Vector3, max2: Vector3, min2: Vector3): boolean
    return min1.X <= max2.X and max1.X >= min2.X
        and min1.Y <= max2.Y and max1.Y >= min2.Y
        and min1.Z <= max2.Z and max1.Z >= min2.Z
end

function Geometry.calcTriNormal(p1: Vector3, p2: Vector3, p3: Vector3): Vector3
    local edge1, edge2 = p2 - p1, p3 - p1
    
    return edge1:Cross(edge2).Unit
end

--[=[
   @param parts {BasePart} == The parts to unwrap the geometry of.

   @return (VertexArray,IndexArray) -- A vertex and index array containing the vertices (in world space) and the order in which they can be traced to form the shapes.
]=]
function Geometry.unwrap(parts: {BasePart}): (Types.VertexArray,Types.IndexArray)
    local vertices: Types.VertexArray = {}
    local indices: Types.IndexArray = {}
    
    for i,v in pairs(parts) do
        local verts, inds = Geometry.unwrapPart(v)

        table.move(verts,1,#verts,#vertices+1,vertices)
        table.move(inds,1,#inds,#indices+1,indices)
    end

    return vertices, indices
end

--[=[
    @param part BasePart -- The part to unwrap the geometry of.

    @return (VertexArray,IndexArray) -- A vertex and index array containing the vertices (in world space) and the order in which they can be traced to form the shape.
]=]
function Geometry.unwrapPart(part: BasePart): (Types.VertexArray,Types.IndexArray)
    assert(part:IsA("Part"),"Cannot unwrap the geometry of a non-primitive part")

    if part.Shape == Enum.PartType.Ball then
        return Geometry.unwrapSphere(part)
    elseif part.Shape == Enum.PartType.Block then
        return Geometry.unwrapBlock(part)
    elseif part.Shape == Enum.PartType.Cylinder then
        return Geometry.unwrapCylinder(part)
    elseif part.Shape == Enum.PartType.Wedge then
        return Geometry.unwrapWedge(part)
    elseif part.Shape == Enum.PartType.CornerWedge then
        return Geometry.unwrapCornerWedge(part)
    end

    error("Unknown block type!")
end

function Geometry.unwrapSphere(part: Part): (Types.VertexArray,Types.IndexArray)
    local verts, inds = table.clone(sphereCoordinateLookupvertices), table.clone(sphereCoordinateLookupindices)

    local size = part.Size
    local radius = math.min(size.X,size.Y,size.Z)

    for i,v in ipairs(verts) do
        verts[i] = v * radius + part.Position
    end

    return verts, inds
end

function Geometry.unwrapBlock(part: Part): (Types.VertexArray,Types.IndexArray)
    
end

function Geometry.unwrapCylinder(part: Part): (Types.VertexArray,Types.IndexArray)
    
end

function Geometry.unwrapWedge(part: Part): (Types.VertexArray,Types.IndexArray)
    
end

function Geometry.unwrapCornerWedge(part: Part): (Types.VertexArray,Types.IndexArray)
    
end

--// We do these down here so that I have my geometry functions already available to use
do
    local halfGolden = GOLDEN_RATIO/2
    --// Default points for an icosahedron, we will subdivide along these to generate vertices as needed
    local icoVerts: Types.VertexArray, icoInds: Types.IndexArray = {
        Vector3.new(halfGolden, 0.5, 0), -- 1
        Vector3.new(-halfGolden, 0.5, 0), -- 2
        Vector3.new(halfGolden, -0.5, 0), -- 3
        Vector3.new(-halfGolden, -0.5, 0), -- 4

        Vector3.new(0, halfGolden, 0.5), -- 5
        Vector3.new(0, -halfGolden, 0.5), -- 6
        Vector3.new(0, halfGolden, -0.5), -- 7
        Vector3.new(0, -halfGolden, -0.5), -- 8

        Vector3.new(0.5, 0, halfGolden), -- 9
        Vector3.new(-0.5, 0, halfGolden), -- 10
        Vector3.new(0.5, 0, -halfGolden), -- 11
        Vector3.new(-0.5, 0, -halfGolden), -- 12
    },{
        --// Middle Faces
        1,5,7,
        2,7,5,
        3,8,6,
        4,6,8,
        5,9,10,
        6,10,9,
        7,12,11,
        8,11,12,
        9,1,3,
        10,4,2,
        11,3,1,
        12,2,4,

        --// Corner Faces
        1,9,5,
        1,7,11,
        2,12,7,
        2,5,10,
        3,11,8,
        3,6,9,
        4,10,6,
        4,8,12
    }

    local verts: Types.VertexArray, inds: Types.IndexArray = {}, {}

    for i = 1,math.floor(#icoInds / 3) do
        local vertexInd = i * 3 - 2

        local p1 = icoVerts[icoInds[vertexInd]]
        local p2 = icoVerts[icoInds[vertexInd + 1]]
        local p3 = icoVerts[icoInds[vertexInd + 2]]

        local subVerts = Geometry.subdivideTriangle(p1, p2, p3, sphereTesselationResolution)
        
        table.move(subVerts,1,#subVerts,#verts + 1,verts)
        
        local startIndex = #inds
        for i,v in pairs(subVerts) do
            table.insert(inds, i + startIndex)
        end
    end

    Geometry.optimizeArrayPair(verts, inds)

    for i,v in pairs(verts) do
        verts[i] = v.Unit
    end

    sphereCoordinateLookupvertices = verts
    sphereCoordinateLookupindices = inds
end

return Geometry