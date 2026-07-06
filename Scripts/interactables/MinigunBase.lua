dofile "TurretBase.lua"

---@class MinigunBase : TurretBase
MinigunBase = class(TurretBase)
MinigunBase.seatUUID = "ff5b4291-25cd-4af9-b325-5c6b2a2fd071"
MinigunBase.seatHologramUUID = tostring(kin_interactive_cannon_seat_hologram)
MinigunBase.explosionDebrisData = {
    { uuid = obj_effect_turret_seat_debris_bar,         offset = vec3(0.960741,    -2.49486,   -0.842322) * 0.25 },
    { uuid = obj_effect_turret_seat_debris_bar,         offset = vec3(-0.960741,   -2.49486,   -0.842322) * 0.25 },
    { uuid = obj_effect_cannon_seat_debris_barrel,      offset = vec3(0,            0.396581,    6.14909) * 0.25 },
    { uuid = obj_effect_cannon_seat_debris_keyboard,    offset = vec3(-2.04222,    -1.0867,       2.6493) * 0.25 },
    { uuid = obj_effect_cannon_seat_debris_screen,      offset = vec3(2.13494,     0.363002,     2.99947) * 0.25 },
    { uuid = obj_effect_cannon_seat_debris_handle,      offset = vec3(0,           0.847786,     1.69998) * 0.25 },
}