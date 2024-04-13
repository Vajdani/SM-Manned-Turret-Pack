dofile "TurretSeat.lua"

---@class CannonSeat : TurretSeat
CannonSeat = class(TurretSeat)
CannonSeat.ammoTypes = {
    {
        name = "Guided Missile",
        velocity = 50,
        recoilStrength = 1,
        fireCooldown = 40,
        effect = "Cannon - Shoot",
        ammo = sm.uuid.new("24d5e812-3902-4ac3-b214-a0c924a5c40f"),
        uuid = sm.uuid.new("24d5e812-3902-4ac3-b214-a0c924a5c40f"),
        isPart = true
    },
    {
        name = "Air Strike",
        velocity = 50,
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
        ammo = sm.uuid.new( HotbarIcon.pLauncher )
    }
}
CannonSeat.containerToAmmoType = {
    ["d9e6453a-2e8c-47f8-a843-d0e700957d39"] = 1,
    ["037e3ecb-e0a6-402b-8187-a7264863c64f"] = 2,
    ["da615034-dd24-4090-ba66-9d36785d7483"] = 3,
}
CannonSeat.baseUUID = "a0c96d35-37ca-4cf9-82d8-9b9077132918"
CannonSeat.airStrikeDistanceLimit = 100



function CannonSeat:server_onCreate()
    TurretSeat.server_onCreate(self)

    self.harvestable.publicData.rocketRoll = 0
    self.harvestable.publicData.rocketBoost = 0
    self.rocketControls = { [1] = false, [2] = false, [3] = false, [4] = false }
end

function CannonSeat:server_onDestroy()
    if self.rocket then
        sm.event.sendToInteractable(self.rocket.interactable, "sv_explode")
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
    if ammoType == 1 then
        part.interactable.publicData = { owner = player, seat = self.harvestable }
        self.rocket = part
        self:sv_SetTurretControlsEnabled(false)
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
    if self.rocket == nil then return end

    sm.event.sendToInteractable(self.rocket.interactable, "sv_explode")
    self.rocket = nil
end

function CannonSeat:sv_startAirStrikeCasting()
    sm.event.sendToInteractable(self.base, "sv_clearDrivingFlags", true)
    self:sv_SetTurretControlsEnabled(false)
end

function CannonSeat:sv_startAirStrike(pos, caller)
    sm.effect.playEffect("Loot - Pickup", pos)

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
            turretSelf:sv_applyFiringImpulse(turretSelf.ammoTypes[2], turretSelf.harvestable.worldRotation * vec3_up, ({turretSelf:getFirePos()})[2])
            return true
        end
    }

    if not strike:start() then
        self.airStrike = strike
    end
end

function CannonSeat:sv_endAirStrike()
    self:sv_SetTurretControlsEnabled(true)
    self.network:sendToClient(self.sv_seated:getPlayer(), "cl_endAirStrike")
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

    char:setWorldPosition(({self:getFirePos()})[2])
    char:setTumbling(true)
    char:applyTumblingImpulse(self.harvestable.worldRotation * vec3_up * self.ammoTypes[self.ammoType].velocity * char.mass)

    self.network:sendToClients("cl_shoot", { canShoot = true, ammoType = self.ammoType })
end



function CannonSeat:client_onCreate()
    TurretSeat.client_onCreate(self)

    self.strikeMoveControls = { [1] = false, [2] = false, [3] = false, [4] = false }
    self.controlHud = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/RocketControlHud.layout", false,
        {
            isHud = true,
            isInteractive = false,
            needsCursor = false,
            hidesHotbar = false,
            isOverlapped = false,
            backgroundAlpha = 0
        }
    )
end

function CannonSeat:client_onDestroy()
    TurretSeat.client_onDestroy(self)

    self.controlHud:destroy()
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

            self.strikeCamOffset = self.strikeCamOffset + (vec3_forward * veritcal + vec3_right * horizontal):safeNormalize(vec3_zero) * dt * 10 * self.strikeZoom
            local distance = self.strikeCamOffset:length()
            if distance >= self.airStrikeDistanceLimit then
                self.strikeCamOffset = self.strikeCamOffset * (self.airStrikeDistanceLimit / distance)
            end

            sm.localPlayer.getPlayer().clientPublicData.interactableCameraData.cameraPosition = self:getStrikeCamPos(dt)
        elseif self.cl_controlsEnabled then
            sm.localPlayer.getPlayer().clientPublicData.interactableCameraData = { cameraState = 5 }

            local parent = self.cl_base:getSingleParent()
            if parent then
                local container = parent:getContainer(0)
                local uuid = self.ammoTypes[self.ammoType].ammo
                sm.gui.setInteractionText(("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>%d / %d</p>"):format(sm.container.totalQuantity(container, uuid), container:getSize() * container:getMaxStackSize()))
            elseif sm.game.getEnableAmmoConsumption() and self.ammoType ~= 4 then
                sm.gui.setInteractionText(("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>No ammunition</p>"))
            end
        end
    end
