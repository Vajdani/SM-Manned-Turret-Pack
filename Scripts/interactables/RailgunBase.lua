dofile "TurretBase.lua"

---@class RailgunBase : TurretBase
RailgunBase = class(TurretBase)
RailgunBase.connectionInput = connectiontype_railgunspike
RailgunBase.seatUUID = "ce51d535-7a28-4532-82e2-f39f7f41ac36"
RailgunBase.seatHologramUUID = tostring(kin_interactive_cannon_seat_hologram)
RailgunBase.explosionDebrisData = {
    { uuid = obj_effect_turret_seat_debris_bar,         offset = vec3(0.960741,    -2.49486,   -0.842322) * 0.25 },
    { uuid = obj_effect_turret_seat_debris_bar,         offset = vec3(-0.960741,   -2.49486,   -0.842322) * 0.25 },
    { uuid = obj_effect_cannon_seat_debris_barrel,      offset = vec3(0,            0.396581,    6.14909) * 0.25 },
    { uuid = obj_effect_cannon_seat_debris_keyboard,    offset = vec3(-2.04222,    -1.0867,       2.6493) * 0.25 },
    { uuid = obj_effect_cannon_seat_debris_screen,      offset = vec3(2.13494,     0.363002,     2.99947) * 0.25 },
    { uuid = obj_effect_cannon_seat_debris_handle,      offset = vec3(0,           0.847786,     1.69998) * 0.25 },
}