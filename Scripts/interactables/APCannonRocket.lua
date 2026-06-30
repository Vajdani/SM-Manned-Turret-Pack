dofile "CannonRocket.lua"

---@class APCannonRocket : CannonRocket
APCannonRocket = class(CannonRocket)

function APCannonRocket:sv_OnExplode(position)
    --sm.physics.explode(position, 7, 5, 7, 15, "PropaneTank - ExplosionBig", self.shape)

    if count then
        for i = 1, count do
            sm.debugDraw.clear("apImpact"..i)
        end
    end

    sm.debugDraw.addSphere("apImpactStart", position, 0.25, sm.color.new(1,0,0))

    local dir = self.shape.velocity:normalize()
    local distance = 10

    sm.debugDraw.addArrow("apLength", position, position + dir * distance)

    count = 0
    while distance > 0 do
        local hit, result = sm.physics.raycast(position, position + dir * distance, self.shape.body)
        if hit then
            count = count + 1

            -- sm.physics.explode(position, 3, 2, 4, 7, "PropaneTank - ExplosionSmall", self.shape)
            distance = distance - distance * result.fraction --- (result.pointWorld - position):length2()
            position = result.pointWorld + dir * 0.01

            if count == 1 then
                sm.debugDraw.addSphere("apImpact"..count, position, 0.1, sm.color.new(0,1,1))
            else
                sm.debugDraw.addSphere("apImpact"..count, position, 0.1, sm.color.new(0,1,0))
            end

            sm.physics.explode(position, 4, 2, 3, 8, "PropaneTank - ExplosionSmall")

            local type = result.type
            if type == "character" then
                sm.event.sendToCharacter(result:getCharacter(), "sv_e_takeDamage", { damage = 9999 })
            elseif type == "body" then
                local shape = result:getShape()
                if shape.isBlock then
                    shape:destroyBlock(shape:getClosestBlockLocalPosition(position))--, vec3_one * 3)
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
                result:getHarvestable():destroy()
            else
                break
            end
        else
            break
        end
    end

    sm.physics.explode(position, 7, 2, 3, 8, "PropaneTank - ExplosionBig")
end