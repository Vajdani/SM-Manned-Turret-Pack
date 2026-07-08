---@diagnostic disable: undefined-global

-- #region Player
dofile( "$GAME_DATA/Scripts/game/BasePlayer.lua" )

mannedTurret_oldPlayerClientCreate = mannedTurret_oldPlayerClientCreate or BasePlayer.client_onCreate
function BasePlayer:client_onCreate()
	mannedTurret_oldPlayerClientCreate(self)

	sm.BASEPLAYERENABLED = true

	if g_survivalHud then
		sm.SURVIVALHUD = g_survivalHud
	end
end
-- #endregion



-- #region Lift
sm.MANNEDTURRET_turretBases_clientPublicData = sm.MANNEDTURRET_turretBases_clientPublicData or {}
local LiftReplacement = {}
function LiftReplacement.client_onEquippedUpdate( self, primaryState, secondaryState )
	if self.tool:isLocal() and self.equipped and sm.localPlayer.getPlayer():getCharacter() then
		local success, raycastResult = sm.localPlayer.getRaycast( 7.5 )
		return true, self:client_interact( primaryState, secondaryState, raycastResult )
	end
	return true, false
end

function LiftReplacement:checkForTurret(result)
	if #self.selectedBodies > 0 then return end

	local harvestable = result:getHarvestable()
	local base = (harvestable.clientPublicData or {}).base
	if base then
		return base.shape.body
	end
end

---@param raycastResult RaycastResult
function LiftReplacement.client_interact( self, primaryState, secondaryState, raycastResult )
	local targetBody = nil
	local blockDelete = false

	if self.importBodies then
		self.selectedBodies = self.importBodies
		self.importBodies = nil
	end

	--Clear states
	if secondaryState == 1 and #self.selectedBodies > 0 then
		self.hoverBodies = {}
		self.selectedBodies = {}

		sm.tool.forceTool( nil )
		self.forced = false
		blockDelete = true
	end

	--Raycast
	if raycastResult.valid then
		if raycastResult.type == "joint" then
			targetBody = raycastResult:getJoint().shapeA.body
		elseif raycastResult.type == "body" then
			targetBody = raycastResult:getBody()
		elseif raycastResult.type == "harvestable" then
			targetBody = self:checkForTurret(raycastResult)
		end

		local liftPos = raycastResult.pointWorld * 4
		self.liftPos = sm.vec3.new( math.floor( liftPos.x + 0.5 ), math.floor( liftPos.y + 0.5 ), math.floor( liftPos.z + 0.5 ) )
	end

	local isSelectable = false
	local isCarryable = false
	if self.selectedBodies[1] then
		if sm.exists( self.selectedBodies[1] ) and self.selectedBodies[1]:isDynamic() and self.selectedBodies[1]:isLiftable() then
			local isLiftable = true
			isCarryable = true
			for _, body in ipairs( self.selectedBodies[1]:getCreationBodies() ) do
				for _, shape in ipairs( body:getShapes() ) do
					if not shape.liftable then
						isLiftable = false
						break
					end
				end
				if not body:isDynamic() or not isLiftable then
					isCarryable = false
					break
				end
			end
		end
	elseif targetBody then
		if targetBody:isDynamic() and targetBody:isLiftable() then
			local isLiftable = true
			isSelectable = true
			for _, body in ipairs( targetBody:getCreationBodies() ) do
				for _, shape in ipairs( body:getShapes() ) do
					if not shape.liftable then
						isLiftable = false
						break
					end
				end
				if not body:isDynamic() or not isLiftable then
					isSelectable = false
					break
				end
			end
		end
	end

	--Hover
	if isSelectable and #self.selectedBodies == 0 then
		self.hoverBodies = targetBody and targetBody:getCreationBodies() or {}
	else
		self.hoverBodies = {}
	end

	-- Unselect invalid bodies
	if #self.selectedBodies > 0 and not isCarryable and not self.forced then
		self.selectedBodies = {}
	end

	--Check lift collision and if placeable surface
	local isPlaceable = self:checkPlaceable(raycastResult) 

	--Lift level
	local okPosition, liftLevel = sm.tool.checkLiftCollision( self.selectedBodies, self.liftPos, self.rotationIndex )
	isPlaceable = isPlaceable and okPosition

	--Pickup
	if primaryState == sm.tool.interactState.start then

		if isSelectable and #self.selectedBodies == 0 then
			self.selectedBodies = self.hoverBodies
			self.hoverBodies = {}
		elseif isPlaceable then
			local placeLiftParams = { player = sm.localPlayer.getPlayer(), selectedBodies = self.selectedBodies, liftPos = self.liftPos, liftLevel = liftLevel, rotationIndex = self.rotationIndex }
			self.network:sendToServer( "server_placeLift", placeLiftParams )
			self.selectedBodies = {}
		end

		sm.tool.forceTool( nil )
		self.forced = false
	end

	--Visualization
	sm.visualization.setCreationValid( isPlaceable, false )
	sm.visualization.setLiftValid( isPlaceable )

	if raycastResult.valid then
		local showLift = #self.hoverBodies == 0
		sm.visualization.setLiftPosition( self.liftPos * 0.25 )
		sm.visualization.setLiftLevel( liftLevel )
		sm.visualization.setLiftVisible( showLift )

		if #self.selectedBodies > 0 then
			sm.visualization.setCreationBodies( self.selectedBodies )
			sm.visualization.setCreationFreePlacement( true )
			sm.visualization.setCreationFreePlacementPosition( self.liftPos * 0.25 + sm.vec3.new(0,0,0.5) + sm.vec3.new(0,0,0.25) * liftLevel )
			sm.visualization.setCreationFreePlacementRotation( self.rotationIndex )
			sm.visualization.setCreationVisible( true )

			sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Create", true ), "#{INTERACTION_PLACE_LIFT_ON_GROUND}" )
		elseif #self.hoverBodies > 0 then
			sm.visualization.setCreationBodies( self.hoverBodies )
			sm.visualization.setCreationFreePlacement( false )		
			sm.visualization.setCreationValid( true, true )
			sm.visualization.setLiftValid( true )
			sm.visualization.setCreationVisible( true )

			sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Create", true ), "#{INTERACTION_PLACE_CREATION_ON_LIFT}" )
		else
			sm.visualization.setCreationBodies( {} )
			sm.visualization.setCreationFreePlacement( false )
			sm.visualization.setCreationVisible( false )

			if isPlaceable then
				sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Create", true ), "#{INTERACTION_PLACE_LIFT}" )
			end
		end
	else
		sm.visualization.setCreationVisible( false )
		sm.visualization.setLiftVisible( false )
	end

	return blockDelete
