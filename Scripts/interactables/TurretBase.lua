---@class ExplosionDebris
---@field uuid Uuid
---@field offset Vec3

---@class TurretBase : ShapeClass
---@field maxHealth number
---@field seatUUID string
---@field seatHologramUUID string
---@field explosionDebrisData ExplosionDebris[]
---@field turret Harvestable
---@field cl_turret Harvestable
TurretBase = class()
TurretBase.maxParentCount = 1
TurretBase.maxChildCount = 0
TurretBase.connectionInput = sm.interactable.connectionType.ammo + sm.interactable.connectionType.water + 2^13 + 2^14
TurretBase.connectionOutput = sm.interactable.connectionType.none
TurretBase.colorNormal = sm.color.new( 0xcb0a00ff )
TurretBase.colorHighlight = sm.color.new( 0xee0a00ff )
TurretBase.maxHealth = 1000
TurretBase.seatUUID = "22b00c9e-e040-48e2-b67a-3f41a6470354"
TurretBase.seatHologramUUID = "49ce0ee7-7d9b-43b0-8160-5dc3fb127cfb"
TurretBase.explosionDebrisData = { --swap the blender y and z coordinates, invert z afterwards
    { uuid = sm.uuid.new("81b668f4-af00-4fbc-b359-dd1b35b939e5"), offset = sm.vec3.new(0.960741,    -2.49486,   -0.842322) * 0.25 },
    { uuid = sm.uuid.new("81b668f4-af00-4fbc-b359-dd1b35b939e5"), offset = sm.vec3.new(-0.960741,   -2.49486,   -0.842322) * 0.25 },
    { uuid = sm.uuid.new("5dde0f36-1cbb-47ba-a9ba-a0cc2b1db555"), offset = sm.vec3.new(-1.07416,    1.37402,      5.55211) * 0.25 },
    { uuid = sm.uuid.new("5dde0f36-1cbb-47ba-a9ba-a0cc2b1db555"), offset = sm.vec3.new(1.07416,     1.37402,      5.55211) * 0.25 },
    { uuid = sm.uuid.new("a58a7a52-6737-468f-a499-aee18faedabb"), offset = sm.vec3.new(0.971095,    1.18554,      2.06928) * 0.25 },
    { uuid = sm.uuid.new("17a8ce54-0617-422c-bac7-9c5c07203094"), offset = sm.vec3.new(-0.971095,   1.18554,      2.06928) * 0.25 },
    { uuid = sm.uuid.new("ea9511ab-26bf-4dcb-9929-7c688f2b240e"), offset = sm.vec3.new(1.45117,     -0.877968,    2.84755) * 0.25 },
    { uuid = sm.uuid.new("d793783b-6ac8-4fb7-b9b4-b7f2d159efed"), offset = sm.vec3.new(-1.45117,    -0.877968,    2.84755) * 0.25 },
}

function TurretBase:server_onCreate()
    local data = self.storage:load() or {}
    local health = data.health or self.maxHealth
    self.destroyed = data.destroyed or false
    self.ammoType = data.ammoType or 1

    self:sv_createTurret()
    self.network:setClientData({ health = health, destroyed = self.destroyed, ammoType = self.ammoType }, 2)
end

function TurretBase:server_onDestroy()
    if sm.exists(self.turret) then
        self.turret:destroy()
    end
end

function TurretBase:sv_respawnSeat(args, caller)
    self:sv_createTurret()

    local contacts = sm.physics.getSphereContacts(self:getSeatPos(), 1)
    local char = contacts.characters[1]
    if char then
        self:sv_trySeat(char:getPlayer())
    end
end

function TurretBase:sv_trySeat(player)
    if not sm.exists(self.turret) then
        sm.event.sendToInteractable(self.interactable, "sv_trySeat", player)
        return
    end

    sm.event.sendToInteractable(self.interactable, "sv_delaySeat", player)
end

function TurretBase:sv_delaySeat(player)
    sm.event.sendToHarvestable(self.turret, "sv_seatRespawn", player)
end

function TurretBase:server_onProjectile(position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid)
    self:sv_takeDamage(damage)
end

function TurretBase:server_onMelee(position, attacker, damage, power, direction, normal)
    self:sv_takeDamage(damage)
end

function TurretBase:server_onExplosion(center, destructionLevel)
    self:sv_takeDamage(destructionLevel * 25)
end

