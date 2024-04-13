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
TurretBase.maxChildCount = 255
TurretBase.connectionInput = sm.interactable.connectionType.ammo + sm.interactable.connectionType.water + 2^13 + 2^14
TurretBase.connectionOutput = sm.interactable.connectionType.seated + sm.interactable.connectionType.power + sm.interactable.connectionType.bearing
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

    self.interactable.publicData = {
        isTurretBase = true,
        maxHealth = self.maxHealth
    }
end

function TurretBase:sv_syncToLateJoiner(player)
    self.network:sendToClient(player, "cl_syncToLateJoiner",
        {
            self.turret,
            { health = self.cl_health, destroyed = self.destroyed, ammoType = self.ammoType },
            self.dir
        }
    )
    sm.event.sendToHarvestable(self.turret, "sv_syncToLateJoiner", player)
end

function TurretBase:server_onDestroy()
    if sm.exists(self.turret) then
        self.turret:destroy()
    end
end

function TurretBase:server_onFixedUpdate()
    local active = sm.exists(self.turret) and self.turret:getSeatCharacter() ~= nil or false
    if active ~= self.interactable.active then
        self.interactable.active = active
    end

    if not active then return end

    local steerPower = self.interactable:getSteeringPower()
    if self.prevSteerPower ~= steerPower then
        self.prevSteerPower = steerPower
        self.interactable.power = steerPower
    end
end

function TurretBase:sv_respawnSeat()
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
            char:setWorldPosition(self:getSeatPos())
        end

        self:sv_clearDrivingFlags(false)

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
    local inv = sm.game.getLimitedInventory() and caller:getInventory() or caller:getHotbar()
    caller.publicData = caller.publicData or {}
    caller.publicData.itemBeforeRepair = { slot = slot, item = inv:getItem(slot) }

    sm.container.beginTransaction()
    inv:setItem(slot, sm.uuid.new("68f9a1ef-dbbc-40c9-8006-0779ececcbf5"), 1)
    sm.container.endTransaction()
end

function TurretBase:sv_setDirTarget(dir)
    self.network:sendToClients("cl_setDirTarget", dir)
end

function TurretBase:sv_clearDrivingFlags(active)
    self.interactable.active = active
    self.interactable.power = 0
    for k, v in pairs(sm.interactable.steering) do
        self.interactable:unsetSteeringFlag( v )
    end
end

function TurretBase:sv_putOnLift()
    self.network:sendToClients("cl_putOnLift")
end


sm.MANNEDTURRET_turretBases_clientPublicData = sm.MANNEDTURRET_turretBases_clientPublicData or {}
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

    self.bearingSettings = {}
	self.bearingSettings.updateDelay = 0.0
	self.bearingSettings.updateSettings = {}


    sm.MANNEDTURRET_turretBases_clientPublicData[self.interactable.id] = {
        isTurretBase = true
    }
end

function TurretBase:client_onDestroy()
    sm.MANNEDTURRET_turretBases_clientPublicData[self.interactable.id] = nil
    self.healthBar:destroy()

    if g_repairingTurret and g_turretBase == self.interactable then
        self:cl_onRepairEnd()
    end
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

function TurretBase:client_getAvailableChildConnectionCount( connectionType )
    --Seated, Power, Logic
    if bit.band(connectionType, 8) ~= 0 and (not bit.band(connectionType, 2) ~= 0 or not bit.band(connectionType, 1) ~= 0) then
        return 0
    end

	return self.maxChildCount - #self.interactable:getChildren(connectionType)
end

function TurretBase:client_onTinker(char, state)
    if state == g_repairingTurret then return end

    if state then
        g_repairingTurret = true
        g_turretBase = self.interactable

        if sm.game.getLimitedInventory() then
            self.network:sendToServer("sv_onRepair", sm.localPlayer.getSelectedHotbarSlot())
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
                    self.network:sendToServer("sv_onRepair", containerSlot)
                    break
                end
            end
        end
    else
        self:cl_onRepairEnd()
    end
end

function TurretBase:client_onUpdate(dt)
    if not (self.cl_turret and sm.exists(self.cl_turret)) then return end

    self:cl_checkHighlight()
    self.cl_turret:setPosition(self:getSeatPos() + (self.lifted and -vec3_up * 1000 or vec3_zero))

    local lifted = self.shape.body:isOnLift()
    if lifted then
        self.dirProgress = 0
        self.dirPrev = nil
        self.dirTarget = nil
        self.dir = { x = 0, y = 0 }
    end

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
    elseif not lifted and self.cl_turret:getSeatCharacter() == sm.localPlayer.getPlayer().character and self.cl_turret.clientPublicData.controlsEnabled then
        local x, y = sm.localPlayer.getMouseDelta()
        if x ~= 0 or y ~= 0 then
            local dir = { x = x, y = y }
            self.network:sendToServer("sv_updateDir", dir)
            self:cl_updateDir(dir)
        end
    end

    --semi functional worldrot
    --local worldRot1 = sm.quat.angleAxis(self.dir.x, vec3_up) * sm.quat.angleAxis(-self.dir.y + math.pi * 0.5, vec3_right)
    self.cl_turret:setRotation(self.shape.worldRotation * sm.quat.angleAxis(self.dir.x, vec3_forward) * sm.quat.angleAxis(-self.dir.y, vec3_right))
