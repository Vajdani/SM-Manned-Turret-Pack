dofile "TurretBase.lua"

---@class CannonBase : TurretBase
CannonBase = class(TurretBase)
CannonBase.connectionInput = connectiontype_turretexplosive + connectiontype_cannonrocket + connectiontype_cannonratshot
CannonBase.seatUUID = "f2efb390-b77d-4587-b2ce-b895698e2fd5"
CannonBase.seatHologramUUID = tostring(kin_interactive_cannon_seat_hologram)
CannonBase.explosionDebrisData = {
    { uuid = obj_effect_turret_seat_debris_bar,         offset = vec3(0.960741,    -2.49486,   -0.842322) * 0.25 },
    { uuid = obj_effect_turret_seat_debris_bar,         offset = vec3(-0.960741,   -2.49486,   -0.842322) * 0.25 },
    { uuid = obj_effect_cannon_seat_debris_barrel,      offset = vec3(0,            0.396581,    6.14909) * 0.25 },
    { uuid = obj_effect_cannon_seat_debris_keyboard,    offset = vec3(-2.04222,    -1.0867,       2.6493) * 0.25 },
    { uuid = obj_effect_cannon_seat_debris_screen,      offset = vec3(2.13494,     0.363002,     2.99947) * 0.25 },
    { uuid = obj_effect_cannon_seat_debris_handle,      offset = vec3(0,           0.847786,     1.69998) * 0.25 },
}

function CannonBase:server_onDestroy()
    if sm.isOverrideAmmoType(self) then
        self:sv_spawnNukeOnDestroy()
    end

    TurretBase.server_onDestroy(self)
end

function CannonBase:sv_spawnNukeOnDestroy()
    local world
    if sm.exists(self.shape) then
        world = self.shape.body:getWorld()
    else
        world = self.turret:getWorld()
        self.shape = {
            worldPosition = self.worldPosition,
            worldRotation = self.worldRotation,
            at = self.worldRotation * vec3_up,
            velocity = vec3_zero
        }
    end

    local ammoData = CannonSeat.overrideAmmoTypes[self.sv_ammoType.index]
    local turretRot = self.shape.worldRotation * angleAxis(self.dir.x, vec3_forward) * angleAxis(-self.dir.y, vec3_right)
    local projectileRot = turretRot * turret_projectile_rotation_adjustment
    ---@diagnostic disable: missing-fields
    local startPos, endPos = CannonSeat.getFirePos(
        {
            harvestable = {
                worldPosition = self:getSeatPos(),
                worldRotation = turretRot
            },
            sv_base = self.interactable,
            getTurretPosition = CannonSeat.getTurretPosition
        }
    )

    sm.event.sendToWorld(world, "sv_e_spawnPart", {
        uuid = ammoData.ammo,
        pos = endPos - projectileRot * sm.item.getShapeOffset(ammoData.ammo),
        rot = projectileRot,
    })

    if type(self.shape) == "Shape" then
        self:sv_e_setAmmoType(self.sv_ammoType.previous)
    end
end