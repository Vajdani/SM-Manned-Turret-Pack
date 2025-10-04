---@class SeatChunkLoader : ShapeClass
SeatChunkLoader = class()

function SeatChunkLoader:server_onCreate()
    self.shape:destroyShape()
    sm.log.warning("DESTROYED SEAT CHUNK LOADER")
end