end

function TurretBase:cl_syncToLateJoiner(data)
    self:client_onClientDataUpdate(data[1], 1)
    self:client_onClientDataUpdate(data[2], 2)
    self:cl_updateDir(data[3])
end

function TurretBase:client_onClientDataUpdate(data, channel)
    if channel == 1 then
        self.turretRot = self.shape.worldRotation
        self.dir = { x = 0, y = 0 }

        self.cl_turret = data

        self.interactable:setSubMeshVisible("turretpart1", false)
        self.interactable:setSubMeshVisible("turretpart2", false)

        self.seatBroken = false
        self.gunBroken = false
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
            self.seatBroken = false
            self.gunBroken = false

            if g_repairingTurret then
                self:cl_onRepairEnd()
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

function TurretBase:cl_onRepairEnd()
    if not sm.exists(g_repairTool) then return end
    sm.event.sendToTool(g_repairTool, "cl_markUnforce")
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

function TurretBase:cl_checkHighlight()
    if not sm.exists(self.turretHighlight) then
        self.turretHighlight = sm.effect.createEffect("ShapeRenderable", self.cl_turret)
        self.turretHighlight:setParameter("uuid", sm.uuid.new(self.seatHologramUUID))
        self.turretHighlight:setParameter("visualization", true)
        self.turretHighlight:setScale(vec3_one * 0.25)
    end

    local shouldHighlight, isPlaying = sm.game.getCurrentTick() - (self.liftHoverTick or 0) < 2, self.turretHighlight:isPlaying()
    if shouldHighlight and not isPlaying then
        self.turretHighlight:start()
    elseif not shouldHighlight and isPlaying then
        self.turretHighlight:stop()
    end
end

function TurretBase:cl_liftHover()
    self.liftHoverTick = sm.game.getCurrentTick()
end

function TurretBase:cl_onLifted(state)
    self.lifted = state

    if state then
        self.interactable:setSubMeshVisible("turretpart1", true)
        self.interactable:setSubMeshVisible("turretpart2", true)
    else
        self.interactable:setSubMeshVisible("turretpart1", self.seatBroken)
        self.interactable:setSubMeshVisible("turretpart2", self.gunBroken)
    end
end

function TurretBase:cl_n_putOnLift()
    self.network:sendToServer("sv_putOnLift")
end

function TurretBase:cl_putOnLift()
    self.lifted = false
    self.interactable:setSubMeshVisible("turretpart1", self.seatBroken)
    self.interactable:setSubMeshVisible("turretpart2", self.gunBroken)
end



local SpeedPerStep = 1 / math.rad( 27 ) / 3
function TurretBase:client_onFixedUpdate( timeStep )
	if self.bearingSettings.updateDelay > 0.0 then
		self.bearingSettings.updateDelay = math.max( 0.0, self.bearingSettings.updateDelay - timeStep )

		if self.bearingSettings.updateDelay == 0 then
			self:cl_applyBearingSettings()
			self.bearingSettings.updateSettings = {}
			self.bearingSettings.updateGuiCooldown = 0.2
		end
	else
		if self.bearingSettings.updateGuiCooldown then
			self.bearingSettings.updateGuiCooldown = self.bearingSettings.updateGuiCooldown - timeStep
			if self.bearingSettings.updateGuiCooldown <= 0 then
				self.bearingSettings.updateGuiCooldown = nil
			end
		end
		if not self.bearingSettings.updateGuiCooldown then
			self:cl_updateBearingGuiValues()
		end
	end
end

function TurretBase:client_canInteractThroughJoint()
    return self.shape.body.connectable
end

function TurretBase:client_onInteractThroughJoint( character, state, joint )
    self.bearingSettings.bearingGui = sm.gui.createSteeringBearingGui()
    self.bearingSettings.bearingGui:open()
    self.bearingSettings.bearingGui:setOnCloseCallback( "cl_onGuiClosed" )

    self.bearingSettings.currentJoint = joint

    self.bearingSettings.bearingGui:setSliderCallback("LeftAngle", "cl_onLeftAngleChanged")
    self.bearingSettings.bearingGui:setSliderData("LeftAngle", 120, self.interactable:getSteeringJointLeftAngleLimit( joint ) - 1 )

    self.bearingSettings.bearingGui:setSliderCallback("RightAngle", "cl_onRightAngleChanged")
    self.bearingSettings.bearingGui:setSliderData("RightAngle", 120, self.interactable:getSteeringJointRightAngleLimit( joint ) - 1 )

    local leftSpeedValue = self.interactable:getSteeringJointLeftAngleSpeed( joint ) / SpeedPerStep
    local rightSpeedValue = self.interactable:getSteeringJointRightAngleSpeed( joint ) / SpeedPerStep

    self.bearingSettings.bearingGui:setSliderCallback("LeftSpeed", "cl_onLeftSpeedChanged")
    self.bearingSettings.bearingGui:setSliderData("LeftSpeed", 10, leftSpeedValue - 1)

    self.bearingSettings.bearingGui:setSliderCallback("RightSpeed", "cl_onRightSpeedChanged")
    self.bearingSettings.bearingGui:setSliderData("RightSpeed", 10, rightSpeedValue - 1)

    local unlocked = self.interactable:getSteeringJointUnlocked( joint )

    if unlocked then
        self.bearingSettings.bearingGui:setButtonState( "Off", true )
    else
        self.bearingSettings.bearingGui:setButtonState( "On", true )
    end

    self.bearingSettings.bearingGui:setButtonCallback( "On", "cl_onLockButtonClicked" )
    self.bearingSettings.bearingGui:setButtonCallback( "Off", "cl_onLockButtonClicked" )
