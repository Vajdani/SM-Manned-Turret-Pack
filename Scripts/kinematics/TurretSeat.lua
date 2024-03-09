---@class TurretSeat : HarvestableClass
---@field base Interactable
TurretSeat = class()
TurretSeat.poseWeightCount = 3

local ShootState = {
    null = 0,
    hold = 1,
    toggle = 2
}

function TurretSeat:server_onCreate()
    self.shotCounter = 0
    self.base = self.params.base
    self.network:setClientData(self.base, 1)
    self.network:setClientData(self.params.ammoType, 2)

    self.harvestable.publicData = { health = TurretBase.maxHealth }
end

function TurretSeat:server_onUnload()
    sm.event.sendToInteractable(self.cl_base, "sv_respawnSeat")
end

function TurretSeat:server_onRemoved(player)
    local container = self.base:addContainer(5, 1)
    local uuid = sm.uuid.new("e4497545-5f77-4d59-bfbf-ce5692284322")
    sm.container.beginTransaction()
    sm.container.collect(container, uuid, 1)
    sm.container.moveAllToCarryContainer( container, player, sm.item.getShapeDefaultColor(uuid) )
    sm.container.endTransaction()
    self.base:removeContainer(5)

    self.harvestable:destroy()
    self.base.shape:destroyShape()
end

function TurretSeat:sv_seatRespawn(player)
    self.network:sendToClient(player, "cl_seat", player.character)
end

---@param caller Player
function TurretSeat:sv_unSeat(args, caller)
    --self:sv_toggleLight(false)

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
    return self.harvestable.publicData.health >= TurretBase.maxHealth and self.harvestable:getSeatCharacter() == nil
end

function TurretSeat:sv_updateAmmoType(ammoType)
    sm.event.sendToInteractable(self.base, "sv_e_setAmmoType", ammoType)
    self.network:setClientData(ammoType, 2)
end

local rayFilter = sm.physics.filter.dynamicBody + sm.physics.filter.staticBody + sm.physics.filter.terrainAsset + sm.physics.filter.terrainSurface + sm.physics.filter.harvestable
function TurretSeat:sv_shoot(ammoType, caller)
    self.shotCounter = self.shotCounter + 1
    local startPos, endPos = self:getFirePos()
    local rot = self.harvestable.worldRotation
    local hit, result = sm.physics.raycast(startPos, endPos, self.harvestable, rayFilter)
    if hit then
        endPos = result.pointWorld - result.normalWorld * 0.1
    end

    local dir = rot * vec3_up
    local canShoot = self:canShoot(ammoType)
    if canShoot then
        local ammoData = ammoTypes[ammoType]
        sm.projectile.projectileAttack( ammoData.uuid, ammoData.damage, endPos + dir * (hit and 0 or 0.25), sm.noise.gunSpread(dir, ammoData.spread) * ammoData.velocity, caller )
    end

    self.network:sendToClients("cl_shoot", { canShoot = canShoot, pos = endPos, dir = dir, shotCount = self.shotCounter, ammoType = ammoType })
end

function TurretSeat:sv_toggleLight(toggle)
    self.network:sendToClients("cl_toggleLight", toggle)
end



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

    self.harvestable.clientPublicData = { health = TurretBase.maxHealth }
end

function TurretSeat:client_onDestroy()
    self.hotbar:destroy()

    if self.seated then
        sm.localPlayer.getPlayer().clientPublicData.customCameraData = nil
    end
end

function TurretSeat:client_onClientDataUpdate(data, channel)
    if channel == 1 then
        self.cl_base = data
    else
        self.ammoType = data
    end
end

function TurretSeat:client_canErase()
    local canErase = not g_repairingTurret and self.harvestable.clientPublicData.health >= TurretBase.maxHealth and self.harvestable:getSeatCharacter() == nil
    --[[if not canErase then
        sm.gui.setInteractionText("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>Unable to pick up damaged turret</p>")
    end]]

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
    self:cl_seat(char)
end

function TurretSeat:cl_seat(char)
    self.seated = true
    self.harvestable:setSeatCharacter(char)
    self.hotbar:open()
    sm.event.sendToInteractable(self.cl_base, "cl_n_toggleHud", true)
    self.ammoType = self:getAmmoType(self.cl_base:getSingleParent())
    self:cl_updateHotbar()
    sm.camera.setCameraPullback(0,0)
    sm.localPlayer.getPlayer().clientPublicData.customCameraData = { cameraState = 5 }
end

function TurretSeat:cl_unSeat()
    self.shootState = ShootState.null
    self.shootTimer = 0
    self.seated = false
    self.network:sendToServer("sv_unSeat")
    self.hotbar:close()
    sm.event.sendToInteractable(self.cl_base, "cl_n_toggleHud", false)
    sm.localPlayer.getPlayer().clientPublicData.customCameraData = nil
end

