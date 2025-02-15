dofile "$GAME_DATA/Scripts/game/Explosive.lua"

---@class CannonNuke : ShapeClass
---@field alive boolean
---@field counting boolean
---@field fireDelayProgress number
---@field destructionRadius number
---@field destructionLevel number
---@field impulseRadius number
---@field impulseMagnitude number
---@field explosionEffectName EffectName
CannonNuke = class(Explosive)

---@param caller Player
function CannonNuke:sv_pickup(slot, caller)
	sm.container.beginTransaction()
	if sm.game.getLimitedInventory() then
		sm.container.collect(caller:getInventory(), self.shape.uuid, 1)
	else
		sm.container.collectToSlot(caller:getHotbar(), slot, self.shape.uuid, 1)
	end
	sm.container.endTransaction()

	sm.effect.playEffect("Part - Removed", self.shape.worldPosition)
	self.shape:destroyShape()
end

function CannonNuke.server_tryExplode( self )
	if self.alive and self.shape.body.destructable then
		self.alive = false
		self.counting = false
		self.fireDelayProgress = 0

		local contacts = sm.physics.getSphereContacts(self.shape.worldPosition, self.destructionRadius)
		for k, body in pairs(contacts.bodies) do
			for _k, int in pairs(body:getInteractables()) do
				if sm.item.isHarvestablePart(int.shape.uuid) then
					sm.event.sendToInteractable(int, "sv_markDeath")
				end
			end
		end

		for k, harvestable in pairs(contacts.harvestables) do
			local data = harvestable:getData()
			if not data then goto continue end

			local blueprint = data.blueprint
			if blueprint then
				local placementOffset = sm.vec3.new( -0.5, -0.5, -0.5 )
				if data.offset then
					placementOffset = sm.vec3.new( data.offset.x, data.offset.y, data.offset.z )
				end
				placementOffset = harvestable.worldRotation * placementOffset

				local isTree = data.crownHeight ~= nil
				if isTree then
					sm.effect.playEffect( "Tree - LogAppear", harvestable.worldPosition )
				end

				local colour = harvestable:getColor()
				local bodies = sm.creation.importFromFile( nil, blueprint, harvestable.worldPosition + placementOffset, harvestable.worldRotation )
				for i, body in pairs(bodies) do
					for _k, int in pairs(body:getInteractables()) do
						local shape = int.shape
						shape:setColor(colour)
						int:setParams( { markedForDeath = true } )

						if isTree then
							local fData = sm.item.getFeatureData(shape.uuid)
							if fData and fData.data.fallenEffects then
								local rotation = shape.worldRotation
								for _, effect in ipairs( fData.data.fallenEffects ) do
									local offsetPosition = sm.vec3.new( effect.offsetPosition.x, effect.offsetPosition.y, effect.offsetPosition.z )
									sm.effect.playEffect( effect.effectName, shape.worldPosition + rotation * offsetPosition, nil, rotation, nil, { Color = colour } )
								end
							end
						end
					end
				end

				harvestable:destroy()
			end

		    ::continue::
		end

		-- Create explosion
		sm.physics.explode( self.shape.worldPosition, self.destructionLevel, self.destructionRadius, self.impulseRadius, self.impulseMagnitude, self.explosionEffectName, self.shape )
		sm.shape.destroyPart( self.shape )
	end
end

function CannonNuke:client_canInteract()
	local canPickup = (sm.game.getLimitedInventory() and sm.localPlayer.getPlayer():getInventory() or sm.localPlayer.getPlayer():getHotbar()):canCollect(self.shape.uuid, 1)
	if canPickup then
		sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use", true), "Pick up")
	end

	return canPickup
end

function CannonNuke:client_onInteract(char, state)
	if not state then return end

	self.network:sendToServer("sv_pickup", sm.localPlayer.getSelectedHotbarSlot())
end



dofile( "$GAME_DATA/Scripts/game/AnimationUtil.lua")
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )

---@class CannonNuke_Tool : ToolClass
---@field activeItem Uuid?
---@field wasOnGround boolean
---@field wantEquipped boolean
---@field equipped boolean
---@field isLocal boolean
---@field tpAnimations table
---@field fpAnimations table
---@field fireCooldownTimer number
---@field blendNext number
---@field blendTime number
CannonNuke_Tool = class()

