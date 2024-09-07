dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

dofile "$CONTENT_DATA/Scripts/util.lua"

---@class ToolEffect
---@field name EffectName
---@field params? table

---@class ToolRenderable
---@field fp table
---@field tp table
---@field effect? ToolEffect|function
---@field audio? AudioName|string
---@field colour? Color

---@class RepairTool : ToolClass
---@field tpAnimations table
---@field fpAnimations table
---@field equipped boolean
---@field wantEquipped boolean
---@field blendTime number
RepairTool = class()

---@type ToolRenderable[]
local renderables = {
    hammer = {
        fp = { "$GAME_DATA/Character/Char_Tools/Char_smallhammer/char_smallhammer_fp.rend" },
        tp = {
			"$GAME_DATA/Character/Char_Tools/Char_smallhammer/char_smallhammer_tp.rend",
			"$CONTENT_DATA/Character/char_male_repairtool_tp.rend"
		},
        effect = { name = "Sledgehammer - Hit", params = { Material = 9 } }
    },
    hammer2 = {
        fp = { "$GAME_DATA/Character/Char_Tools/Char_smallhammer/char_smallhammer_fp.rend" },
        tp = {
			"$GAME_DATA/Character/Char_Tools/Char_smallhammer/char_smallhammer_tp.rend",
			"$CONTENT_DATA/Character/char_male_repairtool_tp.rend"
		},
        effect = { name = "Sledgehammer - Hit", params = { Material = 9 } }
    },
    drill = {
        fp = { "$GAME_DATA/Character/Char_Tools/Char_impactdriver/char_impactdriver_fp.rend" },
        tp = {
			"$GAME_DATA/Character/Char_Tools/Char_impactdriver/char_impactdriver_tp.rend",
			"$CONTENT_DATA/Character/char_male_repairtool_tp.rend"
		},
        audio = "event:/tools/drill"
    },
	weldtool_pickup = {
		fp = { "$CONTENT_DATA/Character/WeldTool/char_weldtool_fp.rend" },
		tp = {
			"$CONTENT_DATA/Character/WeldTool/char_weldtool_tp.rend",
			"$CONTENT_DATA/Character/char_male_repairtool_tp.rend"
		},
		audio = "event:/tools/weldtool/wt_equip"
	},
	weldtool_into = {
		fp = { "$CONTENT_DATA/Character/WeldTool/char_weldtool_fp.rend" },
		tp = {
			"$CONTENT_DATA/Character/WeldTool/char_weldtool_tp.rend",
			"$CONTENT_DATA/Character/char_male_repairtool_tp.rend"
		},
	},
	weldtool_use = {
		fp = { "$CONTENT_DATA/Character/WeldTool/char_weldtool_fp.rend" },
		tp = {
			"$CONTENT_DATA/Character/WeldTool/char_weldtool_tp.rend",
			"$CONTENT_DATA/Character/char_male_repairtool_tp.rend"
		},
		audio = "event:/tools/weldtool/wt_weld",
		effect = { name = "RepairTool - Weld" }
	},
	weldtool_exit = {
		fp = { "$CONTENT_DATA/Character/WeldTool/char_weldtool_fp.rend" },
		tp = {
			"$CONTENT_DATA/Character/WeldTool/char_weldtool_tp.rend",
			"$CONTENT_DATA/Character/char_male_repairtool_tp.rend"
		},
	},
	weldtool_putdown = {
		fp = { "$CONTENT_DATA/Character/WeldTool/char_weldtool_fp.rend" },
		tp = {
			"$CONTENT_DATA/Character/WeldTool/char_weldtool_tp.rend",
			"$CONTENT_DATA/Character/char_male_repairtool_tp.rend"
		},
		audio = "event:/tools/weldtool/wt_putdown"
	},
}

