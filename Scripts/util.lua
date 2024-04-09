---@class AmmoType
---@field name string
---@field damage? number
---@field velocity? number
---@field fireCooldown number
---@field spread? number
---@field effect EffectName|string
---@field isPart? boolean
---@field ammo Uuid
---@field uuid Uuid

dofile "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua"

vec3_right    = sm.vec3.new(1,0,0)
vec3_forward  = sm.vec3.new(0,1,0)
vec3_up       = sm.vec3.new(0,0,1)
vec3_zero     = sm.vec3.zero()
vec3_one      = sm.vec3.one()
camOffset     = sm.vec3.new(0,0,0.575)

ShootState = {
    null = 0,
    hold = 1,
    toggle = 2
}

local repairTick = 0
local checkedTick = 0
function getRepairText()
    local tick = sm.game.getCurrentTick()
    if tick%20 == 0 and tick ~= checkedTick then
        repairTick = repairTick + 1
        checkedTick = tick
    end

    return ("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>Repairing%s</p>"):format(string.rep(".", repairTick%4))
end

function getHealthDisplay(health)
    local green = math.ceil(health/100)
    return ("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>Health: [%s%s#444444]</p>"):format(string.rep("#00f000|", green), string.rep("#ff0000|", 10 - green))
end

---Get the yaw and pitch from a normalized directional vector
---@param direction Vec3 The normalized directional vector
---@return number yaw The yaw
---@return number pitch The pitch
function getYawPitch( direction )
    return math.atan2(direction.y, direction.x) - math.pi/2, math.asin(direction.z)
end

-- #region quat lerp
-- https://stackoverflow.com/questions/46156903/how-to-lerp-between-two-quaternions
local function dot(a, b)
    return a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w;
end

local function negate(a)
    return sm.quat.new(-a.x, -a.y, -a.z, -a.w);
end

local function normalise(a)
    local l = 1.0 / math.sqrt(dot(a, a));
    return sm.quat.new(l*a.x, l*a.y, l*a.z, l*a.w);
end

local function quat_lerp(a, b,t)
    local l2 = dot(a, b);
    if(l2 < 0.0) then
        b = negate(b);
    end
    local c = sm.quat.identity();
    c.x = a.x - t*(a.x - b.x);
    c.y = a.y - t*(a.y - b.y);
    c.z = a.z - t*(a.z - b.z);
    c.w = a.w - t*(a.w - b.w);
    return c;
end

function nlerp(a, b, t)
    return normalise(quat_lerp(a, b, t));
end
-- #endregion

function BoolToNum(bool)
    return bool and 1 or 0
end