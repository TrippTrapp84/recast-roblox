--[=[
   @class Types
]=]
local Types = {}

--[=[
   @type Triangle {A: Vector3, B: Vector3, C: Vector3}
   @within Types

   A clockwise representation of the 3 points in a triangle
]=]
export type Triangle = {A: Vector3, B: Vector3, C: Vector3}

--[=[
   @type VertexArray {Vector3}
   @within Types

   An array of vertices, usually to be indexed using an `IndexArray`
]=]
export type VertexArray = {Vector3}

--[=[
   @type IndexArray {number}
   @within Types

   Ann array of indices, usually used to index a `VertexArray`
]=]
export type IndexArray = {number}

export type AreaId = number
Types.AreaId = {
   Walkable = 63,
   Null = 0,
}

Types.DirectionX = {
   -1,
   0,
   1,
   0
}
Types.DirectionY = {
   0,
   1,
   0,
   -1
}

export type AxisId = "X" | "Y" | "Z"

return Types