local renderables = {
	["47b43e6e-280d-497e-9896-a3af721d89d2"] = { "$CONTENT_DATA/Tools/Renderables/char_nuke.rend" }, 						--Nuclear Bomb
	["8d3b98de-c981-4f05-abfe-d22ee4781d33"] = { "$CONTENT_DATA/Tools/Renderables/char_explosive_small.rend" }, 			--Small Explosive
	["24001201-40dd-4950-b99f-17d878a9e07b"] = { "$CONTENT_DATA/Tools/Renderables/char_explosive_large.rend" }, 			--Large Explosive
	["254360f7-ba19-431d-ac1a-92c1ee9ba483"] = { "$CONTENT_DATA/Tools/Renderables/char_big_potato.rend" }					--Big Potato
}
local renderablesTp = {
    "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_bucket.rend",
    "$SURVIVAL_DATA/Character/Char_bucket/char_bucket_tp_animlist.rend"
}
local renderablesFp = {
    "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_bucket.rend",
    "$SURVIVAL_DATA/Character/Char_bucket/char_bucket_fp_animlist.rend"
}

for k, v in pairs(renderables) do
	sm.tool.preloadRenderables( v )
end

sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

function CannonNuke_Tool:client_onCreate()
    self.isLocal = self.tool:isLocal()

    if self.isLocal then
		self.activeItem = nil
		self.wasOnGround = true
	end

	self:loadAnimations()
end

function CannonNuke_Tool.loadAnimations( self )
	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			idle = { "bucket_idle", { looping = true } },
			use = { "bucket_use_full", { nextAnimation = "idle" } },
			useempty = { "bucket_use_empty", { nextAnimation = "idle" } },
			pickup = { "bucket_pickup", { nextAnimation = "idle" } },
			putdown = { "bucket_putdown" }
		}
	)
	local movementAnimations = {
		idle = "bucket_idle",

		runFwd = "bucket_run",
		runBwd = "bucket_runbwd",

		sprint = "bucket_sprint_idle",

		jump = "bucket_jump",
		jumpUp = "bucket_jump_up",
		jumpDown = "bucket_jump_down",

		land = "bucket_jump_land",
		landFwd = "bucket_jump_land_fwd",
		landBwd = "bucket_jump_land_bwd",

		crouchIdle = "bucket_crouch_idle",
		crouchFwd = "bucket_crouch_run",
		crouchBwd = "bucket_crouch_runbwd"
	}

	for name, animation in pairs( movementAnimations ) do
		self.tool:setMovementAnimation( name, animation )
	end

	setTpAnimation( self.tpAnimations, "idle", 5.0 )

	if self.isLocal then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				idle = { "bucket_idle", { looping = true } },
				use = { "bucket_use_full", { nextAnimation = "idle" } },
				useempty = { "bucket_use_empty", { nextAnimation = "idle" } },

				sprintInto = { "bucket_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
				sprintIdle = { "bucket_sprint_idle", { looping = true } },
				sprintExit = { "bucket_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },

				jump = { "bucket_jump", { nextAnimation = "idle" } },
				land = { "bucket_jump_land", { nextAnimation = "idle" } },

				equip = { "bucket_pickup", { nextAnimation = "idle" } },
				unequip = { "bucket_putdown" }
			}
		)
	end

	self.fireCooldownTimer = 0.0
	self.blendTime = 0.2
end

