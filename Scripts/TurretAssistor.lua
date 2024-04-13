local gameHooked = false
local oldEffect = sm.effect.createEffect
function effectHook(name, object, bone)
    if not gameHooked and name == "SurvivalMusic" then
        gameHooked = true
        dofile("$CONTENT_f51045bd-3f94-476a-8053-55ba172d19a5/Scripts/vanilla_override.lua")
    end

	return oldEffect(name, object, bone)
end
sm.effect.createEffect = effectHook

local oldBind = sm.game.bindChatCommand
function bindHook(command, params, callback, help)
    if not gameHooked then
        gameHooked = true
        dofile("$CONTENT_f51045bd-3f94-476a-8053-55ba172d19a5/Scripts/vanilla_override.lua")
    end

	return oldBind(command, params, callback, help)
end
sm.game.bindChatCommand = bindHook



---@class TurretAssistor : ToolClass
TurretAssistor = class()

function TurretAssistor:server_onCreate()
    self.players = sm.player.getAllPlayers()
end

function TurretAssistor:server_onFixedUpdate()
    local players = sm.player.getAllPlayers()
    local newLen, oldLen = #players, #self.players
    if newLen < oldLen then
        self.players = players
    elseif oldLen < newLen then
        for k, player in pairs(players) do
            if not isAnyOf(player, self.players) then
                self:sv_sendDataToJoiner(player)
            end
        end

        self.players = players
    end
end

function TurretAssistor:sv_sendDataToJoiner(player)
    for k, body in pairs(sm.body.getAllBodies()) do
        for _k, int in pairs(body:getInteractables()) do
            if (int.publicData or {}).isTurretBase == true then
                sm.event.sendToInteractable(int, "sv_syncToLateJoiner", player)
            end
        end
    end
end