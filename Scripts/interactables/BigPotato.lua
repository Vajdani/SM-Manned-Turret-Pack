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
    local projectile = sm.uuid.new("4cc37871-c53f-4f47-9e68-d08f84492d6a")
    for i = 0, hor do
        for j = 0, ver do
            local frac = j / ver
            local horFrac = math.sin(frac * 2) --math.sin(frac) --christmas tree pattern
            local dir = sm.vec3.new(math.sin(i) * horFrac, 0.8 - frac * 1.6, math.cos(i) * horFrac)
            sm.projectile.shapeProjectileAttack(projectile, 28, zero, sm.noise.gunSpread(dir, spreadAngle) * 5, shape)
        end
    end

    shape:destroyShape()
end