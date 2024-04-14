---@class TurretSeat : HarvestableClass
---@field base Interactable
---@field cl_base Interactable
---@field ammoTypes AmmoType[]
---@field overrideAmmoTypes AmmoType[]
---@field containerToAmmoType { string: number }
---@field baseUUID string
TurretSeat = class()
TurretSeat.poseWeightCount = 3
TurretSeat.ammoTypes = {
    {
        name = "AA Rounds",
        damage = 100,
        velocity = 300,
        recoilStrength = 1,
        fireCooldown = 6,
        spread = 5,
        effect = "Turret - Shoot",
        ammo = sm.uuid.new("cabf45e9-a47d-4086-8f5f-4f806d5ec3a2"),
        uuid = sm.uuid.new("fad5bb05-b6da-46ec-92f7-9ffb38bd6c9b")
    },
    {
        name = "Explosive Rounds",
        damage = 10,
        velocity = 130,
        recoilStrength = 1,
        fireCooldown = 15,
        spread = 8,
        effect = "Turret - Shoot",
        ammo = sm.uuid.new("4c69fa44-dd0d-42ce-9892-e61d13922bd2"),
        uuid = projectile_explosivetape
    },
    {
        name = "Water drops",
        damage = 0,
        velocity = 130,
        fireCooldown = 8,
        spread = 0,
        effect = "Mountedwatercanon - Shoot",
        ammo = sm.uuid.new("869d4736-289a-4952-96cd-8a40117a2d28"),
        uuid = projectile_water
    },
    --[[{
        name = "Chemical drops",
        damage = 0,
        velocity = 130,
        fireCooldown = 6,
        spread = 0,
        effect = "Turret - Shoot",
        ammo = "f74c2891-79a9-45e0-982e-4896651c2e25",
        uuid = projectile_pesticide
    },
    {
        name = "Fertilizer drops",
        damage = 0,
        velocity = 130,
        fireCooldown = 6,
        spread = 0,
        effect = "Turret - Shoot",
        ammo = "ac0b5b0a-14e1-4b31-8944-0a351fbfcc67",
        uuid = projectile_fertilizer
    },]]
    {
        name = "Potatoes",
        damage = 56,
        velocity = 200,
        recoilStrength = 0.1,
        fireCooldown = 6,
        spread = 8,
        effect = "SpudgunBasic - BasicMuzzel",
        ammo = sm.uuid.new("bfcfac34-db0f-42d6-bd0c-74a7a5c95e82"),
        uuid = sm.uuid.new("baf7ff9d-191a-4ea4-beba-e160ceb54daf")
    }
}
TurretSeat.overrideAmmoTypes = {}
TurretSeat.containerToAmmoType = {
    ["756594d6-6fdd-4f60-9289-a2416287f942"] = 1,
    ["037e3ecb-e0a6-402b-8187-a7264863c64f"] = 2,
    ["ea10d1af-b97a-46fb-8895-dfd1becb53bb"] = 3,
    --["be29592a-ef58-4b1d-b18c-895023abd27f"] = 4,
    --["76331bbf-abbd-4b8d-bb54-f721a5b6193b"] = 5,
    ["096d4daf-639e-4947-a1a6-1890eaa94464"] = 4,
}
TurretSeat.baseUUID = "e4497545-5f77-4d59-bfbf-ce5692284322"

function TurretSeat:server_onCreate()
    self.shotCounter = 0
    self.base = self.params.base
    self.network:setClientData(self.base, 1)
    self.network:setClientData(self.params.ammoType, 2)

    self.sv_controlsEnabled = true

    self.harvestable.publicData = { health = TurretBase.maxHealth, controlsEnabled = true }
end

function TurretSeat:sv_syncToLateJoiner(player)
    self.network:sendToClient(player, "cl_syncToLateJoiner", { self.base, self.ammoType })
end

function TurretSeat:server_onFixedUpdate()
    if not self.sv_seated then return end

    if not sm.exists(self.sv_seated) then
        self.sv_seated = nil
        return
    end

    local downed = self.sv_seated:isDowned()
    if self.prevDowned ~= downed then
        self.prevDowned = downed

        if downed then
            self:sv_OnPlayerDeath(self.sv_seated:getPlayer())
        end
    end
end

function TurretSeat:sv_OnPlayerDeath(player)
    self:sv_OnPlayerSuddenUnSeated()
    self.network:sendToClient(player, "cl_unSeat_graphics")
