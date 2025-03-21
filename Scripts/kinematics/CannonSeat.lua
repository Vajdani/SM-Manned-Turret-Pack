dofile "TurretSeat.lua"
dofile "$CONTENT_DATA/Scripts/ControlHud.lua"

---@class CannonSeat : TurretSeat
CannonSeat = class(TurretSeat)
CannonSeat.ammoTypes = {
    {
        name = "Guided Missile",
        velocity = 100,
        recoilStrength = 1,
        fireCooldown = 40,
        effect = "Cannon - Shoot",
        ammo = sm.uuid.new("24d5e812-3902-4ac3-b214-a0c924a5c40f"),
        uuid = sm.uuid.new("24d5e812-3902-4ac3-b214-a0c924a5c40f")
    },
    {
        name = "Air Strike",
        recoilStrength = 1,
        fireCooldown = 40,
        effect = "Cannon - Shoot",
        ammo = sm.uuid.new("4c69fa44-dd0d-42ce-9892-e61d13922bd2"),
        uuid = projectile_explosivetape
    },
    {
        name = "Ratshot",
        damage = 50,
        velocity = 250,
        recoilStrength = 3,
        fireCooldown = 40,
        spread = 0,
        effect = "Cannon - Shoot",
        ammo = sm.uuid.new("e36b172c-ae2d-4697-af44-8041d9cbde0e"),
        uuid = sm.uuid.new("53e5da10-99ea-48d5-98b5-c03d0938811e")
    },
    {
        name = "Player Launcher",
        velocity = 75,
        recoilStrength = 1,
        fireCooldown = 40,
        effect = "Cannon - Shoot",
        ammo = sm.uuid.new( HotbarIcon.pLauncher ),
        ignoreAmmoConsumption = true
    }
}
CannonSeat.overrideAmmoTypes = {
    {
        name = "Nuke",
        velocity = 100,
        recoilStrength = 3,
        fireCooldown = 40,
        effect = "Cannon - Shoot",
        ammo = sm.uuid.new("47b43e6e-280d-497e-9896-a3af721d89d2"),
        uuid = sm.uuid.new("47b43e6e-280d-497e-9896-a3af721d89d2"),
        ignoreAmmoConsumption = true
    },
    {
        name = "Large Explosive Canister",
        velocity = 50,
        recoilStrength = 3,
        fireCooldown = 40,
        effect = "Cannon - Shoot",
        ammo = sm.uuid.new("24001201-40dd-4950-b99f-17d878a9e07b"),
        uuid = sm.uuid.new("24001201-40dd-4950-b99f-17d878a9e07b"),
        ignoreAmmoConsumption = true
    },
    {
        name = "Small Explosive Canister",
        velocity = 150,
        recoilStrength = 1,
        fireCooldown = 40,
        effect = "Cannon - Shoot",
        ammo = sm.uuid.new("8d3b98de-c981-4f05-abfe-d22ee4781d33"),
        uuid = sm.uuid.new("8d3b98de-c981-4f05-abfe-d22ee4781d33"),
        ignoreAmmoConsumption = true
    },
    {
        name = "Big Potato",
        damage = 100,
        velocity = 60,
        recoilStrength = 1,
        fireCooldown = 40,
        effect = "Cannon - Shoot",
        ammo = sm.uuid.new("254360f7-ba19-431d-ac1a-92c1ee9ba483"),
        uuid = sm.uuid.new("a385b242-ce0c-4e3b-82a7-99da38510709"),
        ignoreAmmoConsumption = true
    }
}
CannonSeat.containerToAmmoType = {
    ["d9e6453a-2e8c-47f8-a843-d0e700957d39"] = 1,
    ["037e3ecb-e0a6-402b-8187-a7264863c64f"] = 2,
    ["da615034-dd24-4090-ba66-9d36785d7483"] = 3,
}
CannonSeat.baseUUID = "a0c96d35-37ca-4cf9-82d8-9b9077132918"
CannonSeat.airStrikeDistanceLimit = 256
CannonSeat.maxZoom = 5
CannonSeat.beaconScale = sm.vec3.new(0.5, 50, 0.5)



