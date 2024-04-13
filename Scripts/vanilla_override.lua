dofile( "$GAME_DATA/Scripts/game/BasePlayer.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/SurvivalPlayer.lua" )

oldClientCreate = oldClientCreate or SurvivalPlayer.client_onCreate
function newClientCreate( self )
	oldClientCreate(self)

	if g_survivalHud then
		sm.SURVIVALHUD = g_survivalHud
	end
end
SurvivalPlayer.client_onCreate = newClientCreate

--[[function SurvivalPlayer.sv_takeDamage( self, damage, source )
	if damage > 0 then
		damage = damage * GetDifficultySettings().playerTakeDamageMultiplier
		local character = self.player:getCharacter()
		local lockingInteractable = character:getLockingInteractable()
		if lockingInteractable and lockingInteractable:hasSeat() then
			lockingInteractable:setSeatCharacter( character )
		end

		if not g_godMode and self.sv.damageCooldown:done() then
			if self.sv.saved.isConscious then
				self.sv.saved.stats.hp = math.max( self.sv.saved.stats.hp - damage, 0 )

				print( "'SurvivalPlayer' took:", damage, "damage.", self.sv.saved.stats.hp, "/", self.sv.saved.stats.maxhp, "HP" )

				if source then
					self.network:sendToClients( "cl_n_onEvent", { event = source, pos = character:getWorldPosition(), damage = damage * 0.01 } )
				else
					self.player:sendCharacterEvent( "hit" )
				end

				if self.sv.saved.stats.hp <= 0 then
					print( "'SurvivalPlayer' knocked out!" )
					self.sv.respawnInteractionAttempted = false
					self.sv.saved.isConscious = false
					character:setTumbling( true )
					character:setDowned( true )

                    local data = self.player.publicData or {}
                    local seat = data.turretSeat
                    if seat then
                        sm.event.sendToHarvestable(seat, "sv_OnPlayerDeath", self.player)
                    end
				end

				self.storage:save( self.sv.saved )
				self.network:setClientData( self.sv.saved )
			end
		else
			print( "'SurvivalPlayer' resisted", damage, "damage" )
		end
	end
end]]

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
		for k, v in pairs(self.turrets) do
			sm.event.sendToInteractable(v, "cl_n_putOnLift")
		end
	else
		for k, v in pairs(self.turrets) do
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
					if (sm.MANNEDTURRET_turretBases_clientPublicData[int.id] or {}).isTurretBase == true then
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
		self.hoverBodies = targetBody:getCreationBodies()
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