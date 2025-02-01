dofile "MountedTurretGun.lua"
dofile "$CONTENT_DATA/Scripts/ControlHud.lua"

---@class MountedCannonGun : MountedTurretGun
MountedCannonGun = class(MountedTurretGun)
MountedCannonGun.maxParentCount = 3
MountedCannonGun.connectionInput = 1 + 2 + 8 + 2^14 + 2^15 + 2^16
MountedCannonGun.fireOffset = sm.vec3.new( 0.0, 0.0, 1.5 )
MountedCannonGun.ammoTypes = {
    {
        name = "Guided Missile",
        velocity = 10,
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
MountedCannonGun.containerToAmmoType = {
    ["d9e6453a-2e8c-47f8-a843-d0e700957d39"] = 1,
    ["037e3ecb-e0a6-402b-8187-a7264863c64f"] = 2,
    ["da615034-dd24-4090-ba66-9d36785d7483"] = 3,
}



function MountedCannonGun:server_onCreate()
    MountedTurretGun.server_onCreate(self)

    self.interactable.publicData = {
        rocketRoll = 0,
        rocketBoost = 0
    }
    self.rocketControls = { [1] = false, [2] = false, [3] = false, [4] = false }
end

function MountedCannonGun:sv_beforeFiring(ammoType)
    if self.rocket then return false end

    if ammoType == 2 then
        print("airstrike")
        return false
    elseif ammoType == 4 then
        local char = self:getSeatCharacter()
        if not char then return end

        local player = char:getPlayer()
        self.network:sendToClient(player, "cl_launchPlayer")

        local rot = self.shape.worldRotation
        local yaw, pitch = getYawPitch(rot * vec3_up)
        player:setCharacter(
            sm.character.createCharacter(
                player, sm.world.getCurrentWorld(),
                self.shape.worldPosition + rot * self.fireOffset,
                yaw, pitch
            )
        )

        sm.event.sendToInteractable(self.interactable, "sv_tryLaunchPlayer", player)

        return false
    end

	return true
end

---@param player Player
function MountedCannonGun:sv_tryLaunchPlayer(player)
    local char = player.character
    if not sm.exists(char) then
        sm.event.sendToInteractable(self.interactable, "sv_tryLaunchPlayer", player)
        return
    end

    local rot = self.shape.worldRotation
    char:setWorldPosition(self.shape.worldPosition + rot * self.fireOffset)
    char:setTumbling(true)

    local ammoData = getAmmoData(self)
    char:applyTumblingImpulse(rot * vec3_up * ammoData.velocity * char.mass)

    --self.network:sendToClients("cl_shoot", { canShoot = true, ammoType = self.ammoType })
	self.network:sendToClients( "cl_onShoot", ammoData.effect )
end

function MountedCannonGun:sv_OnPartFire(ammoType, ammoData, part, player)
    if ammoType == 1 then --Guided Missile
        local seat = self:getSeat()
        if seat then
            part.interactable.publicData = { owner = player, seat = self.interactable }
            self.rocket = part
        else
            part.interactable.publicData = {}
        end
    elseif isOverrideAmmoType(self, ammoType) then
        --self:sv_unSetOverrideAmmoType()
        self.network:sendToClients("cl_updateLoadedNuke", false)
    end
end

function MountedCannonGun:sv_onRocketExplode(detonated)
    self.rocket = nil
    self.interactable.publicData = {
        rocketRoll = 0,
        rocketBoost = 0
    }
    self.rocketControls = { [1] = false, [2] = false, [3] = false, [4] = false }

    local char = self:getSeatCharacter()
    if char then
        self.network:sendToClient(char:getPlayer(), "cl_onRocketExplode", detonated)
    end
end

function MountedCannonGun:sv_onRocketInput(data)
    local action, state = data.action, data.state

    if (action == 1 or action == 2) then
        self.rocketControls[data.action] = data.state
        self.interactable.publicData.rocketRoll = BoolToNum(self.rocketControls[2]) - BoolToNum(self.rocketControls[1])
    end

    if (action == 3 or action == 4) then
        self.rocketControls[data.action] = data.state
        self.interactable.publicData.rocketBoost = BoolToNum(self.rocketControls[3]) - BoolToNum(self.rocketControls[4])
    end

    if state and (action == 5 or action == 19) then
        if self.rocket == nil or not sm.exists(self.rocket) then return end

        sm.event.sendToInteractable(self.rocket.interactable, "sv_explode")
        self.rocket = nil
    end
end



function MountedCannonGun:client_onCreate()
    MountedTurretGun.client_onCreate(self)

    self.controlHud = ControlHud():init(4, 1/23)
    self.hotbar = sm.gui.createSeatGui()

    sm.SetInteractableClientPublicData(self.interactable, { hasRocket = false })
end

local connectionTypes = {
    2^14,
    2^15,
    2^16
}

function MountedCannonGun:client_getAvailableParentConnectionCount( connectionType )
	if bit.band( connectionType, 1 ) ~= 0 then
		return 1 - #self.interactable:getParents( 1 )
    elseif bit.band( connectionType, 2 ) ~= 0 then
		return 1 - #self.interactable:getParents( 2 )
	else
		for k, cType in pairs(connectionTypes) do
			if #self.interactable:getParents( cType ) > 0 then
				return 0
			end
		end

		return 1
	end
end

function MountedCannonGun:cl_launchPlayer()
    sm.gui.startFadeToBlack(1.0, 0.5)
    sm.gui.endFadeToBlack(0.8)
end

function MountedCannonGun:cl_onShoot(effect)
    MountedTurretGun.cl_onShoot(self, effect)

    if self.ammoType == 1 then
        local char = self:getSeatCharacter()
        if not char or char:getPlayer() ~= sm.localPlayer.getPlayer() then return end

        sm.audio.play("Blueprint - Build")
        sm.gui.startFadeToBlack(1.0, 0.5)
        sm.gui.endFadeToBlack(0.8)
        self:cl_n_toggleHud(false, true)

        self.hotbar:setGridItem( "ButtonGrid", 0, {
            itemId = HotbarIcon.shoot,
            active = false
        })
        self.hotbar:open()

        local rot = self.shape.worldRotation
        SetPlayerCamOverride({
            cameraState = 3,
            cameraFov = 45,
            cameraPosition = sm.camera.getPosition() + rot * vec3_up * 0.25,
            cameraRotation = rot * turret_projectile_rotation_adjustment
        })

        self.controlHud:open()

        --sm.SetInteractableClientPublicData(self.interactable, { hasRocket = true })
        sm.GetInteractableClientPublicData(self.interactable).hasRocket = true
        sm.event.sendToInteractable(self:getSeat(), "cl_onRocketFire")
    end
end

function MountedCannonGun:cl_onRocketExplode(detonated)
    sm.audio.play(detonated and "Retrofmblip" or "Blueprint - Delete")
    sm.gui.startFadeToBlack(1.0, 0.5)
    sm.gui.endFadeToBlack(0.8)

    SetPlayerCamOverride()

    self:cl_n_toggleHud(true)
    self.controlHud:close()
    self.hotbar:close()

    sm.SetInteractableClientPublicData(self.interactable, { hasRocket = false })
    sm.event.sendToInteractable(self:getSeat(), "cl_onRocketExplode")
end

function MountedCannonGun:cl_n_toggleHud(toggle, forceSurvivalOff)
    if type(toggle) == "table" then
        toggle, forceSurvivalOff = toggle[1], toggle[2]
    end

    if toggle then
        if sm.SURVIVALHUD then
            sm.SURVIVALHUD:close()
        end
    else
        if sm.SURVIVALHUD and not forceSurvivalOff then
            sm.SURVIVALHUD:open()
        end
    end
end