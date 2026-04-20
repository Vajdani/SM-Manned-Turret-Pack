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
        fireCooldown = 40,
        spread = 0.1,
        effect = "Turret - Shoot",
        ammo = sm.uuid.new("480ee8b5-d658-449e-9393-c9ac10667da9"),
        uuid = sm.uuid.new("fad5bb05-b6da-46ec-92f7-9ffb38bd6c9b")
    }
}
RailgunSeat.containerToAmmoType = {
    ["d021e2ac-ef62-415c-a0a3-c6da0c43cef2"] = 1
}

function RailgunSeat:getFirePos()
    local pos = self:getTurretPosition()
    local rot = self.harvestable.worldRotation
    local offsetBase = vec3_forward * 0.22
    return pos + rot * offsetBase, pos + rot * (vec3_up * 2 + offsetBase)
end