function CannonSeat:server_onCreate()
    TurretSeat.server_onCreate(self)

    self.harvestable.publicData.rocketRoll = 0
    self.harvestable.publicData.rocketBoost = 0
    self.rocketControls = { [1] = false, [2] = false, [3] = false, [4] = false }
end

function CannonSeat:server_onDestroy()
    if self.rocket and sm.exists(self.rocket) then
        sm.event.sendToInteractable(self.rocket.interactable, "sv_explode")
    end

    if sm.exists(self.base) and sm.isOverrideAmmoType(self) then
        sm.event.sendToInteractable(self.base, "sv_spawnNukeOnDestroy", self.ammoType)
    end
end

function CannonSeat:server_onFixedUpdate()
    TurretSeat.server_onFixedUpdate(self)

    if self.airStrike then
        if self.airStrike:tick() then
            self.airStrike = nil
            self:sv_endAirStrike()
        end
    end
end

function CannonSeat:sv_OnPlayerSuddenUnSeated()
    self:sv_detonateRocket()

    if self.airStrike then
        self:sv_cancelAirStrike()
    end
end

function CannonSeat:sv_rocketRollUpdate(data)
    self.rocketControls[data.action] = data.state
    self.harvestable.publicData.rocketRoll = BoolToNum(self.rocketControls[2]) - BoolToNum(self.rocketControls[1])
end

function CannonSeat:sv_rocketBoostUpdate(data)
    self.rocketControls[data.action] = data.state
    self.harvestable.publicData.rocketBoost = BoolToNum(self.rocketControls[3]) - BoolToNum(self.rocketControls[4])
end

function CannonSeat:sv_OnPartFire(ammoType, ammoData, part, player)
    if ammoType == 1 then --Guided Missile
        part.interactable.publicData = { owner = player, seat = self.harvestable }
        self.rocket = part
        self:sv_SetTurretControlsEnabled(false)
        sm.event.sendToInteractable(self.base, "sv_clearDrivingFlags", true)
    elseif sm.isOverrideAmmoType(self, ammoType) then
        self:sv_unSetOverrideAmmoType()
        self.network:sendToClients("cl_updateLoadedNuke", false)
    end
end

function CannonSeat:sv_OnProjectileFire(ammoType, ammoData, player)
    if sm.isOverrideAmmoType(self, ammoType) then
        self:sv_unSetOverrideAmmoType()
        self.network:sendToClients("cl_updateLoadedNuke", false)
    end
end

function CannonSeat:sv_onRocketExplode(detonated)
    self.rocket = nil
    self.harvestable.publicData.rocketRoll = 0
    self.harvestable.publicData.rocketBoost = 0
    self.rocketControls = { [1] = false, [2] = false, [3] = false, [4] = false }
    self:sv_SetTurretControlsEnabled(true)
    self.network:sendToClient(self.sv_seated:getPlayer(), "cl_onRocketExplode", detonated)
end

function CannonSeat:sv_detonateRocket()
    if self.rocket == nil or not sm.exists(self.rocket) then return end

    sm.event.sendToInteractable(self.rocket.interactable, "sv_explode")
    self.rocket = nil
end

function CannonSeat:sv_startAirStrikeCasting()
    sm.event.sendToInteractable(self.base, "sv_clearDrivingFlags", true)
    self:sv_SetTurretControlsEnabled(false)
end