local function _createTpAnimations( tool, animationMap )
	local data = {}
	data.tool = tool
	data.animations = {}

	for name, pair in pairs(animationMap) do
		local info = tool:getAnimationInfo(pair[1])
		local animation = {
			info = info,
			time = 0.0,
			weight = 0.0,
			playRate = pair[2] and pair[2].playRate or 1.0,
			looping =  pair[2] and pair[2].looping or false,
			nextAnimation = pair[2] and pair[2].nextAnimation or nil,
			blendNext = pair[2] and pair[2].blendNext or 0.0,
            eventTime = pair[2] and pair[2].eventTime or nil,
            eventPlayed = false,
			baseTime = pair[2] and pair[2].baseTime or 0.0,
			endTime = pair[2] and pair[2].endTime or (info and info.duration or 1),
		}

		if pair[2] and pair[2].dirs then
			animation.dirs = {
				up = tool:getAnimationInfo(pair[2].dirs.up),
				fwd = tool:getAnimationInfo(pair[2].dirs.fwd),
				down = tool:getAnimationInfo(pair[2].dirs.down)
			}
		end

		if pair[2] and pair[2].crouch then
			animation.crouch = tool:getAnimationInfo(pair[2].crouch)
		end

		if animation.info == nil then
			print("Error: failed to get third person animation info for: ", pair[1])
			animation.info = {name = name, duration = 1.0, looping = false }
		end

		data.animations[name] = animation;
	end

	data.blendSpeed = 0.0
	data.currentAnimation = ""
	return data
end

local blockUnforce = {
	weldtool_pickup	= true,
	weldtool_into	= true,
	weldtool_use 	= true,
	weldtool_exit 	= true,
}

local function canUnforce(self, anim)
	return self.markedUnforce and blockUnforce[anim] == nil
end

local function _updateTpAnimations( self, data, dt )
    local crouchWeight = data.tool:isCrouching() and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight
	local totalWeight = 0.0

	local frameCurrent = data.currentAnimation
	local rend = renderables[frameCurrent]

    local blendStep = 1.0
    if data.blendSpeed ~= 0.0 then blendStep = (1.0/data.blendSpeed) * dt end

	for name, animation in pairs( data.animations ) do
		animation.time = animation.baseTime + animation.time + animation.playRate*dt

		if name == frameCurrent then
            if not data.tool:isLocal() and animation.time >= animation.eventTime and not animation.eventPlayed then
				local effectData = rend.effect
				if effectData then
                    local hit, result = self:getRaycast()
					if hit then
						if type(effectData) == "table" then
							sm.effect.playEffect(effectData.name, result.pointWorld, vec3_zero, sm.vec3.getRotation(vec3_up, result.normalWorld), vec3_one, effectData.params)
						else
							effectData(self)
						end
					end
                end

                if rend.audio then
                    sm.audio.play(rend.audio, data.tool:getPosition())
                end

                animation.eventPlayed = true
            end

			animation.weight = math.min( animation.weight + blendStep, 1.0 )

            if animation.time >= animation.endTime then
                if animation.looping == true then
                    animation.time = 0
                else
                    if animation.nextAnimation and not canUnforce(self, frameCurrent) then
						local nextRend = renderables[animation.nextAnimation]
						data.tool:setTpRenderables(nextRend.tp)
						if nextRend.colour then
							data.tool:setTpColor(nextRend.colour)
						end
                        setTpAnimation( data, animation.nextAnimation, animation.blendNext )
                    else
                        animation.weight = 0
                    end
                end

                animation.eventPlayed = false
            end
		else
			animation.weight = math.max( animation.weight - blendStep, 0.0 )
		end

		totalWeight = totalWeight + animation.weight
	end

	totalWeight = totalWeight == 0 and 1.0 or totalWeight
	for name, animation in pairs( data.animations ) do
		local weight = animation.weight / totalWeight
		if name == "idle" then
			data.tool:updateMovementAnimation( animation.time, weight )
		elseif animation.crouch then
			data.tool:updateAnimation( animation.info.name, animation.time, weight * normalWeight )
			data.tool:updateAnimation( animation.crouch.name, animation.time, weight * crouchWeight )
		else
			data.tool:updateAnimation( animation.info.name, animation.time, weight )
		end
	end

	local playerDir = self.tool:getSmoothDirection()
	local angle = math.asin( playerDir:dot( vec3_up ) ) / ( math.pi / 2 )
	local finalAngle = ( 0.5 + angle * 0.5 )
	self.tool:updateAnimation( "spudgun_spine_bend", finalAngle, 1 )
end