end

function TurretSeat:sv_OnPlayerSuddenUnSeated() end

function TurretSeat:server_onUnload()
    if not sm.exists(self.base) then return end
    sm.event.sendToInteractable(self.base, "sv_respawnSeat")
end

---@param player Player
function TurretSeat:server_onRemoved(player)
    local container = self.base:addContainer(5, 1)
    sm.container.beginTransaction()
    sm.container.collect(container, sm.uuid.new(self.baseUUID), 1)
    sm.container.moveAllToCarryContainer( container, player, self.base.shape.color )
    sm.container.endTransaction()
    self.base:removeContainer(5)

    self.harvestable:destroy()
    self.base.shape:destroyShape()
end

function TurretSeat:sv_seatRespawn(player)
    self:sv_seat(nil, player)
    self.network:sendToClient(player, "cl_seat_partial")
end

---@param caller Player
function TurretSeat:sv_seat(args, caller)
    local char = caller.character
    self.harvestable:setSeatCharacter(char)
    self.sv_seated = char

    caller.publicData = caller.publicData or {}
    caller.publicData.turretSeat = self.harvestable
end

---@param caller Player
function TurretSeat:sv_unSeat(args, caller)
    --self:sv_toggleLight(false)

    self.sv_seated = nil
    self.harvestable:setSeatCharacter(caller.character)

    local rot = self.harvestable.worldRotation
    local yaw, pitch = getYawPitch(rot * vec3_up)
    caller:setCharacter(
        sm.character.createCharacter(
            caller, sm.world.getCurrentWorld(),
            self.harvestable.worldPosition + rot * (-vec3_up * 0.15 + vec3_forward),
            yaw, pitch
        )
    )

    caller.publicData.turretSeat = nil
	sm.event.sendToInteractable(self.base, "sv_clearDrivingFlags", false)
end

---@param player Player
function TurretSeat:sv_unSeat_event(player)
    self:sv_unSeat(nil, player)
    self.network:sendToClient(player, "cl_unSeat_graphics")
end

function TurretSeat:server_onProjectile(position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid)
    sm.event.sendToInteractable(self.base, "sv_takeDamage", damage)
end

function TurretSeat:server_onMelee(position, attacker, damage, power, direction, normal)
    sm.event.sendToInteractable(self.base, "sv_takeDamage", damage)
end

function TurretSeat:server_onExplosion(center, destructionLevel)
    sm.event.sendToInteractable(self.base, "sv_takeDamage", destructionLevel * 25)
end

function TurretSeat:server_canErase()
    return self.harvestable.publicData.health >= TurretBase.maxHealth and self.sv_seated == nil
end

function TurretSeat:sv_updateAmmoType(ammoType)
    if not self.sv_controlsEnabled then return end

    sm.event.sendToInteractable(self.base, "sv_e_setAmmoType", ammoType)
    self.network:setClientData(ammoType, 2)
end

local rayFilter = sm.physics.filter.dynamicBody + sm.physics.filter.staticBody + sm.physics.filter.terrainAsset + sm.physics.filter.terrainSurface + sm.physics.filter.harvestable
function TurretSeat:sv_shoot(ammoType, caller)
    if not self.sv_controlsEnabled then return end

    self.shotCounter = self.shotCounter + 1

    local ammoData = self:getAmmoData(ammoType)
    local startPos, endPos = self:getFirePos()
    local rot = self.harvestable.worldRotation
    local hit, result = sm.physics.spherecast(startPos, endPos, 0.1, self.harvestable, rayFilter)
    if hit then
        self.network:sendToClients("cl_shoot", { canShoot = false, pos = endPos })
        return
    end

    local dir = rot * vec3_up
    local canShoot = self:canShoot(ammoType, true) or ammoData.ignoreAmmoConsumption
    if canShoot then
        local finalFirePos
        if sm.item.isPart(ammoData.uuid) then
            local projectileRot = rot * turret_projectile_rotation_adjustment
            finalFirePos = endPos - projectileRot * sm.item.getShapeOffset(ammoData.uuid)
            local projectile = sm.shape.createPart(ammoData.uuid, finalFirePos, projectileRot)

            if ammoData.velocity then
                sm.physics.applyImpulse(projectile, dir * projectile.mass * ammoData.velocity, true)
            end

            self:sv_OnPartFire(ammoType, ammoData, projectile, caller)
        else
            finalFirePos = endPos + dir * (hit and 0 or 0.25)
            sm.projectile.projectileAttack( ammoData.uuid, ammoData.damage, finalFirePos, sm.noise.gunSpread(dir, ammoData.spread) * ammoData.velocity, caller )
        end

        self:sv_applyFiringImpulse(ammoData, dir, finalFirePos)
    end

    self.network:sendToClients("cl_shoot", { canShoot = canShoot, pos = endPos, dir = dir, shotCount = self.shotCounter, ammoType = ammoType })
