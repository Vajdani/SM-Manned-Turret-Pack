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



function CannonBase:sv_spawnNukeOnDestroy(ammoType)
    local ammoData = CannonSeat.overrideAmmoTypes[ammoType.index]
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

    sm.shape.createPart(ammoData.ammo, endPos - projectileRot * sm.item.getShapeOffset(ammoData.ammo), projectileRot)
    self:sv_e_setAmmoType(ammoType.previous)
end