local function _createFpAnimations( tool, animationMap )
	local data = {}
	data.isLocal = tool:isLocal()
	if not data.isLocal then
		return data
	end
	data.tool = tool
	data.animations = {}

	for name, pair in pairs(animationMap) do
		local animation = {
			info = tool:getFpAnimationInfo(pair[1]),
			time = 0.0,
			weight = 0.0,
			playRate = pair[2] and pair[2].playRate or 1.0,
			looping =  pair[2] and pair[2].looping or false,
			nextAnimation = pair[2] and pair[2].nextAnimation or nil,
			blendNext = pair[2] and pair[2].blendNext or 0.0,
            eventTime = pair[2] and pair[2].eventTime or nil,
            eventPlayed = false,
			blockHeal = pair[2] and pair[2].blockHeal or false,
			baseTime = pair[2] and pair[2].baseTime or 0.0,
		}

		if animation.info == nil then
			print("Error: failed to get firspperson animation info for: ", pair[1])
			animation.info = { name = name, duration = 1, looping = false }
		end

		data.animations[name] = animation
	end

	data.blendSpeed = 0.0
	data.currentAnimation = ""
	return data
end

local function _updateFpAnimations( self, data, equipped, dt )
	if data ~= nil and data.isLocal and (equipped or data.currentAnimation == "unequip") then
		local totalWeight = 0.0
		local frameCurrent = data.currentAnimation
		local blendStep = 1.0
		if data.blendSpeed ~= 0.0 then blendStep = (1.0/data.blendSpeed) * dt end

		local rend = renderables[frameCurrent]
		for name, animation in pairs(data.animations) do
			animation.time = animation.baseTime + animation.time+animation.playRate*dt

			if name == frameCurrent then
                if animation.time >= animation.eventTime and not animation.eventPlayed then
					local effectData = rend.effect
					if effectData then
						if type(effectData) == "table" then
							local hit, result = sm.localPlayer.getRaycast(7.5)
							if hit then
								sm.effect.playEffect(effectData.name, result.pointWorld, vec3_zero, sm.vec3.getRotation(vec3_up, result.normalWorld), vec3_one, effectData.params)
							end
						else
							effectData(self)
						end
					end

                    if rend.audio then
                        sm.audio.play(rend.audio)
                    end

                    animation.eventPlayed = true
                end

				animation.weight = math.min(animation.weight+blendStep, 1.0)
				if animation.time >= animation.info.duration then
					local endRepair = canUnforce(self, frameCurrent)
                    if animation.looping then
                        animation.time = 0
                    else
                        if animation.nextAnimation then
                            if not animation.blockHeal and sm.exists(g_turretBase) then
                                self.network:sendToServer("sv_healTurret", g_turretBase.shape)
                            end

							if not endRepair then
								local nextRend = renderables[animation.nextAnimation]
								self.tool:setFpRenderables(nextRend.fp)
								if nextRend.colour then
									self.tool:setFpColor(nextRend.colour)
								end
	                            setFpAnimation(data, animation.nextAnimation, animation.blendNext)
							end
                        else
                            animation.weight = 0.0
                        end
                    end

					if endRepair and g_repairingTurret then
						if not self.hasSentEnd then
							self.hasSentEnd = true
							self:cl_onRepairEnd()
						end
					elseif not self.hasSentEnd then
						animation.eventPlayed = false
					end
				end
			else
				animation.weight = math.max(animation.weight-blendStep, 0.0)
			end

			totalWeight = totalWeight + animation.weight
		end
		-- Balance weight
		if totalWeight == 0.0 then totalWeight = 1.0 end
		for name, animation in pairs(data.animations) do
			data.tool:updateFpAnimation( animation.info.name, animation.time, animation.weight / totalWeight, animation.looping )
		end
	end
end

function RepairTool:client_onCreate()
	self.isLocal = self.tool:isLocal()
	if self.isLocal then
		g_repairTool = self.tool
	end
end