end

function TurretBase:cl_onLeftAngleChanged( sliderName, sliderPos )
	self.bearingSettings.updateSettings.leftAngle = sliderPos + 1
	self.bearingSettings.updateDelay = 0.1
end

function TurretBase:cl_onRightAngleChanged( sliderName, sliderPos )
	self.bearingSettings.updateSettings.rightAngle = sliderPos + 1
	self.bearingSettings.updateDelay = 0.1
end

function TurretBase:cl_onLeftSpeedChanged( sliderName, sliderPos )
	self.bearingSettings.updateSettings.leftSpeed = ( sliderPos + 1 ) * SpeedPerStep
	self.bearingSettings.updateDelay = 0.1
end

function TurretBase:cl_onRightSpeedChanged( sliderName, sliderPos )
	self.bearingSettings.updateSettings.rightSpeed = ( sliderPos + 1 ) * SpeedPerStep
	self.bearingSettings.updateDelay = 0.1
end

function TurretBase:cl_onLockButtonClicked( buttonName )
	self.bearingSettings.updateSettings.unlocked = buttonName == "Off"
	self.bearingSettings.updateDelay = 0.1
end

function TurretBase:cl_onGuiClosed()
	if self.bearingSettings.updateDelay > 0.0 then
		self:cl_applyBearingSettings()
		self.bearingSettings.updateSettings = {}
		self.bearingSettings.updateDelay = 0.0
		self.bearingSettings.currentJoint = nil
	end
	self.bearingSettings.bearingGui:destroy()
	self.bearingSettings.bearingGui = nil
end

function TurretBase:cl_applyBearingSettings( )

	assert( self.bearingSettings.currentJoint )

	if self.bearingSettings.updateSettings.leftAngle then
		self.interactable:setSteeringJointLeftAngleLimit( self.bearingSettings.currentJoint, self.bearingSettings.updateSettings.leftAngle )
	end

	if self.bearingSettings.updateSettings.rightAngle then
		self.interactable:setSteeringJointRightAngleLimit( self.bearingSettings.currentJoint, self.bearingSettings.updateSettings.rightAngle )
	end

	if self.bearingSettings.updateSettings.leftSpeed then
		self.interactable:setSteeringJointLeftAngleSpeed( self.bearingSettings.currentJoint, self.bearingSettings.updateSettings.leftSpeed )
	end

	if self.bearingSettings.updateSettings.rightSpeed then
		self.interactable:setSteeringJointRightAngleSpeed( self.bearingSettings.currentJoint, self.bearingSettings.updateSettings.rightSpeed )
	end

	if self.bearingSettings.updateSettings.unlocked ~= nil then
		self.interactable:setSteeringJointUnlocked( self.bearingSettings.currentJoint, self.bearingSettings.updateSettings.unlocked )
	end
end

function TurretBase:cl_updateBearingGuiValues()
	if self.bearingSettings.bearingGui and self.bearingSettings.bearingGui:isActive() then

		local leftSpeed, rightSpeed, leftAngle, rightAngle, unlocked = self.interactable:getSteeringJointSettings( self.bearingSettings.currentJoint )

		if leftSpeed and rightSpeed and leftAngle and rightAngle and unlocked ~= nil then
			self.bearingSettings.bearingGui:setSliderPosition( "LeftAngle", leftAngle - 1 )
			self.bearingSettings.bearingGui:setSliderPosition( "RightAngle", rightAngle - 1 )
			self.bearingSettings.bearingGui:setSliderPosition( "LeftSpeed", ( leftSpeed / SpeedPerStep ) - 1 )
			self.bearingSettings.bearingGui:setSliderPosition( "RightSpeed", ( rightSpeed / SpeedPerStep ) - 1 )

			if unlocked then
				self.bearingSettings.bearingGui:setButtonState( "Off", true )
			else
				self.bearingSettings.bearingGui:setButtonState( "On", true )
			end
		end
	end
end



function TurretBase:getSeatPos()
    if not sm.exists(self.cl_turret) then
        return self.shape.worldPosition + self.shape.at * 1.33 + self.shape.velocity * 0.05
    end

    local turretPos = self.cl_turret.worldPosition
    local targetPos = turretPos + self.cl_turret.worldRotation * vec3_forward * 0.8
    return self.shape.worldPosition + self.shape.at * 0.53 + self.shape.velocity * 0.05 + (targetPos - turretPos)
end