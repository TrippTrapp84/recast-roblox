
--[=[
   @type Triangle {A: Vector3, B: Vector3, C: Vector3}

   A clockwise representation of the 3 points in a triangle
]=]
export type Triangle = {A: Vector3, B: Vector3, C: Vector3}

--[=[
   @type VertexArray {Vector3}

   An array of verticies, usually to be indexed using an `IndexArray`
]=]
export type VertexArray = {Vector3}

--[=[
   @type IndexArray {number}

   Ann array of indicies, usually used to index a `VertexArray`
]=]
export type IndexArray = {number}

return {}