end

-- function LiftReplacement:client_onUnequip()
-- 	self.equipped = false
-- 	sm.visualization.setCreationBodies( {} )
-- 	sm.visualization.setCreationVisible( false )
-- 	sm.visualization.setLiftVisible( false )
-- 	self.forced = false
-- end

for k, liftClass in pairs({ Lift, SurvivalLift }) do
	for _k, v in pairs(LiftReplacement) do
		liftClass[_k] = v
	end
end
-- #endregion



-- #region Stone
if not StoneChunk then
	dofile( "$SURVIVAL_DATA/Scripts/game/harvestable/StoneChunk.lua" )
end

mannedTurret_oldStoneChunkCreate = mannedTurret_oldStoneChunkCreate or StoneChunk.server_onCreate
function StoneChunk.server_onCreate( self )
	mannedTurret_oldStoneChunkCreate(self)

	if self.params then
		if self.params.markedForDeath then
			self.markedForDeath = true
			self:sv_onHit( self.health )
		end
	end
end

--no way around replacing outright
function StoneChunk.sv_onHit( self, damage )
	if self.health > 0 then
		self.health = self.health - damage
		if self.health <= 0 then
			local worldPosition = sm.shape.getWorldPosition(self.shape)
			if self.data then
				if self.data.chunkSize then
					if self.data.chunkSize == 1 then
						local harvest = math.random( 3 ) == 1 and obj_harvest_metal2 or obj_harvest_stone
						local shapeOffset = sm.item.getShapeOffset( harvest )
						local rotation = self.shape.worldRotation

						local stone = sm.shape.createPart( harvest, worldPosition - rotation * shapeOffset, rotation )
						stone.interactable:setParams({ markedForDeath = self.markedForDeath })

						sm.effect.playEffect( "Stone - BreakChunk small", worldPosition, nil, self.shape.worldRotation, nil, { size = self.shape:getMass() / AUDIO_MASS_DIVIDE_RATIO } )
					elseif self.data.chunkSize == 2 then
						local shapeOffset = sm.item.getShapeOffset( obj_harvest_stonechunk01 )
						local halfOffset = sm.vec3.new( 0, 0, shapeOffset.z )
						local rotation = self.shape.worldRotation
						local halfTurn = sm.vec3.getRotation( sm.vec3.new( 1, 0, 0 ), sm.vec3.new( -1, 0, 0 ) )

						local stone = sm.shape.createPart( obj_harvest_stonechunk01, worldPosition - rotation * shapeOffset + rotation * halfOffset, rotation )
						stone.interactable:setParams({ markedForDeath = self.markedForDeath })

						local stone = sm.shape.createPart( obj_harvest_stonechunk01, worldPosition - ( rotation * halfTurn ) * shapeOffset - rotation * halfOffset, rotation * halfTurn )
						stone.interactable:setParams({ markedForDeath = self.markedForDeath })

						sm.effect.playEffect( "Stone - BreakChunk small", worldPosition, nil, self.shape.worldRotation, nil, { size = self.shape:getMass() / AUDIO_MASS_DIVIDE_RATIO } )
					elseif self.data.chunkSize == 3 then
						local shapeOffset = sm.item.getShapeOffset( obj_harvest_stonechunk02 ) -- Same dimensions on both chunks
						local halfOffset = sm.vec3.new( shapeOffset.x, 0, 0 )
						local rotation = self.shape.worldRotation
						local halfTurn = sm.vec3.getRotation( sm.vec3.new( 1, 0, 0 ), sm.vec3.new( -1, 0, 0 ) )

						local stone = sm.shape.createPart( obj_harvest_stonechunk02, worldPosition - rotation * shapeOffset + rotation * halfOffset, rotation )
						stone.interactable:setParams({ markedForDeath = self.markedForDeath })

						local stone = sm.shape.createPart( obj_harvest_stonechunk03, worldPosition - ( rotation * halfTurn ) * shapeOffset - rotation * halfOffset, rotation * halfTurn )
						stone.interactable:setParams({ markedForDeath = self.markedForDeath })

						sm.effect.playEffect( "Stone - BreakChunk", worldPosition, nil, self.shape.worldRotation, nil, { size = self.shape:getMass() / AUDIO_MASS_DIVIDE_RATIO } )
					end
				end
			end

			sm.shape.destroyPart( self.shape )
		end
	end
