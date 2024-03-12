dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )

---@class MountedTurretGun : ShapeClass
MountedTurretGun = class()
MountedTurretGun.maxParentCount = 2
MountedTurretGun.maxChildCount = 0
MountedTurretGun.connectionInput = 1 + 1024 + 2048 + 2^13 + 2^14
MountedTurretGun.connectionOutput = sm.interactable.connectionType.none
MountedTurretGun.colorNormal = sm.color.new( 0xcb0a00ff )
MountedTurretGun.colorHighlight = sm.color.new( 0xee0a00ff )
MountedTurretGun.poseWeightCount = 1
MountedTurretGun.ammoTypes = {
    {
        name = "AA Rounds",
        damage = 100,
        velocity = 300,
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
        ammo = sm.uuid.new( "869d4736-289a-4952-96cd-8a40117a2d28" ),
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
        fireCooldown = 6,
        spread = 8,
        effect = "SpudgunBasic - BasicMuzzel",
        ammo = sm.uuid.new( "bfcfac34-db0f-42d6-bd0c-74a7a5c95e82" ),
        uuid = projectile_potato
    }
}
MountedTurretGun.containerToAmmoType = {
    ["756594d6-6fdd-4f60-9289-a2416287f942"] = 1,
    ["037e3ecb-e0a6-402b-8187-a7264863c64f"] = 2,
    ["ea10d1af-b97a-46fb-8895-dfd1becb53bb"] = 3,
    --["be29592a-ef58-4b1d-b18c-895023abd27f"] = 4,
    --["76331bbf-abbd-4b8d-bb54-f721a5b6193b"] = 5,
    ["096d4daf-639e-4947-a1a6-1890eaa94464"] = 4,
}

local connectionTypes = {
	1024,
	2048,
	2^13,
	2^14
}

function MountedTurretGun:server_onCreate()
	self.sv = {}
	self.sv.fireDelayProgress = self.ammoTypes[1].fireCooldown
	self.sv.canFire = true
	self.sv.parentActive = false

	local ammoType = self.storage:load()
	if ammoType then
		self:sv_updateAmmoType(ammoType)
	end
end


function MountedTurretGun:server_onFixedUpdate()
	if not self.sv.canFire then
		self.sv.fireDelayProgress = self.sv.fireDelayProgress - 1
		if self.sv.fireDelayProgress <= 0 then
			self.sv.canFire = true
		end
	end
	self:sv_tryFire()
	local logicInteractable, ammoInteractable = self:getInputs()
	if logicInteractable then
		self.sv.parentActive = logicInteractable:isActive()
	end

	if ammoInteractable ~= self.ammoInteractable then
		self:sv_updateAmmoType(self:getAmmoType(ammoInteractable))
		self.ammoInteractable = ammoInteractable
	end
end

function MountedTurretGun:sv_tryFire()
	local logicInteractable, ammoInteractable = self:getInputs()
	local active = logicInteractable and logicInteractable:isActive() or false
	local ammoContainer = ammoInteractable and ammoInteractable:getContainer( 0 ) or nil
	local freeFire = not sm.game.getEnableAmmoConsumption() and not ammoContainer

	if freeFire then
		if active and not self.sv.parentActive and self.sv.canFire then
			self:sv_fire(self.ammoTypes[self.cl.ammoType])
		end
	else
		if active and not self.sv.parentActive and self.sv.canFire and ammoContainer then
			local ammoType = self.ammoTypes[self.cl.ammoType]

			sm.container.beginTransaction()
			sm.container.spend( ammoContainer, ammoType.ammo, 1 )
			if sm.container.endTransaction() then
				self:sv_fire(ammoType)
			end
		end
	end
end

---@param ammoType AmmoType
function MountedTurretGun:sv_fire(ammoType)
	self.sv.canFire = false
	self.sv.fireDelayProgress = ammoType.fireCooldown

	sm.projectile.shapeProjectileAttack( ammoType.uuid, ammoType.damage, sm.vec3.new( 0.0, 0.0, 0.375 ), sm.noise.gunSpread(vec3_up, ammoType.spread) * ammoType.velocity, self.shape )
	sm.physics.applyImpulse( self.shape, -vec3_up * 500 )
	self.network:sendToClients( "cl_onShoot", ammoType.effect )
end

function MountedTurretGun:sv_updateAmmoType(ammoType)
	self.storage:save(ammoType)
	self.network:sendToClients("cl_updateAmmoType", ammoType)
end



function MountedTurretGun:client_onCreate()
	self.cl = {}
	self.cl.boltValue = 0.0

	self.cl.ammoType = 1
end

function MountedTurretGun:client_canInteract()
	local canInteract = ({self:getInputs()})[2] == nil
	if canInteract then
		sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use", true), "Switch ammo type")
	end
	sm.gui.setInteractionText(("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>Ammunition: %s</p>"):format(self.ammoTypes[self.cl.ammoType].name))

	return canInteract
end

function MountedTurretGun:client_onInteract(char, state)
	if not state then return end

	local ammoType = self.cl.ammoType < #self.ammoTypes and self.cl.ammoType + 1 or 1
	sm.gui.displayAlertText("Ammunition selected: #df7f00"..self.ammoTypes[ammoType].name, 2)
	sm.audio.play("PaintTool - ColorPick")

	self.cl.ammoType = ammoType
	self.network:sendToServer("sv_updateAmmoType", ammoType)
end

function MountedTurretGun:client_onUpdate( dt )
	if self.cl.boltValue > 0.0 then
		self.cl.boltValue = self.cl.boltValue - dt * 7.5
	end
	if self.cl.boltValue ~= self.cl.prevBoltValue then
		self.interactable:setPoseWeight( 0, sm.util.easing("easeOutCubic", self.cl.boltValue) )
		self.cl.prevBoltValue = self.cl.boltValue
	end
end

function MountedTurretGun:client_getAvailableParentConnectionCount( connectionType )
	if connectionType == 1 then
		return 1 - #self.interactable:getParents( 1 )
	else
		for k, cType in pairs(connectionTypes) do
			if #self.interactable:getParents( cType ) > 0 then
				return 0
			end
		end

		return 1
	end
end

function MountedTurretGun:cl_updateAmmoType(ammoType)
	self.cl.ammoType = ammoType
end

local effectOffsets = {
	["Turret - Shoot"] = vec3_up,
	["Mountedwatercanon - Shoot"] = vec3_zero,
	["SpudgunBasic - BasicMuzzel"] = vec3_up
}
function MountedTurretGun:cl_onShoot(effect)
	self.cl.boltValue = 1.0

	local rot = self.shape.worldRotation
	sm.effect.playEffect(effect, self.shape.worldPosition + rot * effectOffsets[effect], vec3_zero, rot)
end

function MountedTurretGun:getInputs()
	local logicInteractable = nil
	local ammoInteractable = nil
	local parents = self.interactable:getParents()
	for k, parent in pairs(parents) do
		if parent:hasOutputType( 1 ) then
			logicInteractable = parent
		else
			ammoInteractable = parent
		end
	end

	return logicInteractable, ammoInteractable
end

function MountedTurretGun:getAmmoType(parent)
    if parent then
        return self.containerToAmmoType[tostring(parent.shape.uuid)]
    end

    if not sm.game.getEnableAmmoConsumption() then
        return self.cl.ammoType
    end

    return 1
end