function CannonNuke_Tool:client_onUpdate( dt )

	-- First person animation	
	local isSprinting =  self.tool:isSprinting()
	local isCrouching =  self.tool:isCrouching()
	local isOnGround =  self.tool:isOnGround()

	if self.isLocal then
		if self.equipped then
			if isSprinting and self.fpAnimations.currentAnimation ~= "sprintInto" and self.fpAnimations.currentAnimation ~= "sprintIdle" then
				swapFpAnimation( self.fpAnimations, "sprintExit", "sprintInto", 0.0 )
			elseif not self.tool:isSprinting() and ( self.fpAnimations.currentAnimation == "sprintIdle" or self.fpAnimations.currentAnimation == "sprintInto" ) then
				swapFpAnimation( self.fpAnimations, "sprintInto", "sprintExit", 0.0 )
			end

			if not isOnGround and self.wasOnGround and self.fpAnimations.currentAnimation ~= "jump" then
				swapFpAnimation( self.fpAnimations, "land", "jump", 0.2 )
			elseif isOnGround and not self.wasOnGround and self.fpAnimations.currentAnimation ~= "land" then
				swapFpAnimation( self.fpAnimations, "jump", "land", 0.2 )
			end

			local newItem = sm.localPlayer.getActiveItem()
			if self.activeItem ~= newItem and renderables[tostring(newItem)] ~= nil then
				self.activeItem = newItem
				self:cl_updateRenderable(self.activeItem)
				self.network:sendToServer( "sv_updateRenderable", self.activeItem )
			end
		end
		updateFpAnimations( self.fpAnimations, self.equipped, dt )

		self.wasOnGround = isOnGround
	end

	if not self.equipped then
		if self.wantEquipped then
			self.wantEquipped = false
			self.equipped = true
		end
		return
	end

	local crouchWeight = isCrouching and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight
	local totalWeight = 0.0

	for name, animation in pairs( self.tpAnimations.animations or {} ) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min( animation.weight + ( self.tpAnimations.blendSpeed * dt ), 1.0 )

			if animation.time >= animation.info.duration - self.blendTime then
				if ( name == "use" or name == "useempty" ) then
					setTpAnimation( self.tpAnimations, "idle", 10.0 )
				elseif name == "pickup" then
					setTpAnimation( self.tpAnimations, "idle", 0.001 )
				elseif animation.nextAnimation ~= "" then
					setTpAnimation( self.tpAnimations, animation.nextAnimation, 0.001 )
				end
			end
		else
			animation.weight = math.max( animation.weight - ( self.tpAnimations.blendSpeed * dt ), 0.0 )
		end

		totalWeight = totalWeight + animation.weight
	end

	totalWeight = totalWeight == 0 and 1.0 or totalWeight
	for name, animation in pairs( self.tpAnimations.animations ) do
		local weight = animation.weight / totalWeight
		if name == "idle" then
			self.tool:updateMovementAnimation( animation.time, weight )
		elseif animation.crouch then
			self.tool:updateAnimation( animation.info.name, animation.time, weight * normalWeight )
			self.tool:updateAnimation( animation.crouch.name, animation.time, weight * crouchWeight )
		else
			self.tool:updateAnimation( animation.info.name, animation.time, weight )
		end
	end

	-- Timers
	self.fireCooldownTimer = math.max( self.fireCooldownTimer - dt, 0.0 )
end


function CannonNuke_Tool:client_onToggle()
	return false
end

function CannonNuke_Tool:client_onEquip()
	self.wantEquipped = true

	if self.tool:isLocal() then
		local item = sm.localPlayer.getActiveItem()
		if renderables[tostring(item)] == nil then return end

		self.activeItem = item
		self:cl_updateRenderable(item)
		self.network:sendToServer( "sv_updateRenderable", item )
	end
end

function CannonNuke_Tool:sv_updateRenderable(item)
	self.network:sendToClients("cl_updateRenderable", item)
end

