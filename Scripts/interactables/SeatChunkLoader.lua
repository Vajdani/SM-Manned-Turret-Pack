---@class SeatChunkLoader : ShapeClass
SeatChunkLoader = class()

function SeatChunkLoader:server_onCreate()
    local dummy = sm.character.createCharacter(sm.player.getAllPlayers()[1], sm.world.getCurrentWorld(), self.shape.worldPosition + vec3_up * 100)
    self.interactable:setSeatCharacter(dummy)
end

function SeatChunkLoader:client_onUpdate()
    local char = self.interactable:getSeatCharacter()
    if char then
        char:setNameTag("")
    end
end