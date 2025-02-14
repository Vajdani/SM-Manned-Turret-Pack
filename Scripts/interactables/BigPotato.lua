---@class BigPotato : ShapeClass
BigPotato = class()

function BigPotato:server_onCollision(other, position, selfPointVelocity, otherPointVelocity, normal)
    local collisionDirection = (selfPointVelocity - otherPointVelocity):normalize()
	local diffVelocity = (selfPointVelocity - otherPointVelocity):length()
	local dotFraction = math.abs( collisionDirection:dot( normal ) )
	if diffVelocity * dotFraction >= 6 then
        self:sv_explode()
    end
end

function BigPotato:server_onExplosion()
    self:sv_explode()
end

function BigPotato:server_onMelee()
    self:sv_explode()
end

function BigPotato:server_onProjectile()
    self:sv_explode()
end

local zero = sm.vec3.zero()
function BigPotato:sv_explode()
    local shape = self.shape
    local hor = 45
    local ver = 20
    local spreadAngle = 90
    local uuid = sm.uuid.new("baf7ff9d-191a-4ea4-beba-e160ceb54daf")
    for i = 0, hor do
        for j = 0, ver do
            local frac = j / ver
            local horFrec = math.sin(frac * 2) --math.sin(frac) --christmas tree pattern
            local dir = sm.vec3.new(math.sin(i) * horFrec, 0.8 - frac * 1.6, math.cos(i) * horFrec)
            sm.projectile.shapeProjectileAttack(uuid, 28, zero, sm.noise.gunSpread(dir, spreadAngle) * 5, shape)
        end
    end

    shape:destroyShape()
end