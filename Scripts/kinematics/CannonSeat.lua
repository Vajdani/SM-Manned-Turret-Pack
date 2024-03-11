dofile "TurretSeat.lua"

---@class CannonSeat : TurretSeat
CannonSeat = class(TurretSeat)
CannonSeat.ammoTypes = {
    {
        name = "Cannon Ball",
        velocity = 50,
        fireCooldown = 20, --2.5 * 40,
        effect = "Turret - Shoot",
        ammo = sm.uuid.new("24d5e812-3902-4ac3-b214-a0c924a5c40f"),
        uuid = sm.uuid.new("24d5e812-3902-4ac3-b214-a0c924a5c40f")
    }
}
CannonSeat.containerToAmmoType = {
    ["d9e6453a-2e8c-47f8-a843-d0e700957d39"] = 1,
}
CannonSeat.baseUUID = "a0c96d35-37ca-4cf9-82d8-9b9077132918"



function CannonSeat:server_onCreate()
    TurretSeat.server_onCreate(self)

    self.harvestable.publicData.rocketRoll = 0
    self.rollStates = { [1] = false, [2] = false }
end

function CannonSeat:sv_rocketRollUpdate(data)
    self.rollStates[data.action] = data.state
    self.harvestable.publicData.rocketRoll = BoolToNum(self.rollStates[2]) - BoolToNum(self.rollStates[1])
end

local rayFilter = sm.physics.filter.dynamicBody + sm.physics.filter.staticBody + sm.physics.filter.terrainAsset + sm.physics.filter.terrainSurface + sm.physics.filter.harvestable
function CannonSeat:sv_shoot(ammoType, caller)
    self.shotCounter = self.shotCounter + 1
    local startPos, endPos = self:getFirePos()
    local rot = self.harvestable.worldRotation
    local hit, result = sm.physics.raycast(startPos, endPos, self.harvestable, rayFilter)
    if hit then
        self.network:sendToClients("cl_shoot", { canShoot = false, pos = endPos })
        return
    end

    local dir = rot * vec3_up
    local canShoot = self:canShoot(ammoType)
    if canShoot then
        local ammoData = self.ammoTypes[ammoType]

        local projectileRot = rot * sm.quat.angleAxis(math.rad(90), vec3_right) * sm.quat.angleAxis(math.rad(180), vec3_forward)
        local projectile = sm.shape.createPart(ammoData.uuid, endPos - projectileRot * sm.item.getShapeOffset(ammoData.uuid), projectileRot)
        projectile.interactable.publicData = { owner = caller, seat = self.harvestable }
        self.rocket = projectile

        self:sv_SetTurretControlsEnabled(false)
    end

    self.network:sendToClients("cl_shoot", { canShoot = canShoot, pos = endPos, dir = dir, shotCount = self.shotCounter, ammoType = ammoType })
end

function CannonSeat:sv_onRocketExplode(detonated)
    self.rocket = nil
    self.harvestable.publicData.rocketRoll = 0
    self.rollStates = { [1] = false, [2] = false }
    self:sv_SetTurretControlsEnabled(true)
    self.network:sendToClient(self.harvestable:getSeatCharacter():getPlayer(), "cl_onRocketExplode", detonated)
end

function CannonSeat:sv_detonateRocket()
    if self.rocket == nil then return end

    sm.event.sendToInteractable(self.rocket.interactable, "sv_explode")
    self.rocket = nil
end



function CannonSeat:client_onAction(action, state)
    if not self.cl_controlsEnabled then
        if (action == 1 or action == 2) then
            self.network:sendToServer("sv_rocketRollUpdate", { action = action, state = state })
        end

        if state and (action == 5 or action == 19) then
            self.network:sendToServer("sv_detonateRocket")
        end

        return true
    end

    return TurretSeat.client_onAction(self, action, state)
end

function CannonSeat:client_onUpdate(dt)
    if not sm.exists(self.cl_base) then return end

    local speed = dt * 7.5
    self.recoil_l = math.max(self.recoil_l - speed, 0)
    self.harvestable:setPoseWeight(0, sm.util.easing("easeOutCubic", self.recoil_l))

    if self.seated and self.cl_controlsEnabled then --If controlling rocket, dont do turret pov
        sm.localPlayer.getPlayer().clientPublicData.customCameraData = { cameraState = 5 }

        local parent = self.cl_base:getSingleParent()
        if parent then
            local container = parent:getContainer(0)
            local uuid = self.ammoTypes[self.ammoType].ammo
            sm.gui.setInteractionText(("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>%d / %d</p>"):format(sm.container.totalQuantity(container, uuid), container:getSize() * container:getMaxStackSize()))
        end
    end
end

function CannonSeat:getFirePos()
    local pos = self.harvestable.worldPosition
    local rot = self.harvestable.worldRotation

    local offsetBase = vec3_forward * 0.2
    return pos + rot * offsetBase, pos + rot * (vec3_up * 2.75 + offsetBase)
end

function CannonSeat:cl_shoot(args)
    if args.canShoot then
        self.recoil_l = 1
        sm.effect.playEffect(self.ammoTypes[args.ammoType].effect, args.pos, vec3_zero, sm.vec3.getRotation(vec3_up, args.dir))

        if self.seated then
			sm.audio.play("Blueprint - Build")
            sm.gui.startFadeToBlack(0.1, 0.5)
            sm.event.sendToInteractable(self.cl_base, "cl_n_toggleHud", false)

            self.hotbar:setGridItem( "ButtonGrid", 0, {
                itemId = "24001201-40dd-4950-b99f-17d878a9e07b",
                active = false
            })
            self.hotbar:setGridItem( "ButtonGrid", 1, nil)
            self.hotbar:setGridItem( "ButtonGrid", 2, nil)
            self.hotbar:setGridItem( "ButtonGrid", 3, nil)
        end
    else
        sm.audio.play("Lever off", args.pos)

        if self.seated then
            self.shootState = ShootState.null
            self:cl_updateHotbar()
        end
    end
end

function CannonSeat:cl_onRocketExplode(detonated)
    sm.audio.play(detonated and "Retrofmblip" or "Blueprint - Delete")
    sm.gui.startFadeToBlack(0.1, 1)
    sm.event.sendToInteractable(self.cl_base, "cl_n_toggleHud", true)
end