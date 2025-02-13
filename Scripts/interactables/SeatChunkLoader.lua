---@class SeatChunkLoader : ShapeClass
SeatChunkLoader = class()

function SeatChunkLoader:server_onCreate()
    local dummy = self.params or sm.character.createCharacter(sm.player.getAllPlayers()[1], sm.world.getCurrentWorld(), self.shape.worldPosition + vec3_up)
    self.interactable:setSeatCharacter(dummy)

    self.dummy = dummy
    self.position = self.shape.worldPosition
end

function SeatChunkLoader:server_onDestroy()
    sm.log.warning("TRYING TO CREATE LOADER")
    local pos_64 = self.position/64
    local x, y = math.floor(pos_64.x), math.floor(pos_64.y)
    local cellKey = CellKey(x, y)
    sm.event.sendToTool(g_turretAssistor, "sv_recreateChunkLoader", { pos = self.position, dummy = self.dummy, cellKey = cellKey })
end

function SeatChunkLoader:client_onUpdate()
    local char = self.interactable:getSeatCharacter()
    if char then
        char:setNameTag("")
    end
end