end

function StoneChunk:sv_markDeath()
	self.markedForDeath = true
	self:sv_onHit(self.health)
end
-- #endregion



-- #region TreeTrunk
if not TreeTrunk then
	dofile( "$SURVIVAL_DATA/Scripts/game/harvestable/TreeTrunk.lua" )
end

mannedTurret_oldTreeTrunkCreate = mannedTurret_oldTreeTrunkCreate or TreeTrunk.server_onCreate
function TreeTrunk.server_onCreate( self )
	mannedTurret_oldTreeTrunkCreate(self)

	if self.params then
		if self.params.markedForDeath then
			self.markedForDeath = true
			self:sv_onHit( self.sv.health )
		end
	end
end

function TreeTrunk.sv_onHit( self, damage )
	if self.sv.health > 0 then
		self.sv.health = self.sv.health - damage
		if self.sv.health <= 0 then
			local worldPosition = self.shape.worldPosition
			if self.data then
				if self.data.treeType and not self.data.stump then
					if self.data.treeType == "small" then
						local shapeOffset = sm.item.getShapeOffset( obj_harvest_log_s01 )
						local rotation = self.shape.worldRotation

						local log = sm.shape.createPart( obj_harvest_log_s01, worldPosition - rotation * shapeOffset, rotation )
						log.interactable:setParams({ markedForDeath = self.markedForDeath })

						sm.effect.playEffect( "Tree - BreakTrunk Birch", worldPosition, nil, self.shape.worldRotation )
					elseif self.data.treeType == "medium" then
						local shapeOffset = sm.item.getShapeOffset( obj_harvest_log_m01 )
						local halfOffset = sm.vec3.new( shapeOffset.x, 0, 0 )
						local rotation = self.shape.worldRotation
						local halfTurn = sm.vec3.getRotation( sm.vec3.new( 1, 0, 0 ), sm.vec3.new( -1, 0, 0 ) )

						local log = sm.shape.createPart( obj_harvest_log_m01, worldPosition - rotation * shapeOffset + rotation * halfOffset, rotation )
						log.interactable:setParams({ markedForDeath = self.markedForDeath })

						local log = sm.shape.createPart( obj_harvest_log_m01, worldPosition - ( rotation * halfTurn ) * shapeOffset - rotation * halfOffset, rotation * halfTurn )
						log.interactable:setParams({ markedForDeath = self.markedForDeath })

						sm.effect.playEffect( "Tree - BreakTrunk Spruce", worldPosition, nil, self.shape.worldRotation )
					elseif self.data.treeType == "large" then
						local shapeOffset = sm.item.getShapeOffset( obj_harvest_log_l01 )
						local halfOffset = sm.vec3.new( shapeOffset.x, 0, 0 )
						local rotation = self.shape.worldRotation
						local halfTurn = sm.vec3.getRotation( sm.vec3.new( 1, 0, 0 ), sm.vec3.new( -1, 0, 0 ) )

						local log = sm.shape.createPart( obj_harvest_log_l01, worldPosition - rotation * shapeOffset + rotation * halfOffset, rotation )
						log.interactable:setParams({ markedForDeath = self.markedForDeath })

						local log = sm.shape.createPart( obj_harvest_log_l01, worldPosition - ( rotation * halfTurn ) * shapeOffset - rotation * halfOffset, rotation * halfTurn )
						log.interactable:setParams({ markedForDeath = self.markedForDeath })

						sm.effect.playEffect( "Tree - BreakTrunk Pine", worldPosition, nil, self.shape.worldRotation )
					end
				end
			end

			sm.shape.destroyPart(self.shape)
		end
	end
