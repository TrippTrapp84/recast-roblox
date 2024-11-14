local Benchmarker = {}

export type Profiler = {
    Begin: (label: string) -> (),
    End: (time: number?) -> ()
}

return Benchmarker