function CannonSeat:sv_startAirStrike(pos, caller)
    local shape = self.base.shape
    local dir = (pos - shape.worldPosition):normalize()
    local fwd = shape.up
    sm.event.sendToInteractable(self.base, "sv_setDirTarget", { x = math.acos(dir:dot(fwd)) * (dir:cross(fwd).z >= 0 and -1 or 1), y = 1.05 })

    local strike = {
        turretSelf = self,
        position = pos + vec3_up * 100,
        currentTick = 0,
        delay = 0,
        circleCounter = 1,
        angleOffset = math.random(-5, 5) * 60,
        spinDirection = 1,
        tick = function(self)
            self.delay = self.delay + 1
            if self.delay < 10 then return false end

            self.turretSelf.network:sendToClients("cl_shoot", { canShoot = true })
            if not self:fire(self.position + vec3_right:rotate(math.rad(self.angleOffset + self.currentTick * 30 * self.spinDirection), vec3_up) * 3 * self.circleCounter) then
                return true
            end
            self.currentTick = self.currentTick + 1
            self.delay = 0

            if self.currentTick%12 == 0 then
                self.angleOffset = math.random(-5, 5) * 60
                self.spinDirection = self.spinDirection == 1 and -1 or 1
                self.circleCounter = self.circleCounter + 1
            end

            return self.circleCounter > 4
        end,
        start = function(self)
            self:fire(self.position) --One ammo check is already done to start firing
            if not self:fire(self.position) then return true end
        end,
        fire = function(self, position)
            local turretSelf = self.turretSelf
            if not turretSelf:canShoot(2) then
                return false
            end

            sm.projectile.projectileAttack(projectile_explosivetape, 100, position, -vec3_up * 100, caller)
            turretSelf:sv_applyFiringImpulse(sm.GetTurretAmmoData(turretSelf, 2), turretSelf.harvestable.worldRotation * vec3_up, turretSelf:getFirePosEnd())
            return true
        end
    }

    if not strike:start() then
        self.airStrike = strike
        self.network:sendToClients("cl_updateAirStrikeBeacon", pos)
    end
end

function CannonSeat:sv_endAirStrike()
    self:sv_SetTurretControlsEnabled(true)
    self.network:sendToClients("cl_updateAirStrikeBeacon")
end

function CannonSeat:sv_cancelAirStrike()
    self.airStrike = nil
    self:sv_endAirStrike()
end

function CannonSeat:sv_launchPlayer(args, caller)
    self:sv_unSeat_event(caller)
    sm.event.sendToHarvestable(self.harvestable, "sv_tryLaunchPlayer", caller)
end

---@param player Player
function CannonSeat:sv_tryLaunchPlayer(player)
    local char = player.character
    if not sm.exists(char) then
        sm.event.sendToHarvestable(self.harvestable, "sv_tryLaunchPlayer", player)
        return
    end

    char:setWorldPosition(self:getFirePosEnd())
    char:setTumbling(true)
    char:applyTumblingImpulse(self.harvestable.worldRotation * vec3_up * sm.GetTurretAmmoData(self).velocity * char.mass)

    self.network:sendToClients("cl_shoot", { canShoot = true, ammoType = self.ammoType })
end

local itemToOverrideAmmoType = {
    ["47b43e6e-280d-497e-9896-a3af721d89d2"] = 1,
    ["24001201-40dd-4950-b99f-17d878a9e07b"] = 2,
    ["8d3b98de-c981-4f05-abfe-d22ee4781d33"] = 3,
    ["254360f7-ba19-431d-ac1a-92c1ee9ba483"] = 4,
}
function CannonSeat:sv_loadNuke(item)
    self:sv_setOverrideAmmoType(itemToOverrideAmmoType[tostring(item)])
end



function CannonSeat:client_onCreate()
    TurretSeat.client_onCreate(self)

    self.strikeMoveControls = { [1] = false, [2] = false, [3] = false, [4] = false }
    self.controlHud = ControlHud():init(4, 1/23)
end

function CannonSeat:client_onDestroy()
    TurretSeat.client_onDestroy(self)

    self.controlHud:destroy()

    if sm.exists(self.airStrikeRadius) then
        self.airStrikeRadius:destroy()
    end
end

function CannonSeat:client_onClientDataUpdate(data, channel)
    TurretSeat.client_onClientDataUpdate(self, data, channel)

    if channel == 2 then
        if sm.isOverrideAmmoType(self, data) then
            self:cl_updateLoadedNuke(true)
        end
    end
end

function CannonSeat:client_onAction(action, state)
    if self.ammoType == 1 then
        if not self.cl_controlsEnabled then
            if (action == 1 or action == 2) then
                self.network:sendToServer("sv_rocketRollUpdate", { action = action, state = state })
            end

            if (action == 3 or action == 4) then
                self.network:sendToServer("sv_rocketBoostUpdate", { action = action, state = state })
            end

            if state and (action == 5 or action == 19) then
                self.network:sendToServer("sv_detonateRocket")
            end

            return true
        end
    elseif self.ammoType == 2 then
        if self.strikeMoveControls[action] ~= nil then
            self.strikeMoveControls[action] = state
        end

        if state then
            if self.spottingStrike then
                self:cl_strikeControls(action)
                return true
            elseif (action == 5 or action == 19 or action == 6 or action == 18) and self:canShoot(self.ammoType) then
                self:cl_startAirStrike()
                return true
            end

            if self.blockStrikeCast then return true end
        elseif self.spottingStrike then
            return true
        end
    elseif self.ammoType == 4 then
        if state and (action == 5 or action == 19 or action == 6 or action == 18) then
            sm.gui.startFadeToBlack(1.0, 0.5)
            sm.gui.endFadeToBlack(0.8)
            self.network:sendToServer("sv_launchPlayer")
            return true
        end
    end

    return TurretSeat.client_onAction(self, action, state)