end

function TreeTrunk:sv_markDeath()
	self.markedForDeath = true
	self:sv_onHit(self.sv.health)
end
-- #endregion



-- #region TreeLog
if not TreeLog then
	dofile( "$SURVIVAL_DATA/Scripts/game/harvestable/TreeLog.lua" )
end

mannedTurret_oldTreeLogCreate = mannedTurret_oldTreeLogCreate or TreeLog.server_onCreate
function TreeLog.server_onCreate( self )
	mannedTurret_oldTreeLogCreate(self)

	if self.params then
		if self.params.markedForDeath then
			self.markedForDeath = true
			self:sv_onHit( self.health )
		end
	end
end

function TreeLog.sv_onHit( self, damage )
	if self.health > 0 then
		self.health = self.health - damage
		if self.health <= 0 then
			local worldPosition = self.shape.worldPosition
			if self.data then
				if self.data.treeType then
					if self.data.treeType == "small" then
						local shapeOffset = sm.item.getShapeOffset( obj_harvest_wood )
						local rotation = sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), self.shape.at )

						local log = sm.shape.createPart( obj_harvest_wood, worldPosition - rotation * shapeOffset, rotation )
						log.interactable:setParams({ markedForDeath = self.markedForDeath })

						sm.effect.playEffect( "Tree - BreakTrunk Birch", worldPosition, nil, self.shape.worldRotation )
					elseif self.data.treeType == "medium" then
						local shapeOffset = sm.item.getShapeOffset( obj_harvest_wood )
						local rotation = sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), self.shape.at )

						local log = sm.shape.createPart( obj_harvest_wood, worldPosition - rotation * shapeOffset, rotation )
						log.interactable:setParams({ markedForDeath = self.markedForDeath })

						sm.effect.playEffect( "Tree - BreakTrunk SpruceHalf", worldPosition, nil, self.shape.worldRotation )
					elseif self.data.treeType == "large" then
						if self.data.size then
							if self.data.size == "half" then
								local shapeOffsetA = sm.item.getShapeOffset( obj_harvest_log_l02a )
								local halfOffsetA = sm.vec3.new( 0, 0, shapeOffsetA.z )
								local shapeOffsetB = sm.item.getShapeOffset( obj_harvest_log_l02b )
								local halfOffsetB = sm.vec3.new( 0, 0, shapeOffsetB.z )
								local rotation = self.shape.worldRotation
								local halfTurn = sm.vec3.getRotation( sm.vec3.new( 1, 0, 0 ), sm.vec3.new( 0, 0, -1 ) )

								local log = sm.shape.createPart( obj_harvest_log_l02a, worldPosition - rotation * shapeOffsetA + rotation * halfOffsetA, rotation )
								log.interactable:setParams({ markedForDeath = self.markedForDeath })

								local log = sm.shape.createPart( obj_harvest_log_l02b, worldPosition - ( rotation * halfTurn ) * shapeOffsetB - rotation * halfOffsetB, rotation * halfTurn )
								log.interactable:setParams({ markedForDeath = self.markedForDeath })

								sm.effect.playEffect( "Tree - BreakTrunk PineHalf", worldPosition, nil, self.shape.worldRotation )
							elseif self.data.size == "quarter" then
								local shapeOffset = sm.item.getShapeOffset( obj_harvest_wood2 )
								local rotation = sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), self.shape.at )

								local log = sm.shape.createPart( obj_harvest_wood2, worldPosition - rotation * shapeOffset, rotation )
								log.interactable:setParams({ markedForDeath = self.markedForDeath })

								sm.effect.playEffect( "Tree - BreakTrunk PineQuarter", worldPosition, nil, self.shape.worldRotation )
							end
						end
					end
				end
			end

			sm.shape.destroyPart(self.shape)
		end
	end
