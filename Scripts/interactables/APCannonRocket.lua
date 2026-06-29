dofile "CannonRocket.lua"

---@class APCannonRocket : CannonRocket
APCannonRocket = class(CannonRocket)

function APCannonRocket:sv_OnExplode(position)
    --sm.physics.explode(position, 7, 5, 7, 15, "PropaneTank - ExplosionBig", self.shape)

    local dir = self.shape.velocity:normalize()
    while true do
        local hit, result = sm.physics.raycast(position, position + dir, self.shape)
        if hit then
            sm.physics.explode(position, 3, 2, 4, 7, "PropaneTank - ExplosionSmall", self.shape)
            position = result.pointWorld + dir * 0.01

            sm.effect.playEffect("Part - Upgrade", position)

            local type = result.type
            if type == "character" then
                sm.event.sendToCharacter(result:getCharacter(), "sv_e_takeDamage", { damage = 9999 })
            elseif type == "body" then
                result:getShape():destroyShape()
            elseif type == "harvestable" then
                result:getHarvestable():destroy()
            else
                break
            end
        else
            break
        end
    end
end