function TurretBase:sv_takeDamage(damage)
    --if self.cl_health <= 0 and damage >= 0 then return end

    local prevDestroyed = self.destroyed
    local newHealth = sm.util.clamp(self.cl_health - damage, 0, self.maxHealth)
    local turretExists = sm.exists(self.turret)
    if newHealth <= 0 and not self.destroyed then
        self.network:sendToClients("cl_onDestroy")

        local char = self.turret:getSeatCharacter()
        self.turret:destroy()

        if char then
           char:setTumbling(true)
        end

        self.destroyed = true
    elseif newHealth == self.maxHealth and not turretExists then
        self.destroyed = false
        self:sv_createTurret()
    end

    print(string.format("[TURRET ID[%s]] Took %s damage: %s / %s HP", self.shape.id, damage, newHealth, self.maxHealth))
    self.cl_health = newHealth
    if turretExists then
        self.turret.publicData.health = newHealth
    end

    local data = { health = newHealth, destroyed = self.destroyed, prevDestroyed = prevDestroyed, ammoType = self.ammoType }
    self.storage:save(data)
    self.network:setClientData(data, 2)
end

function TurretBase:sv_e_setAmmoType(ammoType)
    self.ammoType = ammoType
    self.storage:save({ health = self.cl_health, destroyed = self.destroyed, ammoType = ammoType })
end

function TurretBase:server_canErase()
    return self.cl_health >= self.maxHealth and self.turret:getSeatCharacter() == nil
end

function TurretBase:sv_createTurret()
    if self.destroyed then return end
    self.turret = sm.harvestable.create(sm.uuid.new(self.seatUUID), self:getSeatPos(), self.shape.worldRotation)
    self.turret:setParams({ base = self.interactable, ammoType = self.ammoType })
    self.network:setClientData(self.turret, 1)
end

function TurretBase:sv_updateDir(dir)
    if not sm.exists(self.turret) or not self.turret.publicData.controlsEnabled then return end

    self.network:sendToClients("cl_n_updateDir", dir)
end

---@param slot number
---@param caller Player
function TurretBase:sv_onRepair(slot, caller)
    if type(slot) == "number" then
        local inv = sm.game.getLimitedInventory() and caller:getInventory() or caller:getHotbar()
        caller.publicData = caller.publicData or {}
        caller.publicData.itemBeforeRepair = { slot = slot, item = inv:getItem(slot) }

        sm.container.beginTransaction()
        inv:setItem(slot, sm.uuid.new("68f9a1ef-dbbc-40c9-8006-0779ececcbf5"), 1)
        sm.container.endTransaction()
    else
        self.network:sendToClient(caller, "cl_onRepairEnd", slot)
    end
end

function TurretBase:sv_onRepairToolDestroy(player)
    self.network:sendToClient(player, "cl_onRepairToolDestroy")
end

function TurretBase:sv_setDirTarget(dir)
    self.network:sendToClients("cl_setDirTarget", dir)
end


function TurretBase:client_onCreate()
    self.healthBar = sm.gui.createSurvivalHudGui()
    self.healthBar:setVisible("WaterBar", false)
    self.healthBar:setVisible("FoodBar", false)
    self.healthBar:setVisible("BindingPanel", false)

    self.turretRot = self.shape.worldRotation
    self.dir = { x = 0, y = 0 }
    self.dirProgress = 0

    self.cl_health = self.maxHealth

    self.interactable:setSubMeshVisible("turretpart1", false)
    self.interactable:setSubMeshVisible("turretpart2", false)

    self.seatBroken = false
    self.gunBroken = false
end

function TurretBase:client_onDestroy()
    self.healthBar:destroy()
end

function TurretBase:client_canErase()
    local canErase = not g_repairingTurret and self.cl_health >= self.maxHealth and self.cl_turret:getSeatCharacter() == nil
    if not canErase then
        sm.gui.setInteractionText("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>Unable to pick up turret</p>")
    end

    return canErase
end

function TurretBase:client_canInteract()
    local seatExists = sm.exists(self.cl_turret)
    local canInteract = seatExists and self.cl_turret:getSeatCharacter() == nil
    local canRepair = self.cl_health < self.maxHealth

    if not g_repairingTurret then
        local displayTexts = {}
        if canInteract then
            table.insert(displayTexts, sm.gui.getKeyBinding("Use", true))
            table.insert(displayTexts, "#{INTERACTION_USE}")
        elseif seatExists then
            table.insert(displayTexts, "<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>#{ALERT_DRIVERS_SEAT_OCCUPIED}</p>")
        end

        if canRepair then
            table.insert(displayTexts, (displayTexts[1] and "\t" or "")..sm.gui.getKeyBinding("Tinker", true))
            table.insert(displayTexts, "Repair")
        end

        sm.gui.setInteractionText("", displayTexts[1] or "", displayTexts[2] or "", displayTexts[3] or "", displayTexts[4] or "")
    end

    if canRepair then
        if g_repairingTurret then
            sm.gui.setInteractionText("", getRepairText())
        end
        sm.gui.setInteractionText("", getHealthDisplay(self.cl_health))
    end

    return canInteract and not g_repairingTurret