end

function TurretSeat:sv_applyFiringImpulse(ammoData, dir, finalFirePos)
    if ammoData.recoilStrength then
        local baseShape = self.base.shape
        sm.physics.applyImpulse(baseShape, -dir * ammoData.recoilStrength * baseShape.mass, true, baseShape:transformPoint(finalFirePos))
    end
end

function TurretSeat:sv_toggleLight(toggle)
    if not self.sv_controlsEnabled then return end
    self.network:sendToClients("cl_toggleLight", toggle)
end

function TurretSeat:sv_SetTurretControlsEnabled(state)
    self.sv_controlsEnabled = state
    self.harvestable.publicData.controlsEnabled = state
    self.network:sendToClients("cl_SetTurretControlsEnabled", state)
end

function TurretSeat:sv_setOverrideAmmoType(id)
    local previous = self:isOverrideAmmoType() and self.ammoType.previous or self.ammoType
    self:sv_updateAmmoType({ index = id, previous = previous })
end

function TurretSeat:sv_unSetOverrideAmmoType()
    self:sv_updateAmmoType(self.ammoType.previous)
end

---@param ammoType number
---@param ammoData AmmoType
---@param part Shape
---@param player Player
function TurretSeat:sv_OnPartFire(ammoType, ammoData, part, player) end



function TurretSeat:client_onCreate()
    self.hotbar = sm.gui.createSeatGui()

    self.shootState = ShootState.null
    self.shootTimer = 0
    self.ammoType = 1

    self.recoil_l = 0
    self.recoil_r = 0

    self.lightEffect = sm.effect.createEffect("HeadLight", self.harvestable)
    self.lightEffect:setOffsetPosition(vec3_up - vec3_forward * 0.325)
    self:cl_toggleLight(false)

    self.seated = false
    self.cl_controlsEnabled = true

    self.harvestable.clientPublicData = { health = TurretBase.maxHealth, controlsEnabled = true }
end

function TurretSeat:client_onDestroy()
    self.hotbar:destroy()

    if self.seated then
        sm.localPlayer.getPlayer().clientPublicData.interactableCameraData = nil
    end
end

function TurretSeat:cl_syncToLateJoiner(data)
    self:client_onClientDataUpdate(data[1], 1)
    self:client_onClientDataUpdate(data[2], 2)
end

function TurretSeat:client_onClientDataUpdate(data, channel)
    if channel == 1 then
        self.cl_base = data
        self.harvestable.clientPublicData.base = data
    else
        self.ammoType = data

        if self.seated then --Override fix
            self:cl_updateHotbar()
        end
    end
end

function TurretSeat:client_canErase()
    local canErase = not g_repairingTurret and self.harvestable.clientPublicData.health >= TurretBase.maxHealth and self.harvestable:getSeatCharacter() == nil
    if not canErase then
        sm.gui.setInteractionText("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>Unable to pick up turret</p>")
    end

    return canErase
end

function TurretSeat:client_canInteract()
    local canInteract = self.harvestable:getSeatCharacter() == nil
    if canInteract then
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use", true), "#{INTERACTION_USE}")
    else
        sm.gui.setInteractionText("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>#{ALERT_DRIVERS_SEAT_OCCUPIED}</p>")
    end

    local health = self.harvestable.clientPublicData.health
    local canRepair = health < TurretBase.maxHealth
    if canRepair then
        sm.gui.setInteractionText("", getHealthDisplay(health))
    end

    return canInteract and not g_repairingTurret
end

function TurretSeat:client_onInteract(char, state)
    if not state then return end
    self:cl_seat()
end

function TurretSeat:cl_seat()
    self.network:sendToServer("sv_seat")
    self:cl_seat_partial()
end

function TurretSeat:cl_seat_partial()
    self.seated = true
    self.hotbar:open()
    self.ammoType = self:getAmmoType(self.cl_base:getSingleParent())
    self:cl_updateHotbar()
    sm.event.sendToInteractable(self.cl_base, "cl_n_toggleHud", true)
    sm.camera.setCameraPullback(0,0)
    sm.localPlayer.getPlayer().clientPublicData.interactableCameraData = { cameraState = 5 }
