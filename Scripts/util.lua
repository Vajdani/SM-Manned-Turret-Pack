---@class AmmoType
---@field name string
---@field damage? number
---@field velocity? number
---@field recoilStrength? number
---@field fireCooldown number
---@field spread? number
---@field effect string|EffectName
---@field ignoreAmmoConsumption? boolean
---@field overheatPerShot? number
---@field chargeTime? number
---@field ammo Uuid
---@field uuid Uuid

dofile "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua"

vec3             = sm.vec3.new
vec3_right       = vec3(1,0,0)
vec3_forward     = vec3(0,1,0)
vec3_up          = vec3(0,0,1)
vec3_zero        = sm.vec3.zero()
vec3_one         = sm.vec3.one()
camOffset        = vec3(0,0,0.575)
camOffset_c      = vec3(0,0,0.3)
vec3_getRotation = sm.vec3.getRotation

rad = math.rad
angleAxis = sm.quat.angleAxis

quat_right_90deg = angleAxis(rad(90), vec3_right)
turret_projectile_rotation_adjustment = quat_right_90deg * angleAxis(rad(180), vec3_forward)

ShootState = {
    null    = 0,
    hold    = 1,
    toggle  = 2
}

HotbarIcon = {
    shoot        = "68a120d9-ba02-413a-a7c7-723d71172f47",
    shoot_toggle = "d6cbdd2c-f6a3-4e2c-a818-2c6112c1b5e7",
    light        = "9a42c98b-a8a1-4bc3-a45e-d0964325ca6d",
    cancel       = "509d50c0-357c-4485-8f24-2f448c5e8e91",
    zoomIn       = "a983d039-0b6b-43b4-8fef-682eab698a3f",
    zoomOut      = "74306663-d10b-4738-aa31-c2459b758765",
    pLauncher    = "242b84e4-c008-4780-a2dd-abacea821637",
}

connectiontype_turretnormal    = 2^13
connectiontype_turretexplosive = 2^14
connectiontype_cannonrocket    = 2^15
connectiontype_cannonratshot   = 2^16
connectiontype_railgunspike    = 2^17

local repairTick = 0
local checkedTick = 0
function getRepairText()
    local tick = sm.game.getCurrentTick()
    if tick%20 == 0 and tick ~= checkedTick then
        repairTick = repairTick + 1
        checkedTick = tick
    end

    return ("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>Repairing%s</p>"):format(string.rep(".", repairTick%4)..string.rep(" ", 3 - repairTick%4))
end

function getHealthDisplay(health)
    local green = math.ceil(health/100)
    return ("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>Health: [%s%s#444444]</p>"):format(string.rep("#00f000|", green), string.rep("#ff0000|", 10 - green))
end

function SetPlayerCamOverride(data)
    if sm.BASEPLAYERENABLED then
        sm.localPlayer.getPlayer().clientPublicData.interactableCameraData = data
        return
    end

    if not data then
        sm.camera.setCameraState( 0 )
        return
    end

    if data.cameraState then
        sm.camera.setCameraState( data.cameraState )
    end
    if data.cameraPosition then
        sm.camera.setPosition( data.cameraPosition )
    end
    if data.cameraRotation then
        sm.camera.setRotation( data.cameraRotation )
    end
    if data.cameraDirection then
        sm.camera.setDirection( data.cameraDirection )
    end
    if data.cameraFov then
        sm.camera.setFov( data.cameraFov )
    end
end

---@param int Interactable
---@param data any
function sm.SetInteractableClientPublicData(int, data)
    sm.MANNEDTURRET_turretBases_clientPublicData[int.id] = data
end

---@param int Interactable
---@return table
function sm.GetInteractableClientPublicData(int)
    return sm.MANNEDTURRET_turretBases_clientPublicData[int.id] or {}
end

-- #region Functions
---@param char Character
function SendDamageEventToCharacter(char, args)
	if not sm.exists(char) then return end

	if char:isPlayer() then
		sm.event.sendToPlayer(char:getPlayer(), "sv_e_takeDamage", args)
	else
		local unit = char:getUnit()
		if not sm.exists(unit) then return end

		sm.event.sendToUnit(unit, "sv_e_takeDamage", args)
	end
end

---Get the yaw and pitch from a normalized directional vector
---@param direction Vec3 The normalized directional vector
---@return number yaw The yaw
---@return number pitch The pitch
function getYawPitch( direction )
    return math.atan2(direction.y, direction.x) - math.pi/2, math.asin(direction.z)
end

function sm.isOverrideAmmoType(self, ammoType)
    return type(ammoType or self.ammoType) == "table"
end

---@return AmmoType
function sm.GetTurretAmmoData(self, ammoType)
    ammoType = ammoType or self.ammoType
    if sm.isOverrideAmmoType(self, ammoType) then
        return self.overrideAmmoTypes[ammoType.index]
    end

    return self.ammoTypes[ammoType]
end

local g_eventBindings =
{
	["Harvestable"     ] = sm.event.sendToHarvestable,
	["ScriptableObject"] = sm.event.sendToScriptableObject,
	["Character"       ] = sm.event.sendToCharacter,
	["Tool"            ] = sm.event.sendToTool,
	["Interactable"	   ] = sm.event.sendToInteractable,
	["Unit"			   ] = sm.event.sendToUnit,
	["Player"		   ] = sm.event.sendToPlayer,
	["World"		   ] = sm.event.sendToWorld
}

function SendEventToObject(object, callback, args)
    g_eventBindings[type(object)](object, callback, args)
end

-- #region quat lerp
-- https://stackoverflow.com/questions/46156903/how-to-lerp-between-two-quaternions
local quat_slerp = sm.quat.slerp
local quat       = sm.quat.new

local function dot(a, b)
    return a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w;
end

local function normalise(a)
    local l = 1.0 / math.sqrt(dot(a, a));
    return quat(l*a.x, l*a.y, l*a.z, l*a.w);
end

function nlerp(a, b, t)
    return normalise(quat_slerp(a, b, t));
end
-- #endregion

function BoolToNum(bool)
    return bool and 1 or 0
end