dofile "TurretBase.lua"

---@class CannonBase : TurretBase
CannonBase = class(TurretBase)
CannonBase.connectionInput = 2^14 + 2^15 + 2^16
CannonBase.seatUUID = "f2efb390-b77d-4587-b2ce-b895698e2fd5"
CannonBase.seatHologramUUID = "80196448-2fd0-40cc-8085-093f27f48158"
CannonBase.explosionDebrisData = {
    { uuid = sm.uuid.new("81b668f4-af00-4fbc-b359-dd1b35b939e5"), offset = sm.vec3.new(0.960741,    -2.49486,   -0.842322) * 0.25 },
    { uuid = sm.uuid.new("81b668f4-af00-4fbc-b359-dd1b35b939e5"), offset = sm.vec3.new(-0.960741,   -2.49486,   -0.842322) * 0.25 },
}