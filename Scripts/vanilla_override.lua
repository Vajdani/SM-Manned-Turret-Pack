---@diagnostic disable: undefined-global

-- #region Player
dofile( "$GAME_DATA/Scripts/game/BasePlayer.lua" )
if not SurvivalPlayer then
	dofile( "$SURVIVAL_DATA/Scripts/game/SurvivalPlayer.lua" )
end

oldClientCreate = oldClientCreate or SurvivalPlayer.client_onCreate
local function newClientCreate( self )
	oldClientCreate(self)

	if g_survivalHud then
		sm.SURVIVALHUD = g_survivalHud
	end

	if self.cl_localPlayerUpdate then --Not a reliable check
		sm.BASEPLAYERENABLED = true
	end
end
SurvivalPlayer.client_onCreate = newClientCreate

local oldClass = class
function newClass(_class)
    if _class then
        for k, v in pairs(BasePlayer) do
            if _class[k] ~= v then
                return oldClass(_class)
            end
        end

        return SurvivalPlayer
    end

    return oldClass()
end
class = newClass
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

function LiftReplacement:liftTurrets(state, onLift)
	if onLift then
		for k, v in pairs(self.turrets or {}) do
			sm.event.sendToInteractable(v, "cl_n_putOnLift")
		end
	else
		for k, v in pairs(self.turrets or {}) do
			sm.event.sendToInteractable(v, "cl_onLifted", state)
		end
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
		self:liftTurrets(false)
		self.turrets = {}

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
			local turrets = {}
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

				for _k, int in pairs(body:getInteractables()) do
					if (sm.MANNEDTURRET_turretBases_clientPublicData[int.id] or {}).isTurret == true then
						table.insert(turrets, int)
					end
				end
			end

			if isLiftable and isSelectable then
				self.turrets = turrets
				for k, v in pairs(turrets) do
					sm.event.sendToInteractable(v, "cl_liftHover")
				end
			end
		end
	end

	--Hover
	if isSelectable and #self.selectedBodies == 0 then
		self.hoverBodies = targetBody and targetBody:getCreationBodies() or {}
	else
		self.hoverBodies = {}

		if #self.selectedBodies == 0 then
			self.turrets = {}
		end
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
			self:liftTurrets(true)
			self.selectedBodies = self.hoverBodies
			self.hoverBodies = {}
		elseif isPlaceable then
			self:liftTurrets(false, true)
			self.turrets = {}

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

function LiftReplacement:client_onUnequip()
	if self.turrets then
		self:liftTurrets(false)
	end
	self.turrets = {}

	self.equipped = false
	sm.visualization.setCreationBodies( {} )
	sm.visualization.setCreationVisible( false )
	sm.visualization.setLiftVisible( false )
	self.forced = false
end

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

oldStoneChunkCreate = oldStoneChunkCreate or StoneChunk.server_onCreate
function newStoneChunkCreate( self )
	oldStoneChunkCreate(self)

	if self.params then
		if self.params.markedForDeath then
			self.markedForDeath = true
			self:sv_onHit( self.health )
		end
	end
end
StoneChunk.server_onCreate = newStoneChunkCreate

--no way around replacing outight
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

oldTreeTrunkCreate = oldTreeTrunkCreate or TreeTrunk.server_onCreate
function newTreeTrunkCreate( self )
	oldTreeTrunkCreate(self)

	if self.params then
		if self.params.markedForDeath then
			self.markedForDeath = true
			self:sv_onHit( self.sv.health )
		end
	end
end
TreeTrunk.server_onCreate = newTreeTrunkCreate

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

oldTreeLogCreate = oldTreeLogCreate or TreeLog.server_onCreate
function newTreeLogCreate( self )
	oldTreeLogCreate(self)

	if self.params then
		if self.params.markedForDeath then
			self.markedForDeath = true
			self:sv_onHit( self.health )
		end
	end
end
TreeLog.server_onCreate = newTreeLogCreate

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

oldSeatAction = oldSeatAction or Seat.client_onAction
function Seat:client_onAction(action, state)
	return self:cl_checkRocketInput(action, state) or oldSeatAction(self, action, state)
end

function Seat:cl_checkRocketInput(action, state)
	local cannon = self.interactable:getChildren(2^14)[1]
	if cannon and sm.GetInteractableClientPublicData(cannon --[[@as Interactable]]).hasRocket then
		self.network:sendToServer("sv_onRocketInput", { cannon = cannon, action = action, state = state })

		if state then
			return true
		end
	end

	return false
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



if not DriverSeat then
	dofile "$SURVIVAL_DATA/Scripts/game/interactables/DriverSeat.lua"
end

oldDriverSeatAction = oldDriverSeatAction or DriverSeat.client_onAction
function DriverSeat:client_onAction(action, state)
	return self:cl_checkRocketInput(action, state) or oldDriverSeatAction(self, action, state)
end

local mountedCannonUUID = "0af5379e-29e8-4eb3-b965-6b3993c8f1df"
local MountedCannonGun = {
	ammoTypes = {
		"24d5e812-3902-4ac3-b214-a0c924a5c40f",
		"4c69fa44-dd0d-42ce-9892-e61d13922bd2",
		"e36b172c-ae2d-4697-af44-8041d9cbde0e",
		"242b84e4-c008-4780-a2dd-abacea821637"
	},
	overrideAmmoTypes = {
		"47b43e6e-280d-497e-9896-a3af721d89d2",
		"24001201-40dd-4950-b99f-17d878a9e07b",
		"8d3b98de-c981-4f05-abfe-d22ee4781d33",
	}
}


oldDriverSeatUpdate = oldDriverSeatUpdate or DriverSeat.client_onUpdate
---@param self ShapeClass
function DriverSeat:client_onUpdate(dt)
	oldDriverSeatUpdate(self, dt)

	if self.gui then
		local interactables = self.interactable:getSeatInteractables()
		for i=1, 10 do
			local value = interactables[i]
			if value and bit.band(value:getConnectionInputType(), 2) then
				local uuid = tostring(value.shape.uuid)
				if uuid == mountedCannonUUID then
					self.gui:setGridItem( "ButtonGrid", i-1, {
						["itemId"] = sm.GetTurretAmmoData(MountedCannonGun, sm.GetInteractableClientPublicData(value).ammoType),
						["active"] = value.active
					})
				else
					self.gui:setGridItem( "ButtonGrid", i-1, {
						["itemId"] = uuid,
						["active"] = value.active
					})
				end
			else
				self.gui:setGridItem( "ButtonGrid", i-1, nil)
			end
		end
	end
end
-- #endregion



-- #region World hook
for k, v in pairs(_G) do
	if type(v) == "table" and (v.cellMaxX or v.cellMaxY or v.cellMinX or v.cellMinY) then
		function v:sv_e_spawnPart(args)
			sm.shape.createPart(args.uuid, args.pos, args.rot)
		end
	end
end
-- #endregion