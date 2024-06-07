dofile "MountedTurretGun.lua"

---@class MountedCannonGun : MountedTurretGun
MountedCannonGun = class(MountedTurretGun)
MountedCannonGun.maxParentCount = 3
MountedCannonGun.connectionInput = 1 + 2 + 2^14 + 2^15 + 2^16
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
end

function MountedCannonGun:sv_OnPartFire(ammoType, ammoData, part, player)
    if ammoType == 1 then --Guided Missile
        local seat = self.interactable:getParents(2)[1]
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
