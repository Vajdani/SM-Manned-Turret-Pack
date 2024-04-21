dofile("$GAME_DATA/Scripts/game/AnimationUtil.lua")
dofile("$SURVIVAL_DATA/Scripts/util.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua")

local Damage = 75
local Range = 100
local MaxCharge = 10
local TurretHealAmount = 50
local FireCooldown = 0.25
local MagRechargeCooldown = 1

---@class LightningGatling : ToolClass
---@field tpAnimations table
---@field fpAnimations table
---@field shootEffect Effect
---@field shootEffectFP Effect
---@field windupEffect Effect
---@field normalFireMode table
---@field aimFireMode table
---@field fireCooldownTimer number
---@field spreadCooldownTimer number
---@field movementDispersion number
---@field sprintCooldownTimer number
---@field sprintCooldown number
---@field aimBlendSpeed number
---@field blendTime number
---@field jointWeight number
---@field spineWeight number
---@field aimWeight number
---@field gatlingActive boolean
---@field gatlingBlendSpeedIn number
---@field gatlingBlendSpeedOut number
---@field gatlingWeight number
---@field gatlingTurnSpeed number
---@field gatlingTurnFraction number
---@field aiming boolean
---@field equipped boolean
---@field wantEquipped boolean
---@field prevSecondaryState boolean
LightningGatling = class()

local renderables = {
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_spinner/char_spudgun_barrel_spinner.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_spinner/char_spudgun_sight_spinner.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
}

local renderablesTp = {
	"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_spudgun.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_tp_animlist.rend"
}
local renderablesFp = {
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_fp_animlist.rend"
}

sm.tool.preloadRenderables(renderables)
sm.tool.preloadRenderables(renderablesTp)
sm.tool.preloadRenderables(renderablesFp)

function LightningGatling:server_onCreate()
	self.sv_charge = self.storage:load() or 0
	self.sv_fireCooldownTimer = 0

	self.network:sendToClients("cl_updateCharge", self.sv_charge)
end

function LightningGatling:client_onCreate()
	self.shootEffect = sm.effect.createEffect("LightningGatling - Shoot") --"SpudgunSpinner - SpinnerMuzzel")
	self.shootEffectFP = sm.effect.createEffect("LightningGatling - Shoot") --"SpudgunSpinner - FPSpinnerMuzzel")
	self.windupEffect = sm.effect.createEffect("SpudgunSpinner - Windup")

	self.isLocal = self.tool:isLocal()
	self.cl_charge = 0
end

local isAimAnim = {
	aimInto = true,
	aimIdle = true,
	aimShoot = true,
}

local isSprintAnim = {
	sprintInto = true,
	sprintIdle = true,
}