end

function TreeLog:sv_markDeath()
	self.markedForDeath = true
	self:sv_onHit(self.health)
end
-- #endregion



-- #region Seat
if not Seat then
	dofile "$SURVIVAL_DATA/Scripts/game/interactables/Seat.lua"
end

local mountedCannonUUID = "0af5379e-29e8-4eb3-b965-6b3993c8f1df"
local MountedCannonGun = {
	ammoTypes = {
		"24d5e812-3902-4ac3-b214-a0c924a5c40f",
		"667171c3-e8b5-4198-814f-425cbd830b0b",
		-- "4c69fa44-dd0d-42ce-9892-e61d13922bd2",
		"e36b172c-ae2d-4697-af44-8041d9cbde0e",
		"242b84e4-c008-4780-a2dd-abacea821637"
	},
	overrideAmmoTypes = {
		"47b43e6e-280d-497e-9896-a3af721d89d2",
		"24001201-40dd-4950-b99f-17d878a9e07b",
		"8d3b98de-c981-4f05-abfe-d22ee4781d33",
		"254360f7-ba19-431d-ac1a-92c1ee9ba483"
	}
}


mannedTurret_oldSeatUpdate = mannedTurret_oldSeatUpdate or Seat.client_onUpdate
---@param self { gui? : GuiInterface, interactable : Interactable }
function Seat:client_onUpdate(dt)
	mannedTurret_oldSeatUpdate(self, dt)

	if self.gui then
		local interactables = self.interactable:getSeatInteractables()
		for i = 1, 10 do
			local value = interactables[i]
			if value and bit.band(value:getConnectionInputType(), 2) then
				local uuid = tostring(value.shape.uuid)
				if uuid == mountedCannonUUID then
					self.gui:setGridItem( "ButtonGrid", i-1, {
						["itemId"] = sm.GetTurretAmmoData(MountedCannonGun, sm.GetInteractableClientPublicData(value).ammoType),
						["active"] = value.active
					})
				end
			end
		end
	end
end

mannedTurret_oldSeatAction = mannedTurret_oldSeatAction or Seat.client_onAction
function Seat:client_onAction(action, state)
	return self:cl_checkRocketInput(action, state) or mannedTurret_oldSeatAction(self, action, state)
end

connectiontype_cannonrocket = 2^15
function Seat:cl_checkRocketInput(action, state)
	local consume = false
	for k, int in pairs(self.interactable:getChildren(connectiontype_cannonrocket)) do
		if sm.GetInteractableClientPublicData(int).hasRocket then
			self.network:sendToServer("sv_onRocketInput", { cannon = int, action = action, state = state })

			consume = consume or state
		end
	end

	return consume
end

function Seat:sv_onRocketInput(data)
	sm.event.sendToInteractable(data.cannon, "sv_onRocketInput", { action = data.action, state = data.state })