function RepairTool:cl_loadAnimations()
    self.tpAnimations = _createTpAnimations(
        self.tool,
        {
            hammer  		 = { "smallhammer_use",   	{ crouch = "smallhammer_use_crouch",    	nextAnimation = "hammer2",  			eventTime = 0.1	  } },
            hammer2 		 = { "crowbar_use",       	{ crouch = "crowbar_use_crouch",        	nextAnimation = "drill",    			eventTime = 0.1   } },
            drill   		 = { "impactdriver_use",  	{ crouch = "impactdriver_use_crouch",   	nextAnimation = "weldtool_pickup",   	eventTime = 0     } },
			weldtool_pickup	 = { "weldtool_pickup",		{ nextAnimation = "weldtool_into",     		eventTime = 0,							playRate = 2	  } },
			weldtool_into 	 = { "weldtool_use_into", 	{ nextAnimation = "weldtool_use",     		eventTime = 0,							blendNext = 0.1,   		endTime = 0.15  } },
			weldtool_use 	 = { "weldtool_use_idle", 	{ nextAnimation = "weldtool_exit",    		eventTime = 0.1,						blendNext = 0.1,		baseTime = 0.7 	} },
			weldtool_exit 	 = { "weldtool_use_exit", 	{ nextAnimation = "weldtool_putdown",		eventTime = 0,							blendNext = 0.1   } },
			weldtool_putdown = { "weldtool_putdown",	{ nextAnimation = "hammer",					eventTime = 0,							playRate = 2,	  } },
        }
    )

    if self.isLocal then
        self.fpAnimations = _createFpAnimations(
            self.tool,
            {
                hammer  		 = { "smallhammer_use",   	{ nextAnimation = "hammer2",    		 	eventTime = 0.1,	blockHeal = false } },
                hammer2 		 = { "smallhammer_use2",  	{ nextAnimation = "drill",      		 	eventTime = 0.1,	blockHeal = false } },
                drill   		 = { "impactdriver_use",  	{ nextAnimation = "weldtool_pickup",	 	eventTime = 0,		blockHeal = false } },
				weldtool_pickup	 = { "weldtool_pickup",		{ nextAnimation = "weldtool_into",     	 	eventTime = 0,		blockHeal = true, 		playRate  = 2  	 } },
				weldtool_into 	 = { "weldtool_use_into", 	{ nextAnimation = "weldtool_use",     	 	eventTime = 0,		blockHeal = true, 		blendNext = 0.2  } },
				weldtool_use 	 = { "weldtool_use_idle", 	{ nextAnimation = "weldtool_exit",    	 	eventTime = 0.1,	blockHeal = false, 		blendNext = 0.1,		baseTime = 0.2 } },
				weldtool_exit 	 = { "weldtool_use_exit", 	{ nextAnimation = "weldtool_putdown",	 	eventTime = 0, 		blockHeal = true, 		blendNext = 0.2  } },
				weldtool_putdown = { "weldtool_putdown",	{ nextAnimation = "hammer",  				eventTime = 0,		blockHeal = true, 		playRate  = 2  	 } },
            }
        )
    end
end

function RepairTool:client_onUpdate( dt )
	if not sm.exists(self.tool) then return end

	if self.isLocal then
		_updateFpAnimations( self, self.fpAnimations, self.equipped, dt )
	end

	if not self.equipped then
		if self.wantEquipped then
			self.wantEquipped = false
			self.equipped = true
		end
		return
	end

	_updateTpAnimations( self, self.tpAnimations, dt )
end

local startAnim = "hammer"
function RepairTool:client_onEquip()
	self.wantEquipped = true
	self.markedUnforce = false

    local rend = renderables[startAnim]
    self.tool:setTpRenderables(rend.tp)
    if self.isLocal then
        self.tool:setFpRenderables(rend.fp)
    end

	self:cl_loadAnimations()

	setTpAnimation( self.tpAnimations, startAnim, 0 )
	if self.isLocal then
		self.hasSentEnd = false
		setFpAnimation( self.fpAnimations, startAnim, 0 )
	end
end

function RepairTool:client_onUnequip()
	self.wantEquipped = false
	self.equipped = false
end

function RepairTool:client_onEquippedUpdate()
	return true, true
end

function RepairTool:cl_markUnforce()
	self.markedUnforce = true
end

function RepairTool:cl_onRepairEnd()
	sm.tool.forceTool(nil)
	g_repairingTurret = false
    g_turretBase = nil
end


function RepairTool:sv_healTurret(turret)
    if not turret or not sm.exists(turret) then return end

	sm.effect.playEffect("Turret - RepairEvent", turret.worldPosition + turret.at * 0.1)
	local int = turret.interactable
    sm.event.sendToInteractable(int, "sv_takeDamage", -math.ceil(int.publicData.maxHealth/12))
end



function RepairTool:getRaycast()
    local pos = self.tool:getPosition() + (self.tool:isCrouching() and camOffset_c or camOffset)
    local hit, result = sm.physics.raycast(pos, pos + self.tool:getDirection() * 7.5)
    return hit, result
end