end

function TurretBase:client_onInteract(char, state)
    if not state then return end
    sm.event.sendToHarvestable(self.cl_turret, "cl_seat", char)
end

function TurretBase:client_canTinker()
    return self.cl_health < self.maxHealth
end

function TurretBase:client_onTinker(char, state)
    if state == g_repairingTurret then return end

    if state then
        g_repairingTurret = true
        g_turretBase = self.interactable
    end

    if sm.game.getLimitedInventory() then
        self.network:sendToServer("sv_onRepair", state and sm.localPlayer.getSelectedHotbarSlot() or g_repairTool)
    else
        local inv = sm.localPlayer.getHotbar()
        local selectedSlot = sm.localPlayer.getSelectedHotbarSlot()
        local activeItem = sm.localPlayer.getActiveItem()
        for i = 1, inv.size do
            local hotbarSlot = i - 1
            local row = math.ceil(i/10) - 1
            if i > 10 then
                hotbarSlot = hotbarSlot - row * 10
            end

            local containerSlot = i - 1
            if hotbarSlot == selectedSlot and inv:getItem(containerSlot).uuid == activeItem then
                self.network:sendToServer("sv_onRepair", state and containerSlot or g_repairTool)
                break
            end
        end
    end
end

function TurretBase:client_onUpdate(dt)
    if not (self.cl_turret and sm.exists(self.cl_turret)) then return end

    self.cl_turret:setPosition(self:getSeatPos())

    if self.dirTarget then
        self.dirProgress = self.dirProgress + dt
        self.dir.x = sm.util.lerp(self.dirPrev.x, self.dirTarget.x, self.dirProgress)
        self.dir.y = sm.util.lerp(self.dirPrev.y, self.dirTarget.y, self.dirProgress)
        self:cl_updateDir({ x = 0, y = 0 })

        if self.dirProgress >= 1 then
            self.dirProgress = 0
            self.dirPrev = nil
            self.dirTarget = nil
        end
    elseif not self.shape.body:isOnLift() and self.cl_turret:getSeatCharacter() == sm.localPlayer.getPlayer().character and self.cl_turret.clientPublicData.controlsEnabled then
        local x, y = sm.localPlayer.getMouseDelta()
        if x ~= 0 or y ~= 0 then
            local dir = { x = x , y = y }
            self.network:sendToServer("sv_updateDir", dir)
            self:cl_updateDir(dir)
        end
    end

    local targetRot = sm.quat.angleAxis(self.dir.x, vec3_forward)
    targetRot = targetRot * sm.quat.angleAxis(-self.dir.y, vec3_right)
    --self.turretRot = nlerp(self.turretRot, self.shape.worldRotation * targetRot, dt * 20)
    self.cl_turret:setRotation(self.shape.worldRotation * targetRot) --self.turretRot)
end

function TurretBase:client_onClientDataUpdate(data, channel)
    if channel == 1 then
        self.turretRot = self.shape.worldRotation
        self.dir = { x = 0, y = 0 }

        self.cl_turret = data
        self.interactable:setSubMeshVisible("turretpart1", false)
        self.interactable:setSubMeshVisible("turretpart2", false)
    else
        local health = data.health
        self.cl_health = health
        self.healthBar:setSliderData("Health", self.maxHealth, health)

        if sm.exists(self.cl_turret) then
            self.cl_turret.clientPublicData.health = health
        end

        if data.destroyed then
            if data.prevDestroyed == false then
                self.healthBar:close()

                self.turretRot = self.shape.worldRotation
                self.dir = { x = 0, y = 0 }
            end

            if not self.repairVisualization or not sm.exists(self.repairVisualization) then
                if health > 0 then
                    self.repairVisualization = sm.effect.createEffect("ShapeRenderable", self.interactable)
                    self.repairVisualization:setParameter("uuid", sm.uuid.new(self.seatHologramUUID))
                    self.repairVisualization:setParameter("visualization", true)
                    self.repairVisualization:setOffsetPosition(vec3_forward * 1.33)
                    self.repairVisualization:setScale(vec3_one * 0.25)
                    self.repairVisualization:start()
                end
            elseif health <= 0 then
                self.repairVisualization:destroy()
            end

            local seatBroken = health >= TurretBase.maxHealth * 0.5
            if seatBroken ~= self.seatBroken then
                self.interactable:setSubMeshVisible("turretpart1", seatBroken)
                self.seatBroken = seatBroken

                if seatBroken then
                    local rot = self.shape.worldRotation
                    sm.effect.playEffect("Turret - SeatRepair1", self.shape.worldPosition + rot * vec3_forward * 0.5, vec3_zero, rot)
                else
                    sm.effect.playEffect("Sledgehammer - Destroy", self:getSeatPos(), vec3_zero, self.shape.worldRotation, vec3_one, { Material = 9, Volume = 10, Color = self.shape.color })
                end
            end

            local gunBroken = health >= TurretBase.maxHealth * 0.8
            if gunBroken ~= self.gunBroken then
                self.interactable:setSubMeshVisible("turretpart2", gunBroken)
                self.gunBroken = gunBroken

                if gunBroken then
                    sm.effect.playEffect("Turret - SeatRepair2", self.shape.worldPosition + self.shape.worldRotation * (vec3_up * 0.625 + vec3_forward))
                else
                    local rot = self.shape.worldRotation
                    sm.effect.playEffect("Sledgehammer - Destroy", self.shape.worldPosition + rot * (vec3_up * 0.625 + vec3_forward), vec3_zero, rot, vec3_one, { Material = 9, Volume = 10, Color = self.shape.color })
                end
            end
        elseif health >= self.maxHealth then
            if g_repairingTurret then
                self.network:sendToServer("sv_onRepair", g_repairTool)
            end

            if data.prevDestroyed == true then
                sm.effect.playEffect("Builderguide - Stagecomplete", self:getSeatPos(), vec3_zero, self.shape.worldRotation)
                self.repairVisualization:destroy()
            end
        end
    end
