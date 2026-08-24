dofile "TurretSeat.lua"

---@class RailgunSeat : TurretSeat
RailgunSeat = class(TurretSeat)
RailgunSeat.baseUUID = tostring(obj_interactive_railgun_base)
RailgunSeat.ammoTypes = {
    {
        name = "Spike",
        damage = 1000,
        velocity = 450,
        recoilStrength = 5,
        fireCooldown = 20,
        spread = 0.1,
        chargeTime = 20,
        effect = "Cannon - Shoot",
        ammo = obj_railgun_spike
    }
}
RailgunSeat.containerToAmmoType = {
    [tostring(obj_container_railgun_spike)] = 1
}

function RailgunSeat:server_onCreate()
    TurretSeat.server_onCreate(self)

    self.sv_charge = {
        current = 0,
        disabledTick = 0
    }
end

function RailgunSeat:server_onFixedUpdate()
    TurretSeat.server_onFixedUpdate(self)

    self:updateCharge(self.sv_shootState, self.sv_charge)
end

local rayFilter = sm.physics.filter.dynamicBody + sm.physics.filter.staticBody + sm.physics.filter.terrainAsset + sm.physics.filter.terrainSurface + sm.physics.filter.harvestable
function RailgunSeat:sv_shoot(ammoType, caller)
    if not self.sv_controlsEnabled then return end

    self.sv_shotCounter = self.sv_shotCounter + 1

    local ammoData = sm.GetTurretAmmoData(self, ammoType)
    local startPos, endPos = self:getFirePos()
    local rot = self.harvestable.worldRotation
    local hit, result = sm.physics.spherecast(startPos, endPos, 0.1, self.harvestable, rayFilter)
    if hit then
        self.network:sendToClients("cl_shoot", { canShoot = false, pos = endPos })
        return
    end

    local dir = rot * vec3_up
    local canShoot = self:canShoot(ammoType, true) or ammoData.ignoreAmmoConsumption
    local damage = ammoData.damage
    if canShoot then
        local finalFirePos = endPos + dir * 0.25
        for k, v in pairs(self:getLaserIntersects(finalFirePos)) do
            local obj, pos = v.obj, v.pos
            if type(obj) == "Shape" then
                if obj.isBlock then
                    obj:destroyBlock(obj:getClosestBlockLocalPosition(pos))
                else
                    local int = obj.interactable
                    local classname = (sm.item.getFeatureData(obj.uuid) or {}).classname
                    if classname == "Package" then
                        sm.event.sendToInteractable( int, "sv_e_open" )
                    elseif not int or int.type ~= "scripted" or not sm.event.sendToInteractable(int, "sv_e_onHit", {
                        damage = damage,
                        source = caller,
                        position = pos,
                        normal = v.normal
                    }) then
                        obj:destroyShape()
                    end
                end
            elseif type(obj) == "Character" then
                SendDamageEventToCharacter(obj, { damage = damage, impact = dir * 10, hitPos = pos })
            elseif not sm.event.sendToHarvestable(obj, "sv_e_onHit", { damage = damage, position = pos }) then
                sm.physics.explode( pos, 100, 1, 1, 1 )
            end
        end

        self:sv_OnProjectileFire(ammoType, ammoData, caller)
        self:sv_applyFiringImpulse(ammoData, dir, finalFirePos)
    end

    self.network:sendToClients("cl_shoot", { canShoot = canShoot, pos = endPos, dir = dir, shotCount = self.sv_shotCounter, ammoType = ammoType })
end



function RailgunSeat:client_onCreate()
    TurretSeat.client_onCreate(self)

    self.cl_charge = {
        current = 0,
        disabledTick = 0
    }
end

function RailgunSeat:client_onFixedUpdate()
    if not sm.exists(self.cl_base) then return end

    local col = self.cl_base.shape.color
    if self.col ~= col then
        self.col = col
        self.harvestable:setColor(col)
    end

    self.cl_chargeData = self:updateCharge(self.cl_shootState, self.cl_charge)

    if not self.seated then return end

    if self.cl_base.body:isOnLift() and self.cl_shootState ~= ShootState.null then
        self.cl_shootState = ShootState.null
        self:cl_updateHotbar()
    end
end

function RailgunSeat:client_onUpdate(dt)
    if not sm.exists(self.cl_base) then return end

    local chargeProgress = 0
    if self.cl_chargeData then
        chargeProgress = self.cl_charge.current/self.cl_chargeData.chargeTime
    end

    self.harvestable:setPoseWeight(0, sm.util.easing("easeOutCubic", chargeProgress))

    self.recoil_r = math.max(self.recoil_r - dt * 7.5, 0)
    self.harvestable:setPoseWeight(1, sm.util.easing("easeOutCubic", self.recoil_r))

    if self.seated then
        SetPlayerCamOverride({ cameraState = 5 })

        sm.gui.setProgressFraction(chargeProgress)

        self:cl_displayAmmoInfo()
    end
end

function RailgunSeat:cl_shoot(args)
    if args.canShoot then
        self.recoil_r = 1

        sm.effect.playEffect(sm.GetTurretAmmoData(self, args.ammoType).effect, args.pos, vec3_zero, vec3_getRotation(vec3_up, args.dir))
    else
        sm.effect.playEffect("Turret - FailedShoot", args.pos)
    end
end



function RailgunSeat:updateCharge(shootState, charge)
    local char = self.harvestable:getSeatCharacter()
    local tick = sm.game.getServerTick()
    if not char or tick < charge.disabledTick then return end

    if shootState ~= ShootState.null then
        local ammoData = sm.GetTurretAmmoData(self)
        charge.current = math.min(charge.current + 1, ammoData.chargeTime)

        if charge.current >= ammoData.chargeTime then
            charge.current = 0
            charge.disabledTick = tick + ammoData.fireCooldown

            if sm.isServerMode() then
                self:sv_shoot(self.sv_ammoType or self.cl_ammoType, char:getPlayer())
            end
        end

        return ammoData
    else
        charge.current = math.max(charge.current - 1, 0)
    end
end

function RailgunSeat:getFirePos()
    local pos = self:getTurretPosition()
    local rot = self.harvestable.worldRotation
    local offsetBase = vec3_forward * 0.22
    return pos + rot * offsetBase, pos + rot * (vec3_up * 2 + offsetBase)
end

---@param pos Vec3
---@return {obj: Shape|Character|Harvestable, pos: Vec3, normal: Vec3}[]
function RailgunSeat:getLaserIntersects(pos)
    pos = pos or self:getFirePos()
    local dir = self.harvestable.worldRotation * vec3_up
    local lastIntersect
    local intersects = {}
    repeat
        -- local hit, result = sm.physics.spherecast(pos, pos + dir * 1000, 0.1, lastIntersect)
        local hit, result = sm.physics.raycast(pos, pos + dir * 1000, lastIntersect)
        if hit then
            pos = result.pointWorld --+ dir * 0.01
            lastIntersect = result:getShape() or result:getCharacter() or result:getHarvestable()
            if lastIntersect then
                table.insert(intersects, {
                    obj = lastIntersect,
                    pos = pos,
                    normal = result.normalWorld
                })
            end
        end
    until lastIntersect == nil

    return intersects
end