function LightningGatling:client_onUpdate(dt)
	-- First person animation	
	local isSprinting = self.tool:isSprinting()
	local isCrouching = self.tool:isCrouching()

	if self.isLocal then
		if self.equipped then
			local currentAnim = self.fpAnimations.currentAnimation

			local isSprintAnimActive = isSprintAnim[currentAnim] == true
			if isSprinting and not isSprintAnimActive then
				swapFpAnimation(self.fpAnimations, "sprintExit", "sprintInto", 0.0)
			elseif not isSprinting and isSprintAnimActive then
				swapFpAnimation(self.fpAnimations, "sprintInto", "sprintExit", 0.0)
			end

			local isAimAnimActive = isAimAnim[currentAnim] == true
			if self.aiming and not isAimAnimActive then
				swapFpAnimation(self.fpAnimations, "aimExit", "aimInto", 0.0)
			elseif not self.aiming and isAimAnimActive then
				swapFpAnimation(self.fpAnimations, "aimInto", "aimExit", 0.0)
			end
		end
		updateFpAnimations(self.fpAnimations, self.equipped, dt)
	end

	if not self.equipped then
		if self.wantEquipped then
			self.wantEquipped = false
			self.equipped = true
		end
		return
	end


	if self.isLocal then
		local dir = sm.localPlayer.getDirection()
		local effectPos
		if not self.aiming then
			effectPos = self.tool:getFpBonePos("pejnt_barrel")
		else
			effectPos = self.tool:getFpBonePos("pejnt_barrel") + dir * 0.45
		end

		self.shootEffectFP:setPosition(effectPos)
		self.shootEffectFP:setVelocity(self.tool:getMovementVelocity())
		self.shootEffectFP:setRotation(sm.vec3.getRotation(vec3_forward, dir))
	end

	local dir = self.tool:getTpBoneDir("pejnt_barrel")
	local effectPos = self.tool:getTpBonePos("pejnt_barrel") + dir * 0.2
	self.shootEffect:setPosition(effectPos)
	self.shootEffect:setVelocity(self.tool:getMovementVelocity())
	self.shootEffect:setRotation(sm.vec3.getRotation(vec3_forward, dir))

	self.windupEffect:setPosition(effectPos)

	-- Timers
	self.fireCooldownTimer = math.max(self.fireCooldownTimer - dt, 0.0)
	self.spreadCooldownTimer = math.max(self.spreadCooldownTimer - dt, 0.0)
	self.sprintCooldownTimer = math.max(self.sprintCooldownTimer - dt, 0.0)

	if self.isLocal then
		local dispersion = 0.0
		local fireMode = self.aiming and self.aimFireMode or self.normalFireMode
		local recoilDispersion = 1.0 - (math.max(fireMode.minDispersionCrouching, fireMode.minDispersionStanding) + fireMode.maxMovementDispersion)

		if isCrouching then
			dispersion = fireMode.minDispersionCrouching
		else
			dispersion = fireMode.minDispersionStanding
		end

		if self.tool:getRelativeMoveDirection():length() > 0 then
			dispersion = dispersion + fireMode.maxMovementDispersion * self.tool:getMovementSpeedFraction()
		end

		if not self.tool:isOnGround() then
			dispersion = dispersion * fireMode.jumpDispersionMultiplier
		end

		self.movementDispersion = dispersion

		self.spreadCooldownTimer = clamp(self.spreadCooldownTimer, 0.0, fireMode.spreadCooldown)
		local spreadFactor = fireMode.spreadCooldown > 0.0 and clamp(self.spreadCooldownTimer / fireMode.spreadCooldown, 0.0, 1.0) or 0.0

		self.tool:setDispersionFraction(clamp(self.movementDispersion + spreadFactor * recoilDispersion, 0.0, 1.0))

		if self.aiming then
			if self.tool:isInFirstPersonView() then
				self.tool:setCrossHairAlpha(0.0)
			else
				self.tool:setCrossHairAlpha(1.0)
			end
			self.tool:setInteractionTextSuppressed(true)
		else
			self.tool:setCrossHairAlpha(1.0)
			self.tool:setInteractionTextSuppressed(false)
		end
	end

	-- Sprint block
	local blockSprint = self.aiming or self.sprintCooldownTimer > 0.0
	self.tool:setBlockSprint(blockSprint)

	local playerDir = self.tool:getSmoothDirection()
	local angle = math.asin(playerDir:dot(sm.vec3.new(0, 0, 1))) / (math.pi / 2)

	local crouchWeight = isCrouching and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight

	local totalWeight = 0.0
	for name, animation in pairs(self.tpAnimations.animations) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min(animation.weight + (self.tpAnimations.blendSpeed * dt), 1.0)

			if animation.time >= animation.info.duration - self.blendTime then
				if (name == "shoot" or name == "aimShoot") then
					setTpAnimation(self.tpAnimations, self.aiming and "aim" or "idle", 10.0)
				elseif name == "pickup" then
					setTpAnimation(self.tpAnimations, self.aiming and "aim" or "idle", 0.001)
				elseif animation.nextAnimation ~= "" then
					setTpAnimation(self.tpAnimations, animation.nextAnimation, 0.001)
				end
			end
		else
			animation.weight = math.max(animation.weight - (self.tpAnimations.blendSpeed * dt), 0.0)
		end

		totalWeight = totalWeight + animation.weight
	end

	totalWeight = totalWeight == 0 and 1.0 or totalWeight
	for name, animation in pairs(self.tpAnimations.animations) do
		local weight = animation.weight / totalWeight
		if name == "idle" then
			self.tool:updateMovementAnimation(animation.time, weight)
		elseif animation.crouch then
			self.tool:updateAnimation(animation.info.name, animation.time, weight * normalWeight)
			self.tool:updateAnimation(animation.crouch.name, animation.time, weight * crouchWeight)
		else
			self.tool:updateAnimation(animation.info.name, animation.time, weight)
		end
	end

	-- Third Person joint lock
	local relativeMoveDirection = self.tool:getRelativeMoveDirection()
	if (((isAnyOf(self.tpAnimations.currentAnimation, { "aimInto", "aim", "shoot" }) and (relativeMoveDirection:length() > 0 or isCrouching)) or (self.aiming and (relativeMoveDirection:length() > 0 or isCrouching))) and not isSprinting) then
		self.jointWeight = math.min(self.jointWeight + (10.0 * dt), 1.0)
	else
		self.jointWeight = math.max(self.jointWeight - (6.0 * dt), 0.0)
	end

	if (not isSprinting) then
		self.spineWeight = math.min(self.spineWeight + (10.0 * dt), 1.0)
	else
		self.spineWeight = math.max(self.spineWeight - (10.0 * dt), 0.0)
	end

	local finalAngle = (0.5 + angle * 0.5)
	self.tool:updateAnimation("spudgun_spine_bend", finalAngle, self.spineWeight)

	local totalOffsetZ = lerp(-22.0, -26.0, crouchWeight)
	local totalOffsetY = lerp(6.0, 12.0, crouchWeight)
	local crouchTotalOffsetX = clamp((angle * 60.0) - 15.0, -60.0, 40.0)
	local normalTotalOffsetX = clamp((angle * 50.0), -45.0, 50.0)
	local totalOffsetX = lerp(normalTotalOffsetX, crouchTotalOffsetX, crouchWeight)
	local finalJointWeight = (self.jointWeight)
	self.tool:updateJoint("jnt_hips", sm.vec3.new(totalOffsetX, totalOffsetY, totalOffsetZ), 0.35 * finalJointWeight * (normalWeight))

	local crouchSpineWeight = (0.35 / 3) * crouchWeight
	self.tool:updateJoint("jnt_spine1", sm.vec3.new(totalOffsetX, totalOffsetY, totalOffsetZ), (0.10 + crouchSpineWeight) * finalJointWeight)
	self.tool:updateJoint("jnt_spine2", sm.vec3.new(totalOffsetX, totalOffsetY, totalOffsetZ), (0.10 + crouchSpineWeight) * finalJointWeight)
	self.tool:updateJoint("jnt_spine3", sm.vec3.new(totalOffsetX, totalOffsetY, totalOffsetZ), (0.45 + crouchSpineWeight) * finalJointWeight)
	self.tool:updateJoint("jnt_head", sm.vec3.new(totalOffsetX, totalOffsetY, totalOffsetZ), 0.3 * finalJointWeight)

	-- Camera update
	local bobbing = 1
	if self.aiming then
		local blend = 1 - math.pow(1 - 1 / self.aimBlendSpeed, dt * 60)
		self.aimWeight = sm.util.lerp(self.aimWeight, 1.0, blend)
		bobbing = 0.12
	else
		local blend = 1 - math.pow(1 - 1 / self.aimBlendSpeed, dt * 60)
		self.aimWeight = sm.util.lerp(self.aimWeight, 0.0, blend)
		bobbing = 1
	end

	self.tool:updateCamera(2.8, 30.0, sm.vec3.new(0.65, 0.0, 0.05), self.aimWeight)
	self.tool:updateFpCamera(30.0, sm.vec3.new(0.0, 0.0, 0.0), self.aimWeight, bobbing)

	self:cl_updateGatling(dt)