end

function TurretBase:cl_n_updateDir(dir)
    if not sm.exists(self.cl_turret) then return end

    if sm.localPlayer.getPlayer().character ~= self.cl_turret:getSeatCharacter() then
        self:cl_updateDir(dir)
    end
end

function TurretBase:cl_updateDir(dir)
    self.dir.x = self.dir.x + dir.x
    self.dir.y = self.dir.y + dir.y

    local norm_y = math.abs(self.dir.y)
    local limit = self.dir.y < 0 and 0.7 or 1.05 --lower/upper
    if norm_y > limit then
        self.dir.y = self.dir.y * (limit / norm_y)
    end
end

function TurretBase:cl_setDirTarget(dir)
    self.dirProgress = 0
    self.dirPrev = self.dir
    self.dirTarget = dir
end

function TurretBase:cl_n_toggleHud(toggle, forceSurvivalOff)
    if type(toggle) == "table" then
        toggle, forceSurvivalOff = toggle[1], toggle[2]
    end

    if toggle then
        self.healthBar:open()
        if sm.SURVIVALHUD then
            sm.SURVIVALHUD:close()
        end
    else
        self.healthBar:close()
        if sm.SURVIVALHUD and not forceSurvivalOff then
            sm.SURVIVALHUD:open()
        end
    end
end

function TurretBase:cl_onRepairEnd(tool)
    if not sm.exists(tool) then return end
    sm.event.sendToTool(tool, "cl_markUnforce")
end

function TurretBase:cl_onRepairToolDestroy()
    sm.tool.forceTool(nil)
	g_repairingTurret = false
    g_turretBase = nil
end

function TurretBase:cl_onDestroy()
    local seatPos = self:getSeatPos()

    --sm.effect.playEffect("Turret - Explode", seatPos, vec3_zero, self.turret.worldRotation * sm.quat.angleAxis(math.rad(-90), vec3_right))

    local rot = self.cl_turret.worldRotation
    local col = self.shape.color
    for k, data in pairs(self.explosionDebrisData) do
        local pos = seatPos + rot * data.offset
        --sm.debris.createDebris(data.uuid, pos, rot, (pos - seatPos):normalize() * (math.random(100, 0) * 0.1), vec3_zero, col)
        sm.effect.playEffect(
            "Explosion - Debris", pos, vec3_zero,
            rot * sm.quat.angleAxis(math.rad(math.random(-600, -1200) * 0.1), vec3_right) * sm.quat.angleAxis(math.rad(math.random(-300, 300) * 0.1), vec3_forward),
            vec3_one, { Renderable = data.uuid, Material = 9, Color = col }
        )
    end

    sm.effect.playEffect("PropaneTank - ExplosionSmall", seatPos)
end



function TurretBase:getSeatPos()
    if not sm.exists(self.cl_turret) then
        return self.shape.worldPosition + self.shape.at * 1.33 + self.shape.velocity * 0.05
    end

    local turretPos = self.cl_turret.worldPosition
    local targetPos = turretPos + self.cl_turret.worldRotation * vec3_forward * 0.8
    return self.shape.worldPosition + self.shape.at * 0.53 + self.shape.velocity * 0.05 + (targetPos - turretPos)
end