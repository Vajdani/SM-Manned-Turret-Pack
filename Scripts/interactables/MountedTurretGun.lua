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
MountedTurretGun.fireOffset = sm.vec3.new( 0.0, 0.0, 0.375 )
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
        effect = "Mountedwatercanon - Shoot",
        ammo = sm.uuid.new( "869d4736-289a-4952-96cd-8a40117a2d28" ),
        uuid = projectile_water
    },
    --[[{
        name = "Chemical drops",
        damage = 0,
        velocity = 130,
        fireCooldown = 6,
        effect = "Turret - Shoot",
        ammo = "f74c2891-79a9-45e0-982e-4896651c2e25",
        uuid = projectile_pesticide
    },
    {
        name = "Fertilizer drops",
        damage = 0,
        velocity = 130,
        fireCooldown = 6,
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
MountedTurretGun.overrideAmmoTypes = {}
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
		if active and not self.sv.parentActive and self.sv.canFire and self:sv_beforeFiring(self.ammoType) then
			self:sv_fire(sm.GetTurretAmmoData(self, self.ammoType))
		end
	else
		if active and not self.sv.parentActive and self.sv.canFire and ammoContainer then
			local ammoData = sm.GetTurretAmmoData(self, self.ammoType)

			sm.container.beginTransaction()
			sm.container.spend( ammoContainer, ammoData.ammo, 1 )
			if sm.container.endTransaction() and self:sv_beforeFiring(self.ammoType) then
				self:sv_fire(ammoData)
			end
		end
	end
end

function MountedTurretGun:sv_beforeFiring(ammoType)
	return true
end

---@param ammoData AmmoType
function MountedTurretGun:sv_fire(ammoData)
	self.sv.canFire = false
	self.sv.fireDelayProgress = ammoData.fireCooldown

	local finalFirePos
	local rot = self.shape.worldRotation
	local dir = self.shape.up
	if sm.item.isPart(ammoData.uuid) then
		local projectileRot = rot * turret_projectile_rotation_adjustment
		finalFirePos = self.shape.worldPosition + rot * self.fireOffset - projectileRot * sm.item.getShapeOffset(ammoData.uuid)
		local projectile = sm.shape.createPart(ammoData.uuid, finalFirePos, projectileRot)

		if ammoData.velocity then
			sm.physics.applyImpulse(projectile, dir * projectile.mass * ammoData.velocity, true)
		end

		local char = self:getSeatCharacter()
		self:sv_OnPartFire(self.ammoType, ammoData, projectile, char and char:getPlayer())
	else
		finalFirePos = self.shape.worldPosition + rot * self.fireOffset
		sm.projectile.shapeProjectileAttack( ammoData.uuid, ammoData.damage, self.fireOffset, sm.noise.gunSpread(vec3_up, ammoData.spread or 0) * ammoData.velocity, self.shape )

		local char = self:getSeatCharacter()
		self:sv_OnProjectileFire(self.ammoType, ammoData, char and char:getPlayer())
	end

	self:sv_applyFiringImpulse(ammoData, dir, finalFirePos)
	self.network:sendToClients( "cl_onShoot", { effect = ammoData.effect, ammoType = self.ammoType } )
end

---@param ammoType number
---@param ammoData AmmoType
---@param part Shape
---@param player Player|nil
function MountedTurretGun:sv_OnPartFire(ammoType, ammoData, part, player) end

---@param ammoType number
---@param ammoData AmmoType
---@param player Player|nil
function MountedTurretGun:sv_OnProjectileFire(ammoType, ammoData, player) end

function MountedTurretGun:sv_applyFiringImpulse(ammoData, dir, finalFirePos)
    if ammoData.recoilStrength then
        sm.physics.applyImpulse(self.shape, -dir * ammoData.recoilStrength * self.shape.mass, true, self.shape:transformPoint(finalFirePos))
    end
end

function MountedTurretGun:sv_updateAmmoType(ammoType)
	self.storage:save(ammoType)
	self.network:sendToClients("cl_updateAmmoType", ammoType)
end

function MountedTurretGun:sv_setOverrideAmmoType(id)
    local previous = sm.isOverrideAmmoType(self) and self.ammoType.previous or self.ammoType
    self:sv_updateAmmoType({ index = id, previous = previous })
end

function MountedTurretGun:sv_unSetOverrideAmmoType()
    self:sv_updateAmmoType(self.ammoType.previous)
end



function MountedTurretGun:client_onCreate()
	self.boltValue = 0.0
	self.ammoType = 1
end

function MountedTurretGun:client_canInteract()
	local canInteract = ({self:getInputs()})[2] == nil
	if canInteract then
		sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use", true), "Switch ammo type")
	end
	sm.gui.setInteractionText(("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>Ammunition: %s</p>"):format(sm.GetTurretAmmoData(self).name))

	return canInteract
end

function MountedTurretGun:client_onInteract(char, state)
	if not state then return end
	if sm.isOverrideAmmoType(self) then return end

	local ammoType = self.ammoType < #self.ammoTypes and self.ammoType + 1 or 1
	sm.gui.displayAlertText("Ammunition selected: #df7f00"..self.ammoTypes[ammoType].name, 2)
	sm.audio.play("PaintTool - ColorPick")

	self.ammoType = ammoType
	self.network:sendToServer("sv_updateAmmoType", ammoType)
end

function MountedTurretGun:client_onUpdate( dt )
	if self.boltValue > 0.0 then
		self.boltValue = self.boltValue - dt * 7.5
	end
	if self.boltValue ~= self.prevBoltValue then
		self.interactable:setPoseWeight( 0, sm.util.easing("easeOutCubic", self.boltValue) )
		self.prevBoltValue = self.boltValue
	end
end

function MountedTurretGun:client_getAvailableParentConnectionCount( connectionType )
	if bit.band( connectionType, 1 ) ~= 0  then
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
	self.ammoType = ammoType
end

local effectOffsets = {
	["Mountedwatercanon - Shoot"] = vec3_zero
}
function MountedTurretGun:cl_onShoot(ammoData)
	self.boltValue = 1.0

	local effect = ammoData.effect
	local rot = self.shape.worldRotation
	sm.effect.playEffect(effect, self.shape.worldPosition + rot * (effectOffsets[effect] or vec3_up), vec3_zero, rot)
end

function MountedTurretGun:getInputs()
	local logicInteractable = nil
	local ammoInteractable = nil
	local parents = self.interactable:getParents()
	for k, parent in pairs(parents) do
		if parent:hasOutputType( 1 ) then
			logicInteractable = parent
		elseif parent:getContainer(0) then
			ammoInteractable = parent
		end
	end

	return logicInteractable, ammoInteractable
end

function MountedTurretGun:getAmmoType(parent)
	if sm.isOverrideAmmoType(self) then
        return self.ammoType
    end

    if parent then
        return self.containerToAmmoType[tostring(parent.shape.uuid)]
    end

    if not sm.game.getEnableAmmoConsumption() then
        return self.ammoType
    end

    for k, v in pairs(self.ammoTypes) do
        if v.ignoreAmmoConsumption then
            return k
        end
    end

    return 1
end

function MountedTurretGun:getSeat()
    return self.interactable:getParents(2)[1] or self.interactable:getParents(8)[1]
end

function MountedTurretGun:getSeatCharacter()
    local seat = self:getSeat()
    if not seat then return end

    local char = seat:getSeatCharacter()
    if sm.exists(char) then
        return char
    end
end