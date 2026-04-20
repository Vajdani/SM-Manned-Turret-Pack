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
        effect = "Turret - Shoot",
        ammo = sm.uuid.new("480ee8b5-d658-449e-9393-c9ac10667da9"),
        uuid = sm.uuid.new("fad5bb05-b6da-46ec-92f7-9ffb38bd6c9b")
    }
}
RailgunSeat.containerToAmmoType = {
    ["d021e2ac-ef62-415c-a0a3-c6da0c43cef2"] = 1
}

function RailgunSeat:server_onCreate()
    TurretSeat.server_onCreate(self)

    self.sv_shotCharge = 0
    self.sv_shootingDisabledTick = 0
end

function RailgunSeat:server_onFixedUpdate()
    local char = self.harvestable:getSeatCharacter()
    local tick = sm.game.getServerTick()
    if not char or tick < self.sv_shootingDisabledTick then return end

    if self.sv_shootState ~= ShootState.null then
        local ammoData = sm.GetTurretAmmoData(self)
        self.sv_shotCharge = math.min(self.sv_shotCharge + 1, ammoData.chargeTime)

        if self.sv_shotCharge == ammoData.chargeTime then
            self.sv_shotCharge = 0
            self.sv_shootingDisabledTick = tick + ammoData.fireCooldown
            self:sv_shoot(self.ammoType, self.harvestable:getSeatCharacter():getPlayer())
        end
    else
        self.sv_shotCharge = math.max(self.sv_shotCharge - 1, 0)
    end
end



function RailgunSeat:client_onFixedUpdate()
    if not sm.exists(self.cl_base) then return end

    local col = self.cl_base.shape.color
    if self.col ~= col then
        self.col = col
        self.harvestable:setColor(col)
    end

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



function RailgunSeat:getFirePos()
    local pos = self:getTurretPosition()
    local rot = self.harvestable.worldRotation
    local offsetBase = vec3_forward * 0.22
    return pos + rot * offsetBase, pos + rot * (vec3_up * 2 + offsetBase)
end
