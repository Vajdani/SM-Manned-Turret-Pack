---@class AmmoType
---@field name string
---@field damage number
---@field velocity number
---@field fireCooldown number
---@field spread number
---@field effect EffectName|string
---@field ammo Uuid
---@field uuid Uuid

dofile "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua"

vec3_right    = sm.vec3.new(1,0,0)
vec3_forward  = sm.vec3.new(0,1,0)
vec3_up       = sm.vec3.new(0,0,1)
vec3_zero = sm.vec3.zero()
vec3_one = sm.vec3.one()
camOffset = sm.vec3.new(0,0,0.575)

---@type AmmoType[]
ammoTypes = {
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
containerToAmmoType = {
    ["756594d6-6fdd-4f60-9289-a2416287f942"] = 1,
    ["037e3ecb-e0a6-402b-8187-a7264863c64f"] = 2,
    ["ea10d1af-b97a-46fb-8895-dfd1becb53bb"] = 3,
    --["be29592a-ef58-4b1d-b18c-895023abd27f"] = 4,
    --["76331bbf-abbd-4b8d-bb54-f721a5b6193b"] = 5,
    ["096d4daf-639e-4947-a1a6-1890eaa94464"] = 4,
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