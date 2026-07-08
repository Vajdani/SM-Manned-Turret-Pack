sm.log.error("Mod override loading")

--All Technical Guns tools
local blackList = {
    mp5a = true,
    at4 = true,
    Sword = true,
    AK74 = true,
    m4a1 = true,
    val = true,
    glock = true,
    pkm = true,
    rpg = true,
    coltt = true,
}

oldToolFuncs = oldToolFuncs or {}
function HookTools()
    for k, v in pairs(_G) do
        if type(v) ~= "table" then
            goto continue
        end

        if v.client_onEquip and k ~= "RepairTool" then
            print("[Manned Turret] Tool found:", k)
            if not oldToolFuncs[k] then
                oldToolFuncs[k] = {
                    client_onEquip = v.client_onEquip,
                    client_onUnequip = v.client_onUnequip,
                    client_onUpdate = v.client_onUpdate,
                }
            end

            function v:sv_forceUnequipOnRepairStart(repairTool)
                self.network:sendToClients("cl_forceUnequipOnRepairStart", repairTool)
            end

            function v:cl_forceUnequipOnRepairStart(repairTool)
                self:client_onUnequip(true, true)

                if repairTool:isLocal() then
                    if self.unequipAnim and blackList[k] == nil then
                        self.repairTool = repairTool
                    else
                        sm.tool.forceTool(repairTool)
                    end
                end
            end

            function v.client_onEquip(self, ...)
                local player = self.tool:getOwner()
                if not player.clientPublicData then
                    player.clientPublicData = {}
                end

                player.clientPublicData.currentTool = self.tool

                -- print(k, "equipping", ...)

                local func = oldToolFuncs[k].client_onEquip
                if func then
                    func(self, ...)
                end

                if self.tool:isLocal() and self.fpAnimations then
                    if self.fpAnimations.animations.unequip then
                        self.unequipAnim = "unequip"
                    elseif self.fpAnimations.animations.putdown then
                        self.unequipAnim = "putdown"
                    end
                end
            end

            function v.client_onUnequip(self, ...)
                local player = self.tool:getOwner()
                if not player.clientPublicData then
                    player.clientPublicData = {}
                end

                player.clientPublicData.currentTool = nil

                -- print(k, "unequipping", ...)

                local func = oldToolFuncs[k].client_onUnequip
                if func then
                    func(self, ...)
                end
            end

            function v:client_onUpdate(dt)
                local func = oldToolFuncs[k].client_onUpdate
                if func then
                    func(self, dt)
                end

                if self.tool:isLocal() and self.tool:isEquipped() and self.unequipAnim and self.repairTool then
                    local anim = self.fpAnimations.animations[self.unequipAnim]
                    if anim.time >= anim.info.duration then
                        sm.tool.forceTool(self.repairTool)

                        self.repairTool = nil
                    end
                end
            end
        end

        ::continue::
    end
end

if sm.MannedTurret_ToolHooks then
    table.insert(sm.MannedTurret_ToolHooks, function()
        HookTools()
    end)
else
    HookTools()
end


if TSU_IsOwnerSwimming then
    oldTSU_IsOwnerSwimming = oldTSU_IsOwnerSwimming or TSU_IsOwnerSwimming
    function TSU_IsOwnerSwimming(self)
        if self.repairTool then return true end

        return oldTSU_IsOwnerSwimming(self)
    end
end