function TurretSeat:client_onAction(action, state)
    if self.cl_base.shape.body:isOnLift() then
        if action == 15 then
            self:cl_unSeat()
        end

        return true
    end

    if (action == 5 or action == 19) and self.shootState ~= ShootState.toggle then
        self.shootState = state and ShootState.hold or ShootState.null
        self:cl_updateHotbar()
    end

    if state then
        if action == 6 or action == 18 then
            self.shootState = self.shootState == ShootState.toggle and ShootState.null or ShootState.toggle
            self:cl_updateHotbar()
        elseif action == 7 then
            self.lightActive = not self.lightActive
            self:cl_updateHotbar()
            self.network:sendToServer("sv_toggleLight", self.lightActive)
        elseif action == 8 and not sm.game.getEnableAmmoConsumption() and self.cl_base:getSingleParent() == nil then
            if self.shootState == ShootState.null then
                local ammoType = self.ammoType < #ammoTypes and self.ammoType + 1 or 1
                sm.gui.displayAlertText("Ammunition selected: #df7f00"..ammoTypes[ammoType].name, 2)
                sm.audio.play("PaintTool - ColorPick")

                self.ammoType = ammoType
                self:cl_updateHotbar()

                self.network:sendToServer("sv_updateAmmoType", ammoType)
            end
        elseif action == 15 then
            self:cl_unSeat()
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

    local parent = self.cl_base:getSingleParent()
    if parent ~= self.parent then
        self.ammoType = self:getAmmoType(parent)
        self.parent = parent
    end

    self.shootTimer = math.max(self.shootTimer - 1, 0)
    if self.shootState ~= ShootState.null and self.shootTimer <= 0 then
        self.shootTimer = ammoTypes[self.ammoType].fireCooldown
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
        sm.localPlayer.getPlayer().clientPublicData.customCameraData = { cameraState = 5 }

        local parent = self.cl_base:getSingleParent()
        if parent then
            local container = parent:getContainer(0)
            local uuid = ammoTypes[self.ammoType].ammo
            sm.gui.setInteractionText(("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>%d / %d</p>"):format(sm.container.totalQuantity(container, uuid), container:getSize() * container:getMaxStackSize()))
        end
    end
end

function TurretSeat:cl_updateHotbar()
    self.hotbar:setGridItem( "ButtonGrid", 0, {
        itemId = "1e8d93a4-506b-470d-9ada-9c0a321e2db5",
        active = self.shootState == ShootState.hold
    })

    self.hotbar:setGridItem( "ButtonGrid", 1, {
        itemId = "7cf717d7-d167-4f2d-a6e7-6b2c70aa3986",
        active = self.shootState == ShootState.toggle
    })

    self.hotbar:setGridItem( "ButtonGrid", 2, {
        itemId = "ed27f5e2-cac5-4a32-a5d9-49f116acc6af",
        active = self.lightActive
    })

    if self.ammoType == 0 then
        self.hotbar:setGridItem( "ButtonGrid", 3, {
            itemId = nil,
            active = false
        })
    else
        self.hotbar:setGridItem( "ButtonGrid", 3, {
            itemId = tostring(ammoTypes[self.ammoType].ammo),
            active = false
        })
    end
end

function TurretSeat:cl_shoot(args)
    if args.canShoot then
        if args.shotCount%2==0 then
            self.recoil_l = 1
        else
            self.recoil_r = 1
        end

        sm.effect.playEffect(ammoTypes[args.ammoType].effect, args.pos, vec3_zero, sm.vec3.getRotation(vec3_up, args.dir))
    else
        sm.audio.play("Lever off", args.pos)

        if self.seated then
            self.shootState = ShootState.null
            self:cl_updateHotbar()
        end
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



function TurretSeat:getFirePos()
    local pos = self.harvestable.worldPosition
    local rot = self.harvestable.worldRotation
    if self.shotCounter%2==0 then
        local offsetBase =  vec3_right * 0.27 + vec3_forward * 0.35
        return pos + rot * offsetBase, pos + rot * (vec3_up * 1.8 + offsetBase)
    else
        local offsetBase = -vec3_right * 0.27 + vec3_forward * 0.35
        return pos + rot * offsetBase, pos + rot * (vec3_up * 1.8 + offsetBase)
    end
end

function TurretSeat:getAmmoType(parent)
    if parent then
        return containerToAmmoType[tostring(parent.shape.uuid)]
    end

    if not sm.game.getEnableAmmoConsumption() then
        return self.ammoType
    end

    return 1
end

function TurretSeat:canShoot(ammoType)
    local parent = self.base:getSingleParent()
    if parent then
        sm.container.beginTransaction()
        sm.container.spend(parent:getContainer(0), ammoTypes[ammoType].ammo, 1)
        return sm.container.endTransaction()
    end

    return not sm.game.getEnableAmmoConsumption()
end