function CannonNuke_Tool:cl_updateRenderable(item)
	local currentRenderablesTp = {}
	local currentRenderablesFp = {}
	for k,v in pairs( renderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	for k,v in pairs( renderables[tostring(item)] ) do
        currentRenderablesTp[#currentRenderablesTp+1] = v
        currentRenderablesFp[#currentRenderablesFp+1] = v
    end

	local color = sm.item.getShapeDefaultColor( item )
	self.tool:setTpRenderables( currentRenderablesTp )
	self.tool:setTpColor( color )
	if self.isLocal then
        self.tool:setFpRenderables( currentRenderablesFp )
		self.tool:setFpColor( color )
	end

    self:loadAnimations()
	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )
	if self.isLocal then
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function CannonNuke_Tool:client_onUnequip()
    self.wantEquipped = false
	self.equipped = false

    if sm.exists( self.tool ) then
		setTpAnimation( self.tpAnimations, "putdown" )
		if self.isLocal and self.fpAnimations.currentAnimation ~= "unequip" then
			swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
		end
	end
end

local cannonUUIDs = {
	["f2efb390-b77d-4587-b2ce-b895698e2fd5"] = true,
	["0af5379e-29e8-4eb3-b965-6b3993c8f1df"] = true,
}

local titles = {
	["47b43e6e-280d-497e-9896-a3af721d89d2"] = "Nuke", 				--Nuclear Bomb
	["8d3b98de-c981-4f05-abfe-d22ee4781d33"] = "Small Explosive", 	--Small Explosive
	["24001201-40dd-4950-b99f-17d878a9e07b"] = "Large Explosive", 	--Large Explosive
	["254360f7-ba19-431d-ac1a-92c1ee9ba483"] = "Potato"				--Big Potato
}

function CannonNuke_Tool:client_onEquippedUpdate( lmb, rmb, f )
    if not f then
		local title = titles[tostring(sm.localPlayer.getActiveItem())]
		if not title then return true, true end

        local rayStart = sm.localPlayer.getRaycastStart()
        local rayDir = sm.localPlayer.getDirection()
        local hit, result = sm.physics.raycast( rayStart, rayStart + rayDir * 7.5, sm.localPlayer.getPlayer().character )

		---@type Harvestable|Shape
        local cannon = result:getHarvestable() or result:getShape()
        local isCannon = cannon and cannonUUIDs[tostring(cannon.uuid)] == true
        if isCannon then
			local cPub = type(cannon) == "Harvestable" and cannon.clientPublicData or sm.GetInteractableClientPublicData(cannon.interactable)
			if not cPub.controlsEnabled then
            	sm.gui.setInteractionText("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>Cannon is in use!</p>")
				return true, false
			end

			if cPub.isBarrelLoaded then
            	sm.gui.setInteractionText("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>A projectile is already loaded!</p>")
				return true, false
			end

			sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Load "..title)

			if lmb == 1 then
				self.network:sendToServer(
					"sv_loadNuke",
					{
						cannon = type(cannon) == "Harvestable" and cannon or cannon.interactable,
						consumeData = {
							selectedSlot = sm.localPlayer.getSelectedHotbarSlot(),
							item = sm.localPlayer.getActiveItem(),
							container = sm.game.getLimitedInventory() and sm.localPlayer.getInventory() or sm.localPlayer.getHotbar()
						}
					}
				)
			end
        else
            sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Toss "..title)

			if lmb == 1 or lmb == 2 then
                self:cl_toss()
			end
        end

        return true, false
    end

	return false, false
end

function CannonNuke_Tool:sv_consumeNuke(params)
    if not sm.game.getLimitedInventory() then
        return true
    end

    sm.container.beginTransaction()
    sm.container.spendFromSlot( params.container, params.selectedSlot, params.item, 1, true )
    return sm.container.endTransaction()
end

function CannonNuke_Tool:sv_loadNuke(nuke)
    if not self:sv_consumeNuke(nuke.consumeData) then return end

    SendEventToObject(nuke.cannon, "sv_loadNuke", nuke.consumeData.item)
    self.network:sendToClients( "cl_onUse" )
end

function CannonNuke_Tool:cl_toss()
	if self.fireCooldownTimer <= 0.0 then
		local item = sm.localPlayer.getActiveItem()
		if sm.container.canSpend( sm.localPlayer.getInventory(), item, 1 ) then
			local dir = sm.localPlayer.getDirection()
			local forward = sm.vec3.new( 0, 0, 1 ):cross( sm.localPlayer.getRight() )
			local pitchScale = forward:dot( dir )
			dir = dir:rotate( math.rad( pitchScale * 18 ), sm.camera.getRight() )

			local params = {
                firePos = self:calculateFirePosition(),
                item = item,
                dir = dir,
                selectedSlot = sm.localPlayer.getSelectedHotbarSlot(),
                container = sm.game.getLimitedInventory() and sm.localPlayer.getInventory() or sm.localPlayer.getHotbar()
            }

			self.network:sendToServer( "sv_n_onUse", params )
			self:cl_onUse()

			self.fireCooldownTimer = 1
		end
	end
end

function CannonNuke_Tool:sv_n_onUse(params)
    if not self:sv_consumeNuke(params) then return end

	local item = params.item
    local dir = params.dir
    local rot = sm.vec3.getRotation(vec3_forward, dir)
    local nuke = sm.shape.createPart(item, params.firePos + dir - rot * sm.item.getShapeOffset(item), rot, true, true )
    sm.physics.applyImpulse(nuke, (self.tool:getOwner().character.velocity + dir * 10) * nuke.mass, true)

    self.network:sendToClients( "cl_n_onUse" )
end

function CannonNuke_Tool:cl_n_onUse()
	if not self.isLocal then
		self:cl_onUse()
	end
end

function CannonNuke_Tool:cl_onUse()
	self.tpAnimations.animations.idle.time = 0
	setTpAnimation( self.tpAnimations, "use", 10.0 )

    if self.isLocal then
		setFpAnimation( self.fpAnimations, "use", 0.25 )
    end

	sm.audio.play( "Sledgehammer - Swing", self.tool:getOwner():getCharacter().worldPosition )
end



function CannonNuke_Tool:calculateFirePosition()
	local crouching = self.tool:isCrouching()
	local firstPerson = self.tool:isInFirstPersonView()
	local dir = sm.localPlayer.getDirection()
	local pitch = math.asin( dir.z )
	local right = sm.localPlayer.getRight()
	local fireOffset = sm.vec3.new( 0.0, 0.0, 0.0 )

	if crouching then
		fireOffset.z = 0.15
	else
		fireOffset.z = 0.45
	end

	if firstPerson then
        fireOffset = fireOffset + right * 0.05
	else
		fireOffset = fireOffset + right * 0.25
		fireOffset = fireOffset:rotate( math.rad( pitch ), right )
	end
	local firePosition = GetOwnerPosition( self.tool ) + fireOffset
	return firePosition
end