end

function CannonSeat:client_onUpdate(dt)
    if not sm.exists(self.cl_base) then return end

    local speed = dt * 5
    self.recoil_l = math.max(self.recoil_l - speed, 0)
    self.harvestable:setPoseWeight(0, sm.util.easing("easeOutCubic", self.recoil_l))

    if self.seated then
        if self.spottingStrike then
            local horizontal = BoolToNum(self.strikeMoveControls[2]) - BoolToNum(self.strikeMoveControls[1])
            local veritcal = BoolToNum(self.strikeMoveControls[3]) - BoolToNum(self.strikeMoveControls[4])

            self.strikeCamOffset = self.strikeCamOffset + (vec3_forward * veritcal + vec3_right * horizontal):safeNormalize(vec3_zero) * dt * 10 * self.strikeZoom^2
            local distance = self.strikeCamOffset:length()
            if distance >= self.airStrikeDistanceLimit then
                self.strikeCamOffset = self.strikeCamOffset * (self.airStrikeDistanceLimit / distance)
            end

            SetPlayerCamOverride({
                cameraState = 3,
                cameraFov = 45,
                cameraPosition = self:getStrikeCamPos(dt),
                cameraDirection = -vec3_up
            })

            local base = self.cl_base.shape
            self.airStrikeRadius:setPosition(base:getInterpolatedWorldPosition() + base.velocity * dt)
            self.airStrikeBaseMarker:setScale(vec3_one * self.strikeZoom)
        elseif self.cl_controlsEnabled then
            SetPlayerCamOverride({ cameraState = 5 })

            self:cl_displayAmmoInfo()
        end

        if self.controlHud:isActive() then
            self.controlHud:update(dt)
        end
    end
end

function CannonSeat:getFirePos()
    local pos = self:getTurretPosition()
    local rot = self.harvestable.worldRotation
    local offsetBase = vec3_forward * 0.22
    return pos + rot * offsetBase, pos + rot * (vec3_up * 2 + offsetBase)
end

local strikeFilter = sm.physics.filter.staticBody + sm.physics.filter.dynamicBody + sm.physics.filter.terrainAsset + sm.physics.filter.terrainSurface
function CannonSeat:getStrikeCamPos(dt)
    local baseShape = self.cl_base.shape
    local basePos = baseShape:getInterpolatedWorldPosition() + baseShape.velocity * (dt or 0) + self.strikeCamOffset
    local hit, result = sm.physics.raycast(basePos + vec3_up * 1000, basePos, baseShape, strikeFilter)
    if hit then
        return result.pointWorld + vec3_up * 10 * self.strikeZoom^2
    end

    return basePos + vec3_up * 10 * self.strikeZoom^2
end

function CannonSeat:cl_strikeControls(action)
    if not self.blockStrikeCast and (action == 5 or action == 19) then
        local camPos = sm.camera.getPosition()
        local hit, result = sm.physics.raycast(camPos, camPos - vec3_up * 1000)
        self.network:sendToServer("sv_startAirStrike", result.pointWorld)
        self.blockStrikeCast = true
    elseif action == 6 then
        self:cl_cancelAirStrike()
    elseif action == 7 then
        if self.strikeZoom > 1 then
            self.strikeZoom = self.strikeZoom - 1
            sm.audio.play("ConnectTool - Rotate", self:getStrikeCamPos())
        end
    elseif action == 8 then
        if self.strikeZoom < self.maxZoom then
            self.strikeZoom = self.strikeZoom + 1
            sm.audio.play("ConnectTool - Rotate", self:getStrikeCamPos())
        end
    end