end

function Seat:cl_onRocketFire()
	self.gui:close()
end

function Seat:cl_onRocketExplode()
	self.gui:open()
end



dofile "$SURVIVAL_DATA/Scripts/game/interactables/DriverSeat.lua"

DriverSeat.cl_checkRocketInput = Seat.cl_checkRocketInput

mannedTurret_oldDriverSeatAction = mannedTurret_oldDriverSeatAction or DriverSeat.client_onAction
function DriverSeat:client_onAction(action, state)
	return self:cl_checkRocketInput(action, state) or mannedTurret_oldDriverSeatAction(self, action, state)
end



Saddle = class( Seat )
Saddle.Levels = {
	[tostring(obj_interactive_saddle_01)] = { maxConnections = 3, upgrade = obj_interactive_saddle_02, cost = 1, title = "#{LEVEL} 1" },
	[tostring(obj_interactive_saddle_02)] = { maxConnections = 4, upgrade = obj_interactive_saddle_03, cost = 1, title = "#{LEVEL} 2" },
	[tostring(obj_interactive_saddle_03)] = { maxConnections = 6, upgrade = obj_interactive_saddle_04, cost = 1, title = "#{LEVEL} 3" },
	[tostring(obj_interactive_saddle_04)] = { maxConnections = 8, upgrade = obj_interactive_saddle_05, cost = 1, title = "#{LEVEL} 4" },
	[tostring(obj_interactive_saddle_05)] = { maxConnections = 10, title = "#{LEVEL} 5" },
}

DriverSaddle = class( DriverSeat )
DriverSaddle.Levels = {
	[tostring(obj_interactive_driversaddle_01)] = { maxConnections = 6, allowAdjustingJoints = false, upgrade = obj_interactive_driversaddle_02, cost = 1, title = "#{LEVEL} 1" },
	[tostring(obj_interactive_driversaddle_02)] = { maxConnections = 8, allowAdjustingJoints = false, upgrade = obj_interactive_driversaddle_03, cost = 2, title = "#{LEVEL} 2" },
	[tostring(obj_interactive_driversaddle_03)] = { maxConnections = 12, allowAdjustingJoints = false, upgrade = obj_interactive_driversaddle_04, cost = 3, title = "#{LEVEL} 3" },
	[tostring(obj_interactive_driversaddle_04)] = { maxConnections = 16, allowAdjustingJoints = false, upgrade = obj_interactive_driversaddle_05, cost = 5, title = "#{LEVEL} 4" },
	[tostring(obj_interactive_driversaddle_05)] = { maxConnections = 20, allowAdjustingJoints = true, title = "#{LEVEL} 5" },
}
-- #endregion



