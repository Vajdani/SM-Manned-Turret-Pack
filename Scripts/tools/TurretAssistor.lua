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



local function ReadFile(path)
    if sm.json.fileExists(path) then
        return sm.json.open(path)
    end

    return { version = 0 }
end


---@class TurretAssistor : ToolClass
TurretAssistor = class()

g_TurretSeatChunkLoaders = g_TurretSeatChunkLoaders or {}
g_saveKey_TurretSeatChunkLoaders = "af96778d-402e-4f42-9332-3cb7d9119479"
function TurretAssistor:server_onCreate()
    if g_turretAssistor then return end --Prevent multiple loads

    g_TurretSeatChunkLoaders = sm.storage.load(g_saveKey_TurretSeatChunkLoaders) or {}
    g_turretAssistor = self.tool

    self.players = sm.player.getAllPlayers()

    local selfVer = ReadFile("$CONTENT_DATA/modVersion.json").version
    local kinematicVer = ReadFile("$CONTENT_0407ffa7-c133-4934-a490-fe737c11d262/modVersion.json").version
    local text
    if selfVer > kinematicVer then
        text = "#ff0000[MANNED TURRET PACK] #df7f00KINEMATIC MOD#ffffff OUT OF DATE, UPDATE AT: #df7f00https://steamcommunity.com/sharedfiles/filedetails/?id=3107289209"
    elseif selfVer < kinematicVer then
        text = "#ff0000[MANNED TURRET PACK] #df7f00BLOCKS AND PARTS MOD#ffffff OUT OF DATE, UPDATE AT: #df7f00https://steamcommunity.com/sharedfiles/filedetails/?id=3107290429"
    end

    if text then
        sm.log.warning(text)
        sm.gui.chatMessage(text)
    end
end

function TurretAssistor:server_onFixedUpdate()
    if g_turretAssistor ~= self.tool then return end

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
            if sm.exists(int) and int.type == "scripted" and (int.publicData or {}).isTurret == true then
                sm.event.sendToInteractable(int, "sv_syncToLateJoiner", player)
            end
        end
    end
end

function TurretAssistor:sv_recreateChunkLoader(data)
    local seat = sm.shape.createPart(sm.uuid.new("53a7a730-24e1-49b6-b3df-54407ea75b82"), sm.vec3.new(data.pos.x, data.pos.y, -200), nil, false, true)
    seat.interactable:setParams(data.dummy)

    g_TurretSeatChunkLoaders[data.cellKey] = seat
    sm.storage.save(g_saveKey_TurretSeatChunkLoaders, g_TurretSeatChunkLoaders)
end