end

function CannonSeat:cl_shoot(args)
    if args.canShoot then
        self.recoil_l = 1

        local ammoType = args.ammoType or self.ammoType
        sm.effect.playEffect(sm.GetTurretAmmoData(self, ammoType).effect, args.pos or self:getFirePosEnd(), vec3_zero, sm.vec3.getRotation(vec3_up, args.dir or self.harvestable.worldRotation * vec3_up))

        if self.seated and ammoType == 1 then
			sm.audio.play("Blueprint - Build")
            sm.gui.startFadeToBlack(1.0, 0.5)
			sm.gui.endFadeToBlack(0.8)
            sm.event.sendToInteractable(self.cl_base, "cl_n_toggleHud", { false, true })

            self.hotbar:setGridItem( "ButtonGrid", 0, {
                itemId = HotbarIcon.shoot,
                active = false
            })
            self.hotbar:setGridItem( "ButtonGrid", 1, nil)
            self.hotbar:setGridItem( "ButtonGrid", 2, nil)
            self.hotbar:setGridItem( "ButtonGrid", 3, nil)

            local rot = self.harvestable.worldRotation
            SetPlayerCamOverride({
                cameraState = 3,
                cameraFov = 45,
                cameraPosition = sm.camera.getPosition() + rot * vec3_up * 0.25,
                cameraRotation = rot * turret_projectile_rotation_adjustment
            })

            self.controlHud:open()
        end
    else
        sm.effect.playEffect("Turret - FailedShoot", args.pos)
    end
end

function CannonSeat:cl_startAirStrike()
    if self.blockStrikeCast then return end

    local parent = self.cl_base:getSingleParent()
    if parent and not parent:getContainer(0):canSpend(sm.GetTurretAmmoData(self, 2).ammo, 1) then
        self:cl_shoot({ canShoot = false })
        return true
    end

    self.network:sendToServer("sv_startAirStrikeCasting")
    sm.gui.startFadeToBlack(1.0, 0.5)
    sm.gui.endFadeToBlack(0.8)
    sm.event.sendToInteractable(self.cl_base, "cl_n_toggleHud", { false, true })

    self.hotbar:setGridItem( "ButtonGrid", 0, {
        itemId = HotbarIcon.shoot,
        active = false
    })
    self.hotbar:setGridItem( "ButtonGrid", 1, {
        itemId = HotbarIcon.cancel,
        active = false
    })
    self.hotbar:setGridItem( "ButtonGrid", 2, {
        itemId = HotbarIcon.zoomOut,
        active = false
    })
    self.hotbar:setGridItem( "ButtonGrid", 3, {
        itemId = HotbarIcon.zoomIn,
        active = false
    })

    self.controlHud:open()

    self.airStrikeRadius = sm.effect.createEffect("Cannon - AirStrike - Radius")
    self.airStrikeRadius:setRotation(quat_right_90deg)
    self.airStrikeRadius:setScale(vec3_one * self.airStrikeDistanceLimit)
    self.airStrikeRadius:start()

    self.airStrikeBaseMarker = sm.effect.createEffect("Cannon - AirStrike - Radius", self.cl_base)
    self.airStrikeBaseMarker:setScale(vec3_one)
    self.airStrikeBaseMarker:start()

    self.strikeCamOffset = sm.vec3.zero()
    self.strikeZoom = 1
    self.spottingStrike = true

    SetPlayerCamOverride({
        cameraState = 3,
        cameraFov = 45,
        cameraPosition = self:getStrikeCamPos(),
        cameraDirection = -vec3_up
    })
end

function CannonSeat:cl_cancelAirStrike(ignore)
    if not ignore then
        if self.blockStrikeCast then
            self.network:sendToServer("sv_cancelAirStrike")
        else
            self.network:sendToServer("sv_SetTurretControlsEnabled", true)
        end
    end

    if self.spottingStrike then
        sm.gui.startFadeToBlack(1.0, 0.5)
        sm.gui.endFadeToBlack(0.8)
        sm.event.sendToInteractable(self.cl_base, "cl_n_toggleHud", true)
        self.controlHud:close()
        self.airStrikeRadius:stop()
        self.airStrikeBaseMarker:stop()
        self:cl_updateHotbar()
    end

    SetPlayerCamOverride()
    self.spottingStrike = false
