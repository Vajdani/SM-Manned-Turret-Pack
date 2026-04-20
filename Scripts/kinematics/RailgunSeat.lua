dofile "TurretSeat.lua"

---@class RailgunSeat : TurretSeat
RailgunSeat = class(TurretSeat)
RailgunSeat.baseUUID = "48700b0e-6f0b-40b5-bdde-e0ba0c9f2e69"
RailgunSeat.ammoTypes = {
    {
        name = "Spike",
        damage = 1000,
        velocity = 450,
        recoilStrength = 1,
        fireCooldown = 20,
        spread = 0.1,
        chargeTime = 20,
        effect = "Cannon - Shoot",
        ammo = sm.uuid.new("480ee8b5-d658-449e-9393-c9ac10667da9"),
        uuid = sm.uuid.new("fad5bb05-b6da-46ec-92f7-9ffb38bd6c9b")
    }
}
RailgunSeat.containerToAmmoType = {
    ["d021e2ac-ef62-415c-a0a3-c6da0c43cef2"] = 1
}

function RailgunSeat:server_onCreate()
    TurretSeat.server_onCreate(self)

    self.sv_charge = {
        current = 0,
        disabledTick = 0
    }
end

function RailgunSeat:server_onFixedUpdate()
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
    if canShoot then
        local finalFirePos
        if sm.item.isPart(ammoData.uuid) then
            local projectileRot = rot * turret_projectile_rotation_adjustment
            finalFirePos = endPos - projectileRot * sm.item.getShapeOffset(ammoData.uuid)
            local projectile = sm.shape.createPart(ammoData.uuid, finalFirePos, projectileRot)

            if ammoData.velocity then
                sm.physics.applyImpulse(projectile, (dir * ammoData.velocity + self.base.body.velocity) * projectile.mass, true)
            end

            self:sv_OnPartFire(ammoType, ammoData, projectile, caller)
        else
            finalFirePos = endPos + dir * (hit and 0 or 0.25)
            for i = 1, 100 do
                sm.projectile.projectileAttack( ammoData.uuid, ammoData.damage, finalFirePos, sm.noise.gunSpread(dir, ammoData.spread or 0) * ammoData.velocity + self.base.body.velocity, caller, nil, nil, i/100 * 10 )
            end

            self:sv_OnProjectileFire(ammoType, ammoData, caller)
        end

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

    local parent = self.cl_base:getSingleParent()
    if parent ~= self.parent then
        self.ammoType = self:getAmmoType(parent)
        self.parent = parent
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

        sm.effect.playEffect(sm.GetTurretAmmoData(self, args.ammoType).effect, args.pos, vec3_zero, sm.vec3.getRotation(vec3_up, args.dir))
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
                self:sv_shoot(self.ammoType, char:getPlayer())
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