-- #region World hook
mannedTurret_originalHookFuncs = mannedTurret_originalHookFuncs or {}
for k, v in pairs(_G) do
	if type(v) ~= "table" then
		goto continue
	end

	if (v.cellMaxX or v.cellMaxY or v.cellMinX or v.cellMinY) then
		function v:sv_e_spawnPart(args)
			sm.shape.createPart(args.uuid, args.pos, args.rot)
		end

		if mannedTurret_originalHookFuncs[k] == nil then
			mannedTurret_originalHookFuncs[k] = {
				server_onProjectile = v.server_onProjectile
			}
		end

		function v:server_onProjectile(position, airTime, velocity, projectileName, shooter, damage, customData, normal, target, uuid)
			local uuidstr = tostring(uuid)
			if uuidstr == "a385b242-ce0c-4e3b-82a7-99da38510709" then --Big Potato
				local hor = 45
				local ver = 20
				local spreadAngle = 90
				local source = type(shooter) == "Player" and shooter or sm.player.getAllPlayers()[1]
				local projectile = sm.uuid.new("4cc37871-c53f-4f47-9e68-d08f84492d6a")
				for i = 0, hor do
					for j = 0, ver do
						local frac = j / ver
						local horFrac = math.sin(frac * 2) --math.sin(frac) --christmas tree pattern
						local dir = sm.vec3.new(math.sin(i) * horFrac, 0.8 - frac * 1.6, math.cos(i) * horFrac)
						sm.projectile.projectileAttack(projectile, 28, position, sm.noise.gunSpread(dir, spreadAngle) * 5, source)
					end
				end
			end

			if uuidstr == "8e94e087-a12c-472f-a3d1-78b3fd696605" or uuidstr == "cec68b0a-fc9d-4c9d-ae3b-c9d231148c4d" then --Explosive, tracer explosive
				return mannedTurret_originalHookFuncs[k].server_onProjectile(self, position, airTime, velocity, "explosivetape", shooter, damage, customData, normal, target, projectile_explosivetape)
			end

			if uuidstr == "aad3baad-861c-4a19-a3f6-b444e70bd27b" then --AP rocket
				-- if count then
				-- 	for i = 1, count do
				-- 		sm.debugDraw.clear("apImpact"..i)
				-- 	end
				-- end

				-- sm.debugDraw.addSphere("apImpactStart", position, 0.25, sm.color.new(1,0,0))

				local dir = velocity:normalize()
				local distance = 10

				-- sm.debugDraw.addArrow("apLength", position, position + dir * distance)

				-- count = 0
				while distance > 0 do
					local hit, result = sm.physics.raycast(position, position + dir * distance)
					if hit then
						-- count = count + 1

						distance = distance - distance * result.fraction
						position = result.pointWorld + dir * 0.01

						-- if count == 1 then
						-- 	sm.debugDraw.addSphere("apImpact"..count, position, 0.1, sm.color.new(0,1,1))
						-- else
						-- 	sm.debugDraw.addSphere("apImpact"..count, position, 0.1, sm.color.new(0,1,0))
						-- end

						sm.physics.explode(position, 4, 2, 3, 8)--, "PropaneTank - ExplosionSmall")

						local type = result.type
						if type == "character" then
							sm.event.sendToCharacter(result:getCharacter(), "sv_e_takeDamage", { damage = 9999 })
						elseif type == "body" then
							local shape = result:getShape()
							if shape.isBlock then
								shape:destroyBlock(shape:getClosestBlockLocalPosition(position))
							else
								local int = shape.interactable
								local classname = (sm.item.getFeatureData(shape.uuid) or {}).classname
								if classname == "Package" then
									sm.event.sendToInteractable( int, "sv_e_open" )
								elseif not int or int.type ~= "scripted" or not sm.event.sendToInteractable(int, "sv_e_onHit", {
									damage = 9999,
									position = position,
									normal = result.normalWorld
								}) then
									shape:destroyShape()
								end
							end
						elseif type == "harvestable" then
							if not sm.event.sendToHarvestable(target, "sv_e_onHit", { damage = 9999, position = pos }) then
								sm.physics.explode( pos, 3, 1, 1, 1 )
							end
						else
							break
						end
					else
						break
					end
				end

				sm.physics.explode(position, 7, 2, 3, 8)--, "PropaneTank - ExplosionBig")
			end

			return mannedTurret_originalHookFuncs[k].server_onProjectile(self, position, airTime, velocity, projectileName, shooter, damage, customData, normal, target, uuid)
		end
	elseif v.server_onPlayerJoined then
		if mannedTurret_originalHookFuncs[k] == nil then
			mannedTurret_originalHookFuncs[k] = {
				server_onPlayerJoined = v.server_onPlayerJoined
			}
		end

		function v:server_onPlayerJoined(player, newPlayer)
			mannedTurret_originalHookFuncs[k].server_onPlayerJoined(self, player, newPlayer)

			sm.log.warning("PLAYER JOIN", player, player:getName())
		end

		function v:sv_addTurretChunkLoader(int)
			sm.log.warning("LOADING CHUNK FOR TURRET")
			local pos_64 = int.shape.worldPosition/64
			local x, y = math.floor(pos_64.x), math.floor(pos_64.y)
			local cellKey = CellKey(x, y)
			if sm.MANNEDTURRET_turretChunkLoaders[cellKey] == nil then
				sm.MANNEDTURRET_turretChunkLoaders[cellKey] = {
					bases = {},
					handle = nil
				}

				int.body:getWorld():loadCell(x, y, nil, "sv_OnTurretChunkLoaded")
			end

			if isAnyOf(int, sm.MANNEDTURRET_turretChunkLoaders[cellKey].bases) then
				sm.log.error(int, "IS ALREADY SAVED, NOT SAVING AGAIN")
			else
				table.insert(sm.MANNEDTURRET_turretChunkLoaders[cellKey].bases, int)
				-- sm.storage.save(sm.MANNEDTURRET_turretChunkLoaders_saveKey, sm.MANNEDTURRET_turretChunkLoaders)
				sm.event.sendToTool(sm.MANNEDTURRET_turretAssistor, "sv_saveChunkLoaders")
			end

			sm.log.warning(sm.MANNEDTURRET_turretChunkLoaders[cellKey])
		end

		function v:sv_OnTurretChunkLoaded(world, x, y, player, params, handle)
			sm.MANNEDTURRET_turretChunkLoaders[CellKey(x, y)].handle = handle
			-- sm.storage.save(sm.MANNEDTURRET_turretChunkLoaders_saveKey, sm.MANNEDTURRET_turretChunkLoaders)
			sm.event.sendToTool(sm.MANNEDTURRET_turretAssistor, "sv_saveChunkLoaders")
			sm.log.warning("CHUNK LOADED FOR TURRET, HANDLE:", handle)
		end

		function v:sv_removeTurretChunkLoader(data)
			sm.log.warning("REMOVING TURRET FROM LOADED CHUNK")
			local pos_64 = data.position / 64
			local x, y = math.floor(pos_64.x), math.floor(pos_64.y)
			local cellKey = CellKey(x, y)
			if not sm.MANNEDTURRET_turretChunkLoaders[cellKey] then
				sm.log.error("NO CHUNK DATA FOR BASE REQUESTING REMOVAL", data, x, y)
				return
			end

			if data.int then
				table.sort(sm.MANNEDTURRET_turretChunkLoaders[cellKey].bases, function(a, b)
					return b == data.int
				end)

				table.remove(sm.MANNEDTURRET_turretChunkLoaders[cellKey].bases)
			else
				local new = {}
				for baseIdx, base in pairs(sm.MANNEDTURRET_turretChunkLoaders[cellKey].bases) do
					if sm.exists(base) then
						table.insert(new, base)
					end
				end

				sm.MANNEDTURRET_turretChunkLoaders[cellKey].bases = new
			end

			if #sm.MANNEDTURRET_turretChunkLoaders[cellKey].bases == 0 then
				self:sv_releaseTurretChunkLoaderHandle(cellKey)
			end

			-- sm.storage.save(sm.MANNEDTURRET_turretChunkLoaders_saveKey, sm.MANNEDTURRET_turretChunkLoaders)
			sm.event.sendToTool(sm.MANNEDTURRET_turretAssistor, "sv_saveChunkLoaders")

			sm.log.warning(sm.MANNEDTURRET_turretChunkLoaders[cellKey])
		end

		function v:sv_releaseTurretChunkLoaderHandle(cellKey)
			-- sm.MANNEDTURRET_turretChunkLoaders[cellKey].handle:release()
			sm.MANNEDTURRET_turretChunkLoaders[cellKey] = nil
		end
	elseif v.server_onUnitUpdate then
		function v:sv_e_takeDamage(args)
			if not sm.exists(self.unit) then return end

			local char = self.unit.character
			if isAnyOf(char:getCharacterType(), g_tapebots) then
				self:sv_takeDamage( args.damage or 0, args.impact or sm.vec3.zero(), args.headHit or false )
			else
				self:sv_takeDamage( args.damage or 0, args.impact or sm.vec3.zero(), args.hitPos or self.unit.character.worldPosition )
			end
		end

		print("[MANNED TURRET] HOOKED UNIT CLASS", k)
	elseif v.client_onCancel or v.server_onInventoryChanges then
		function v:sv_e_takeDamage(args)
			local char = self.player.character
			if sm.exists(char) then
				self:sv_takeDamage( args.damage or 0, args.impact or sm.vec3.zero(), args.hitPos or self.player.character.worldPosition )
			end
		end

		print("[MANNED TURRET] HOOKED PLAYER CLASS", k)
	elseif v.sv_onHit then
		function v:sv_e_onHit(args)
			self:sv_onHit(args.damage, args.position)
		end

		print("[MANNED TURRET] HOOKED HARVESTABLE CLASS", k)
	end

	::continue::
end
-- #endregion