end

function CannonSeat:getFirePos()
    local pos = self.harvestable.worldPosition + (self.base or self.cl_base).shape.velocity * 0.025
    local rot = self.harvestable.worldRotation
    local offsetBase = vec3_forward * 0.2
    return pos + rot * offsetBase, pos + rot * (vec3_up * 2 + offsetBase)
end

local strikeFilter = sm.physics.filter.staticBody + sm.physics.filter.dynamicBody + sm.physics.filter.terrainAsset + sm.physics.filter.terrainSurface
function CannonSeat:getStrikeCamPos(dt)
    local baseShape = self.cl_base.shape
    local basePos = baseShape:getInterpolatedWorldPosition() + baseShape.velocity * (dt or 0) + self.strikeCamOffset
    local hit, result = sm.physics.raycast(basePos + vec3_up * 1000, basePos, baseShape, strikeFilter)
    if hit then
        return result.pointWorld + vec3_up * 10 * self.strikeZoom
    end

    return basePos + vec3_up * 10 * self.strikeZoom
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
            sm.localPlayer.getPlayer().clientPublicData.interactableCameraData.cameraPosition = self:getStrikeCamPos()
        end
    elseif action == 8 then
        if self.strikeZoom < 5 then
            self.strikeZoom = self.strikeZoom + 1
            sm.audio.play("ConnectTool - Rotate", self:getStrikeCamPos())
            sm.localPlayer.getPlayer().clientPublicData.interactableCameraData.cameraPosition = self:getStrikeCamPos()
        end
    end
end

function CannonSeat:cl_shoot(args)
    if args.canShoot then
        self.recoil_l = 1

        local ammoType = args.ammoType or self.ammoType
        sm.effect.playEffect(self.ammoTypes[ammoType].effect, args.pos or ({self:getFirePos()})[2], vec3_zero, sm.vec3.getRotation(vec3_up, args.dir or self.harvestable.worldRotation * vec3_up))

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

            local dir = self.harvestable.worldRotation * vec3_up
            sm.localPlayer.getPlayer().clientPublicData.interactableCameraData = {
                cameraState = 3,
                cameraFov = 45,
                cameraPosition = sm.camera.getPosition() + dir * 0.25,
                cameraDirection = dir
            }

            self.controlHud:open()
        end
    else
        sm.effect.playEffect("Turret - FailedShoot", args.pos)
    end
end

function CannonSeat:cl_startAirStrike()
    if self.blockStrikeCast then return end

    local parent = self.cl_base:getSingleParent()
    if parent and not parent:getContainer(0):canSpend(self.ammoTypes[2].ammo, 1) then
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

    sm.localPlayer.getPlayer().clientPublicData.interactableCameraData = {
        cameraState = 3,
        cameraFov = 45,
        cameraPosition = self.cl_base.shape.worldPosition + vec3_up * 10,
        cameraDirection = -vec3_up
    }

    self.controlHud:open()

    self.strikeCamOffset = sm.vec3.zero()
    self.strikeZoom = 1
    self.spottingStrike = true
end

function CannonSeat:cl_cancelAirStrike()
    if self.blockStrikeCast then
        self.network:sendToServer("sv_cancelAirStrike")
    else
        self.network:sendToServer("sv_SetTurretControlsEnabled", true)
    end

    if sm.localPlayer.getPlayer().clientPublicData.interactableCameraData then
        sm.gui.startFadeToBlack(1.0, 0.5)
        sm.gui.endFadeToBlack(0.8)
        sm.event.sendToInteractable(self.cl_base, "cl_n_toggleHud", true)
        self.controlHud:close()
        self:cl_updateHotbar()
    end

    sm.localPlayer.getPlayer().clientPublicData.interactableCameraData = nil
    self.spottingStrike = false
end

function CannonSeat:cl_endAirStrike()
    self:cl_cancelAirStrike()
    self.blockStrikeCast = false
end

function CannonSeat:cl_onRocketExplode(detonated)
    sm.audio.play(detonated and "Retrofmblip" or "Blueprint - Delete")
    sm.gui.startFadeToBlack(1.0, 0.5)
    sm.gui.endFadeToBlack(0.8)

    sm.localPlayer.getPlayer().clientPublicData.interactableCameraData = nil

    if self.harvestable.clientPublicData.health > 0 then
        sm.event.sendToInteractable(self.cl_base, "cl_n_toggleHud", true)
        self.controlHud:close()
        self:cl_updateHotbar()
    end
end

function CannonSeat:cl_SetTurretControlsEnabled(state)
    self.cl_controlsEnabled = state
    self.harvestable.clientPublicData.controlsEnabled = state

    if self.seated and self.ammoType ~= 2 and self.shootState ~= ShootState.null then
        self.shootState = ShootState.null
        self:cl_updateHotbar()
    end
end