end

function TurretSeat:cl_unSeat()
    self.network:sendToServer("sv_unSeat")
    self:cl_unSeat_graphics()
end

function TurretSeat:cl_unSeat_graphics()
    self.shootState = ShootState.null
    self.shootTimer = 0
    self.seated = false
    self.hotbar:close()
    sm.event.sendToInteractable(self.cl_base, "cl_n_toggleHud", false)
    sm.localPlayer.getPlayer().clientPublicData.interactableCameraData = nil
end

function TurretSeat:client_onAction(action, state)
    if not self.cl_controlsEnabled then return true end

    if self.cl_base.shape.body:isOnLift() then
        if state and action == 15 then
            self:cl_unSeat()
        end

        return true
    end

    if (action == 5 or action == 19) and self.shootState ~= ShootState.toggle then
        self.shootState = state and ShootState.hold or ShootState.null
        self:cl_updateHotbar()
    end

    if state then
        if action == 1 then
			self.cl_base:setSteeringFlag( 1 )
		elseif action == 2 then
			self.cl_base:setSteeringFlag( 2 )
        elseif action == 3 then
			self.cl_base:setSteeringFlag( 4 )
		elseif action == 4 then
			self.cl_base:setSteeringFlag( 8 )
        elseif action == 6 or action == 18 then
            self.shootState = self.shootState == ShootState.toggle and ShootState.null or ShootState.toggle
            self:cl_updateHotbar()
        elseif action == 7 then
            self.lightActive = not self.lightActive
            self:cl_updateHotbar()
            self.network:sendToServer("sv_toggleLight", self.lightActive)
        elseif action == 8 then
            if self:isOverrideAmmoType() then
                return true
            end

            if #self.ammoTypes > 1 and not sm.game.getEnableAmmoConsumption() and self.cl_base:getSingleParent() == nil then
                if self.shootState == ShootState.null then
                    local ammoType = self.ammoType < #self.ammoTypes and self.ammoType + 1 or 1
                    sm.gui.displayAlertText("Ammunition selected: #df7f00"..self:getAmmoData(ammoType).name, 2)
                    sm.audio.play("PaintTool - ColorPick")

                    self.ammoType = ammoType
                    self:cl_updateHotbar()

                    self.network:sendToServer("sv_updateAmmoType", ammoType)
                end
            end
        elseif action == 15 then
            self:cl_unSeat()
        end
    else
        if action == 1 then
			self.cl_base:unsetSteeringFlag( 1 )
		elseif action == 2 then
			self.cl_base:unsetSteeringFlag( 2 )
        elseif action == 3 then
			self.cl_base:unsetSteeringFlag( 4 )
		elseif action == 4 then
			self.cl_base:unsetSteeringFlag( 8 )
        end
    end

    return true
end

function TurretSeat:client_onFixedUpdate()
    if not sm.exists(self.cl_base) then return end

    local col = self.cl_base.shape.color
    if self.col ~= col then
        self.col = col
        self.harvestable:setColor(col)
    end

    if not self.seated then return end

    if self.cl_base.body:isOnLift() and self.shootState ~= ShootState.null then
        self.shootState = ShootState.null
        self:cl_updateHotbar()
    end

    local parent = self.cl_base:getSingleParent()
    if parent ~= self.parent then
        self.ammoType = self:getAmmoType(parent)
        self.parent = parent
    end

    self.shootTimer = math.max(self.shootTimer - 1, 0)
    if self.shootState ~= ShootState.null and self.shootTimer <= 0 then
        self.shootTimer = self:getAmmoData().fireCooldown
        self.network:sendToServer("sv_shoot", self.ammoType)
    end
end

function TurretSeat:client_onUpdate(dt)
    if not sm.exists(self.cl_base) then return end

    local speed = dt * 7.5
    self.recoil_l = math.max(self.recoil_l - speed, 0)
    self.harvestable:setPoseWeight(0, sm.util.easing("easeOutCubic", self.recoil_l))

    self.recoil_r = math.max(self.recoil_r - speed, 0)
    self.harvestable:setPoseWeight(1, sm.util.easing("easeOutCubic", self.recoil_r))

    if self.seated then
        sm.localPlayer.getPlayer().clientPublicData.interactableCameraData = { cameraState = 5 }

        self:cl_displayAmmoInfo()
    end
