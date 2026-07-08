---@diagnostic disable:duplicate-set-field

sm.MannedTurret_ToolHooks = sm.MannedTurret_ToolHooks or {}

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

oldBind = oldBind or sm.game.bindChatCommand
function bindHook(command, params, callback, help)
    if not gameHooked then
        gameHooked = true
        dofile("$CONTENT_f51045bd-3f94-476a-8053-55ba172d19a5/Scripts/vanilla_override.lua")
    end

	return oldBind(command, params, callback, help)
end
sm.game.bindChatCommand = bindHook

oldVizSetBodies = oldVizSetBodies or sm.visualization.setCreationBodies
function sm.visualization.setCreationBodies(bodies)
    sm.visualization.currentBodies = bodies
    oldVizSetBodies(bodies)
end

oldVizSetVisible = oldVizSetVisible or sm.visualization.setCreationVisible
function sm.visualization.setCreationVisible(state)
    sm.visualization.isVisible = state
    oldVizSetVisible(state)
end

oldVizSetFreePlacement = oldVizSetFreePlacement or sm.visualization.setCreationFreePlacement
function sm.visualization.setCreationFreePlacement(state)
    sm.visualization.creationFreePlacement = state
    oldVizSetFreePlacement(state)
end

function sm.visualization.isBodyHighlighted(body, lift)
    if not sm.visualization.isVisible or not lift and sm.visualization.creationFreePlacement then
        return false
    end

    for k, v in pairs(sm.visualization.currentBodies) do
        if v == body then
            return true
        end
    end

    return false
end

dofile "$CONTENT_f51045bd-3f94-476a-8053-55ba172d19a5/Scripts/mod_override.lua"

oldPreload = oldPreload or sm.tool.preloadRenderables
function sm.tool.preloadRenderables(rends)
    dofile "$CONTENT_f51045bd-3f94-476a-8053-55ba172d19a5/Scripts/mod_override.lua"

    oldPreload(rends)
end


local function ReadFile(path)
    if sm.json.fileExists(path) then
        return sm.json.open(path)
    end

    return { version = 0 }
end


---@class TurretAssistor : ToolClass
TurretAssistor = class()

sm.MANNEDTURRET_turretChunkLoaders = sm.MANNEDTURRET_turretChunkLoaders or {}
sm.MANNEDTURRET_turretChunkLoaders_saveKey = "af96778d-402e-4f42-9332-3cb7d9119479"
function TurretAssistor:server_onCreate()
    if sm.MANNEDTURRET_turretAssistor then return end --Prevent multiple loads

    -- sm.storage.save(sm.MANNEDTURRET_turretChunkLoaders_saveKey, nil)
    sm.MANNEDTURRET_turretChunkLoaders = sm.storage.load(sm.MANNEDTURRET_turretChunkLoaders_saveKey) or {}
    sm.log.error(sm.MANNEDTURRET_turretChunkLoaders)

    for cellKey, chunk in pairs(sm.MANNEDTURRET_turretChunkLoaders) do
        local newChunks = {}
        for _k, base in pairs(chunk.bases) do
            if sm.exists(base) then
                table.insert(newChunks, base)
            end
        end

        if #newChunks == 0 then
            sm.event.sendToGame("sv_releaseTurretChunkLoaderHandle", cellKey)
        end

        chunk.bases = newChunks
    end

    self:sv_saveChunkLoaders()

    sm.MANNEDTURRET_turretAssistor = self.tool

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

    self.charQueue = {}
end

function TurretAssistor:server_onFixedUpdate()
    if sm.MANNEDTURRET_turretAssistor ~= self.tool then return end

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

    for k, v in pairs(self.charQueue) do
        if v and sm.exists(v) then
            sm.log.warning("CHARACTER DISCARDED")
            v:setWorldPosition(vec3(0, 0, -512))
            self.charQueue[k] = nil
        end
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

function TurretAssistor:sv_saveChunkLoaders()
	sm.storage.save(sm.MANNEDTURRET_turretChunkLoaders_saveKey, sm.MANNEDTURRET_turretChunkLoaders)
end

function TurretAssistor:sv_addCharToDestroyQueue(char)
    sm.log.warning("CHARACTER ADDED TO DISCARD QUEUE")
    table.insert(self.charQueue, char)
end