end

function CannonSeat:cl_endAirStrike()
    self:cl_cancelAirStrike(true)
    self.blockStrikeCast = false
end

function CannonSeat:cl_updateAirStrikeBeacon(pos)
    if pos then
        local rot = sm.vec3.getRotation(vec3_forward, vec3_up)
        self.airStrikeBeacon = sm.effect.createEffect("Cannon - AirStrike - Beacon")
        self.airStrikeBeacon:setPosition(pos + vec3_up * self.beaconScale.y * 0.5)
        self.airStrikeBeacon:setRotation(rot)
        self.airStrikeBeacon:setScale(self.beaconScale)
        self.airStrikeBeacon:start()

        self.airStrikeBeaconRange = sm.effect.createEffect("Cannon - AirStrike - BeaconRange")
        self.airStrikeBeaconRange:setPosition(pos + vec3_up * 0.1)
        self.airStrikeBeaconRange:setRotation(rot)
        self.airStrikeBeaconRange:setScale(vec3_one * 3 * 5)
        self.airStrikeBeaconRange:start()
    else
        self.airStrikeBeacon:stop()
        self.airStrikeBeacon:destroy()

        self.airStrikeBeaconRange:stop()
        self.airStrikeBeaconRange:destroy()

        if self.seated then
            self:cl_endAirStrike()
        end
    end
end

function CannonSeat:cl_onRocketExplode(detonated)
    sm.audio.play(detonated and "Retrofmblip" or "Blueprint - Delete")
    sm.gui.startFadeToBlack(1.0, 0.5)
    sm.gui.endFadeToBlack(0.8)

    SetPlayerCamOverride()

    if self.harvestable.clientPublicData.health > 0 then
        sm.event.sendToInteractable(self.cl_base, "cl_n_toggleHud", true)
        self.controlHud:close()
        self:cl_updateHotbar()
    end
end

local itemTransforms = {
    ["47b43e6e-280d-497e-9896-a3af721d89d2"] = { pos = vec3_up * 2.085 + vec3_forward * 0.22, scale = vec3_one * 0.2 },
    ["24001201-40dd-4950-b99f-17d878a9e07b"] = { pos = vec3_up * 2.085 + vec3_forward * 0.22, scale = vec3_one * 0.2 },
    ["8d3b98de-c981-4f05-abfe-d22ee4781d33"] = { pos = vec3_up * 2.085 + vec3_forward * 0.22, scale = vec3_one * 0.2 },
    ["a385b242-ce0c-4e3b-82a7-99da38510709"] = { pos = vec3_up * 2.185 + vec3_forward * 0.20, scale = vec3_one * 0.25, overrideUUID = sm.uuid.new("254360f7-ba19-431d-ac1a-92c1ee9ba483") },
}
function CannonSeat:cl_updateLoadedNuke(state)
    if state then
        self.nukeEffect = sm.effect.createEffect("ShapeRenderable", self.harvestable)

        local ammoData = self.overrideAmmoTypes[self.ammoType.index]
        local transform = itemTransforms[tostring(ammoData.uuid)]
        local uuid = transform.overrideUUID or ammoData.uuid
        self.nukeEffect:setParameter("uuid", uuid)
        self.nukeEffect:setParameter("color", sm.item.getShapeDefaultColor(uuid))

        self.nukeEffect:setOffsetPosition(transform.pos)
        self.nukeEffect:setOffsetRotation(turret_projectile_rotation_adjustment)
        self.nukeEffect:setScale(transform.scale)

        self.nukeEffect:start()
    	sm.effect.playEffect( "Resourcecollector - TakeOut", self.harvestable.worldPosition )
    else
        self.nukeEffect:stop()
        self.nukeEffect:destroy()
    end

    self.harvestable.clientPublicData.isBarrelLoaded = state
end

function CannonSeat:cl_SetTurretControlsEnabled(state)
    self.cl_controlsEnabled = state
    self.harvestable.clientPublicData.controlsEnabled = state

    if self.seated and self.ammoType ~= 2 and self.shootState ~= ShootState.null then
        self.shootState = ShootState.null
        self:cl_updateHotbar()
    end
end