end

function TurretSeat:cl_updateHotbar()
    self.hotbar:setGridItem( "ButtonGrid", 0, {
        itemId = HotbarIcon.shoot,
        active = self.shootState == ShootState.hold
    })

    self.hotbar:setGridItem( "ButtonGrid", 1, {
        itemId = HotbarIcon.shoot_toggle,
        active = self.shootState == ShootState.toggle
    })

    self.hotbar:setGridItem( "ButtonGrid", 2, {
        itemId = HotbarIcon.light,
        active = self.lightActive
    })

    if self.ammoType == 0 then
        self.hotbar:setGridItem( "ButtonGrid", 3, {
            itemId = nil,
            active = false
        })
    else
        self.hotbar:setGridItem( "ButtonGrid", 3, {
            itemId = tostring(self:getAmmoData().ammo),
            active = false
        })
    end
end

function TurretSeat:cl_displayAmmoInfo()
    local ammoData = self:getAmmoData()
    if ammoData.ignoreAmmoConsumption then return end

    local parent = self.cl_base:getSingleParent()
    if parent then
        local container = parent:getContainer(0)
        sm.gui.setInteractionText(("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>%d / %d</p>"):format(sm.container.totalQuantity(container, ammoData.uuid), container:getSize() * container:getMaxStackSize()))
    elseif sm.game.getEnableAmmoConsumption() then
        sm.gui.setInteractionText(("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>No ammunition</p>"))
    end
end

function TurretSeat:cl_shoot(args)
    if args.canShoot then
        if args.shotCount%2==0 then
            self.recoil_l = 1
        else
            self.recoil_r = 1
        end

        sm.effect.playEffect(self:getAmmoData(args.ammoType).effect, args.pos, vec3_zero, sm.vec3.getRotation(vec3_up, args.dir))
    else
        sm.effect.playEffect("Turret - FailedShoot", args.pos)
    end
end

function TurretSeat:cl_toggleLight(toggle)
    if toggle then
        self.lightEffect:start()
    else
        self.lightEffect:stop()
    end

    self.lightActive = toggle
    self.harvestable:setUvFrameIndex(toggle and 1 or 0)
end

function TurretSeat:cl_SetTurretControlsEnabled(state)
    self.cl_controlsEnabled = state
    self.harvestable.clientPublicData.controlsEnabled = state

    if self.seated and self.shootState ~= ShootState.null then
        self.shootState = ShootState.null
        self:cl_updateHotbar()
    end
end



function TurretSeat:getFirePos()
    local pos = self.harvestable.worldPosition + (self.base or self.cl_base).shape.velocity * 0.025
    local rot = self.harvestable.worldRotation
    if self.shotCounter%2==0 then
        local offsetBase =  vec3_right * 0.27 + vec3_forward * 0.35
        return pos + rot * offsetBase, pos + rot * (vec3_up * 1.7 + offsetBase)
    else
        local offsetBase = -vec3_right * 0.27 + vec3_forward * 0.35
        return pos + rot * offsetBase, pos + rot * (vec3_up * 1.7 + offsetBase)
    end
end

function TurretSeat:isOverrideAmmoType(ammoType)
    return type(ammoType or self.ammoType) == "table"
end

function TurretSeat:getAmmoType(parent)
    if self:isOverrideAmmoType() then
        return self.ammoType
    end

    if parent then
        return self.containerToAmmoType[tostring(parent.shape.uuid)]
    end

    if not sm.game.getEnableAmmoConsumption() then
        return self.ammoType
    end

    return 1
end

function TurretSeat:getAmmoData(ammoType)
    ammoType = ammoType or self.ammoType
    if self:isOverrideAmmoType(ammoType) then
        return self.overrideAmmoTypes[ammoType.index]
    end

    return self.ammoTypes[ammoType]
end

function TurretSeat:canShoot(ammoType, consume)
    local parent = (self.base or self.cl_base):getSingleParent()
    if parent then
        if consume then
            sm.container.beginTransaction()
            sm.container.spend(parent:getContainer(0), self:getAmmoData(ammoType).ammo, 1)
            return sm.container.endTransaction()
        else
            return parent:getContainer(0):canSpend(self:getAmmoData(ammoType).ammo, 1)
        end
    end

    return not sm.game.getEnableAmmoConsumption()
end