end

function LightningGatling.client_onEquip(self, animate)
	if animate then
		sm.audio.play("PotatoRifle - Equip", self.tool:getPosition())
	end

	self.windupEffect:start()
	self.wantEquipped = true
	self.aiming = false
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max(cameraWeight, cameraFPWeight)
	self.jointWeight = 0.0

	local currentRenderablesTp = {}
	local currentRenderablesFp = {}

	for k, v in pairs(renderablesTp) do currentRenderablesTp[#currentRenderablesTp + 1] = v end
	for k, v in pairs(renderablesFp) do currentRenderablesFp[#currentRenderablesFp + 1] = v end
	for k, v in pairs(renderables) do
		currentRenderablesTp[#currentRenderablesTp + 1] = v
		currentRenderablesFp[#currentRenderablesFp + 1] = v
	end

	self.tool:setTpRenderables(currentRenderablesTp)
	if self.isLocal then
		self.tool:setFpRenderables(currentRenderablesFp)
	end

	self:loadAnimations()

	setTpAnimation(self.tpAnimations, "pickup", 0.0001)
	if self.isLocal then
		swapFpAnimation(self.fpAnimations, "unequip", "equip", 0.2)
	end
end

function LightningGatling:client_onUnequip(animate)
	self.windupEffect:stop()
	self.wantEquipped = false
	self.equipped = false
	self.aiming = false
	if sm.exists(self.tool) then
		if animate then
			sm.audio.play("PotatoRifle - Unequip", self.tool:getPosition())
		end
		setTpAnimation(self.tpAnimations, "putdown")
		if self.isLocal then
			self.tool:setMovementSlowDown(false)
			self.tool:setBlockSprint(false)
			self.tool:setCrossHairAlpha(1.0)
			self.tool:setInteractionTextSuppressed(false)

			self.cl_chargedState = false
			self.network:sendToServer("sv_updateChargedState", false)

			if self.fpAnimations.currentAnimation ~= "unequip" then
				swapFpAnimation(self.fpAnimations, "equip", "unequip", 0.2)
			end
		end
	end
end

function LightningGatling:sv_n_onAim(aiming)
	self.network:sendToClients("cl_n_onAim", aiming)
end

function LightningGatling:cl_n_onAim(aiming)
	if not self.isLocal and self.tool:isEquipped() then
		self:onAim(aiming)
	end
end

function LightningGatling:onAim(aiming)
	self.aiming = aiming
	if self.tpAnimations.currentAnimation == "idle" or self.tpAnimations.currentAnimation == "aim" or self.tpAnimations.currentAnimation == "relax" and self.aiming then
		setTpAnimation(self.tpAnimations, self.aiming and "aim" or "idle", 5.0)
	end
end

function LightningGatling:sv_n_onShoot(charge)
	self.network:sendToClients("cl_n_onShoot", charge)
end

function LightningGatling:cl_n_onShoot(charge)
	self:onShoot(charge)
end

function LightningGatling:onShoot(charge)
	self.tpAnimations.animations.idle.time = 0
	self.tpAnimations.animations.shoot.time = 0
	self.tpAnimations.animations.aimShoot.time = 0

	setTpAnimation(self.tpAnimations, self.aiming and "aimShoot" or "shoot", 10.0)
	if self.isLocal then
		setFpAnimation(self.fpAnimations, self.aiming and "aimShoot" or "shoot", 0.05)

		local fireMode = self.aiming and self.aimFireMode or self.normalFireMode
		self.fireCooldownTimer = fireMode.fireCooldown
		self.spreadCooldownTimer = math.min(self.spreadCooldownTimer + fireMode.spreadIncrement, fireMode.spreadCooldown)
		self.sprintCooldownTimer = self.sprintCooldown
	end

	if self.tool:isInFirstPersonView() then
		self.shootEffectFP:start()
	else
		self.shootEffect:start()
	end

	self:cl_updateCharge(charge)
end

function LightningGatling:calculateFirePosition()
	local crouching = self.tool:isCrouching()
	local firstPerson = self.tool:isInFirstPersonView()
	local dir = sm.localPlayer.getDirection()
	local pitch = math.asin(dir.z)
	local right = sm.localPlayer.getRight()

	local fireOffset = sm.vec3.new(0.0, 0.0, 0.0)

	if crouching then
		fireOffset.z = 0.15
	else
		fireOffset.z = 0.45
	end

	if firstPerson then
		if not self.aiming then
			fireOffset = fireOffset + right * 0.05
		end
	else
		fireOffset = fireOffset + right * 0.25
		fireOffset = fireOffset:rotate(math.rad(pitch), right)
	end
	local firePosition = GetOwnerPosition(self.tool) + fireOffset
	return firePosition
end

function LightningGatling:sv_updateChargedState(state)
	self.sv_chargedState = state
end

function LightningGatling:sv_updateFiring(firing)
	self.network:sendToClients("cl_updateFiring", firing)
end

function LightningGatling:cl_updateFiring(firing)
	self.gatlingActive = firing
end

function LightningGatling:server_onFixedUpdate(dt)
	self.sv_fireCooldownTimer = math.max(self.sv_fireCooldownTimer - dt, 0)
	if not self.sv_chargedState or self.sv_fireCooldownTimer > 0 then return end

	local owner = self.tool:getOwner()
	if self.sv_charge <= 0 then
		local inv = owner:getInventory()
		if not inv:canSpend(obj_consumable_battery, 1) then return end

		sm.container.beginTransaction()
		sm.container.spend(inv, obj_consumable_battery, 1)
		sm.container.endTransaction()

		self.sv_charge = MaxCharge
		self.storage:save(self.sv_charge)
		self.network:sendToClients("cl_updateCharge", self.sv_charge)

		self.sv_fireCooldownTimer = MagRechargeCooldown
		return
	end

	local hit, result, endPos = self:doLightningCast(owner)
	local skipExplosion = false
	local turretBase = result:getShape()
	if turretBase then
		local int = turretBase.interactable
		if int and int:getType() == "scripted" then
			local fData = sm.item.getFeatureData(turretBase.uuid)
			if fData and fData.classname == "Package" then
				sm.event.sendToInteractable(int, "sv_e_open")
			else
				local pData = int.publicData or {}
				if pData.isTurret == true then
					if pData.health < pData.maxHealth then
						sm.event.sendToInteractable(int, "sv_takeDamage", -TurretHealAmount)
						skipExplosion = true
					else
						return
					end
				end
			end
		end
	end

	local turretSeat = result:getHarvestable()
	if turretSeat then
		local pData = turretSeat.publicData or {}
		if pData.isTurret == true then
			if pData.health < pData.maxHealth then
				sm.event.sendToInteractable(pData.base, "sv_takeDamage", -TurretHealAmount)
				skipExplosion = true
			else
				return
			end
		end
	end

	--[[local char = result:getCharacter()
	if char and not char:isPlayer() then
		local dir = owner.character.direction
		sm.melee.meleeAttack(sm.uuid.new( "d9527b06-aeef-4fb9-88be-61361c8e95b6" ), 0, endPos - dir, dir * 2.5, owner)
	end]]

	if not skipExplosion then
		sm.physics.explode(endPos, 3, 1, 5, 10, "PropaneTank - ExplosionSmall")
	end

	self.sv_fireCooldownTimer = FireCooldown
	self.sv_charge = self.sv_charge - 1
	self:sv_n_onShoot(self.sv_charge)
end

---@param owner Player
function LightningGatling:doLightningCast(owner)
	local char = owner.character
	local startPos = char.worldPosition
	if char:isCrouching() then
		startPos = startPos + sm.vec3.new(0,0,0.3)
	else
		startPos = startPos + sm.vec3.new(0,0,0.575)
	end

	local endPos = startPos + char.direction * Range
	local hit, result = sm.physics.raycast(startPos, endPos, char)
	return hit, result, hit and result.pointWorld or endPos
end


function LightningGatling:cl_updateCharge(charge)
	self.cl_charge = charge
end

function LightningGatling:cl_updateGatling(dt)
	local canFire = (self.isLocal and sm.localPlayer.getPlayer():getInventory():canSpend(obj_consumable_battery, 1)) or self.cl_charge > 0
	if canFire and self.gatlingActive then
		self.gatlingWeight = math.min(self.gatlingWeight + self.gatlingBlendSpeedIn * dt, 1)
	else
		self.gatlingWeight = math.max(self.gatlingWeight - self.gatlingBlendSpeedIn * dt, 0)
	end
	local frac
	frac, self.gatlingTurnFraction = math.modf(self.gatlingTurnFraction + self.gatlingTurnSpeed * self.gatlingWeight * dt)

	self.windupEffect:setParameter("velocity", self.gatlingWeight)
	if self.equipped and not self.windupEffect:isPlaying() then
		self.windupEffect:start()
	elseif not self.equipped and self.windupEffect:isPlaying() then
		self.windupEffect:stop()
	end

	-- Update gatling animation
	if self.isLocal then
		self.tool:updateFpAnimation("spudgun_spinner_shoot_fp", self.gatlingTurnFraction, 1.0, true)

		local charged = self.gatlingWeight >= 1
		if self.cl_chargedState ~= charged then
			self.cl_chargedState = charged
			self.network:sendToServer("sv_updateChargedState", charged)
		end
	end
	self.tool:updateAnimation("spudgun_spinner_shoot_tp", self.gatlingTurnFraction, 1.0)
end

function LightningGatling:client_onEquippedUpdate(primaryState, secondaryState)
	local firing = primaryState == 1 or primaryState == 2
	if firing ~= self.gatlingActive then
		self.gatlingActive = firing
		self.network:sendToServer("sv_updateFiring", firing)
	end

	if secondaryState ~= self.prevSecondaryState then
		self:cl_onSecondaryUse(secondaryState)
		self.prevSecondaryState = secondaryState
	end

	sm.gui.setProgressFraction(self.cl_charge/MaxCharge)

	return true, true
end

function LightningGatling:cl_onSecondaryUse(state)
	local aiming = state == 1 or state == 2
	if aiming ~= self.aiming then
		self.aiming = aiming
		self.tpAnimations.animations.idle.time = 0

		self:onAim(aiming)
		self.tool:setMovementSlowDown(aiming)
		self.network:sendToServer("sv_n_onAim", aiming)
	end
end

function LightningGatling:client_onReload()
	return true
end

function LightningGatling:client_onToggle()
	return true
end



function LightningGatling:calculateTpMuzzlePos()
	local crouching = self.tool:isCrouching()
	local dir = sm.localPlayer.getDirection()
	local pitch = math.asin(dir.z)
	local right = sm.localPlayer.getRight()
	local up = right:cross(dir)

	local fakeOffset = sm.vec3.new(0.0, 0.0, 0.0)

	--General offset
	fakeOffset = fakeOffset + right * 0.25
	fakeOffset = fakeOffset + dir * 0.5
	fakeOffset = fakeOffset + up * 0.25

	--Action offset
	local pitchFraction = pitch / (math.pi * 0.5)
	if crouching then
		fakeOffset = fakeOffset + dir * 0.2
		fakeOffset = fakeOffset + up * 0.1
		fakeOffset = fakeOffset - right * 0.05

		if pitchFraction > 0.0 then
			fakeOffset = fakeOffset - up * 0.2 * pitchFraction
		else
			fakeOffset = fakeOffset + up * 0.1 * math.abs(pitchFraction)
		end
	else
		fakeOffset = fakeOffset + up * 0.1 * math.abs(pitchFraction)
	end

	local fakePosition = fakeOffset + GetOwnerPosition(self.tool)
	return fakePosition
end

function LightningGatling:calculateFpMuzzlePos()
	local fovScale = (sm.camera.getFov() - 45) / 45

	local up = sm.localPlayer.getUp()
	local dir = sm.localPlayer.getDirection()
	local right = sm.localPlayer.getRight()

	local muzzlePos45 = sm.vec3.new(0.0, 0.0, 0.0)
	local muzzlePos90 = sm.vec3.new(0.0, 0.0, 0.0)

	if self.aiming then
		muzzlePos45 = muzzlePos45 - up * 0.2
		muzzlePos45 = muzzlePos45 + dir * 0.5

		muzzlePos90 = muzzlePos90 - up * 0.5
		muzzlePos90 = muzzlePos90 - dir * 0.6
	else
		muzzlePos45 = muzzlePos45 - up * 0.15
		muzzlePos45 = muzzlePos45 + right * 0.2
		muzzlePos45 = muzzlePos45 + dir * 1.25

		muzzlePos90 = muzzlePos90 - up * 0.15
		muzzlePos90 = muzzlePos90 + right * 0.2
		muzzlePos90 = muzzlePos90 + dir * 0.25
	end

	return self.tool:getFpBonePos("pejnt_barrel") + sm.vec3.lerp(muzzlePos45, muzzlePos90, fovScale)
end

function LightningGatling:loadAnimations()
	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			shoot = { "spudgun_shoot", { crouch = "spudgun_crouch_shoot" } },
			aim = { "spudgun_aim", { crouch = "spudgun_crouch_aim" } },
			aimShoot = { "spudgun_aim_shoot", { crouch = "spudgun_crouch_aim_shoot" } },
			idle = { "spudgun_idle" },
			pickup = { "spudgun_pickup", { nextAnimation = "idle" } },
			putdown = { "spudgun_putdown" }
		}
	)
	local movementAnimations = {
		idle = "spudgun_idle",
		idleRelaxed = "spudgun_relax",

		sprint = "spudgun_sprint",
		runFwd = "spudgun_run_fwd",
		runBwd = "spudgun_run_bwd",

		jump = "spudgun_jump",
		jumpUp = "spudgun_jump_up",
		jumpDown = "spudgun_jump_down",

		land = "spudgun_jump_land",
		landFwd = "spudgun_jump_land_fwd",
		landBwd = "spudgun_jump_land_bwd",

		crouchIdle = "spudgun_crouch_idle",
		crouchFwd = "spudgun_crouch_fwd",
		crouchBwd = "spudgun_crouch_bwd"
	}

	for name, animation in pairs(movementAnimations) do
		self.tool:setMovementAnimation(name, animation)
	end

	setTpAnimation(self.tpAnimations, "idle", 5.0)

	if self.isLocal then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				equip = { "spudgun_pickup", { nextAnimation = "idle" } },
				unequip = { "spudgun_putdown" },

				idle = { "spudgun_idle", { looping = true } },
				shoot = { "spudgun_shoot", { nextAnimation = "idle" } },

				aimInto = { "spudgun_aim_into", { nextAnimation = "aimIdle" } },
				aimExit = { "spudgun_aim_exit", { nextAnimation = "idle", blendNext = 0 } },
				aimIdle = { "spudgun_aim_idle", { looping = true } },
				aimShoot = { "spudgun_aim_shoot", { nextAnimation = "aimIdle" } },

				sprintInto = { "spudgun_sprint_into", { nextAnimation = "sprintIdle", blendNext = 0.2 } },
				sprintExit = { "spudgun_sprint_exit", { nextAnimation = "idle", blendNext = 0 } },
				sprintIdle = { "spudgun_sprint_idle", { looping = true } },
			}
		)
	end

	self.normalFireMode = {
		fireCooldown = 0.1,
		spreadCooldown = 0.18,
		spreadIncrement = 3.9,
		spreadMinAngle = 0.25,
		spreadMaxAngle = 32,
		fireVelocity = 130.0,

		minDispersionStanding = 0.1,
		minDispersionCrouching = 0.04,

		maxMovementDispersion = 0.4,
		jumpDispersionMultiplier = 2
	}

	self.aimFireMode = {
		fireCooldown = 0.1,
		spreadCooldown = 0.18,
		spreadIncrement = 1.95,
		spreadMinAngle = 0.25,
		spreadMaxAngle = 24,
		fireVelocity = 130.0,

		minDispersionStanding = 0.01,
		minDispersionCrouching = 0.01,

		maxMovementDispersion = 0.4,
		jumpDispersionMultiplier = 2
	}

	self.fireCooldownTimer = 0.0
	self.spreadCooldownTimer = 0.0

	self.movementDispersion = 0.0

	self.sprintCooldownTimer = 0.0
	self.sprintCooldown = 0.3

	self.aimBlendSpeed = 3.0
	self.blendTime = 0.2

	self.jointWeight = 0.0
	self.spineWeight = 0.0
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max(cameraWeight, cameraFPWeight)

	self.gatlingActive = false
	self.gatlingBlendSpeedIn = 1.5
	self.gatlingBlendSpeedOut = 0.375
	self.gatlingWeight = 0.0
	self.gatlingTurnSpeed = (1 / self.normalFireMode.fireCooldown) / 3
	self.gatlingTurnFraction = 0.0
end