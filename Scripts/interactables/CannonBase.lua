dofile "TurretBase.lua"

---@class CannonBase : TurretBase
CannonBase = class(TurretBase)
CannonBase.connectionInput = 2^14 + 2^15 + 2^16
CannonBase.seatUUID = "f2efb390-b77d-4587-b2ce-b895698e2fd5"
CannonBase.seatHologramUUID = "80196448-2fd0-40cc-8085-093f27f48158"
CannonBase.explosionDebrisData = {
    { uuid = sm.uuid.new("81b668f4-af00-4fbc-b359-dd1b35b939e5"), offset = sm.vec3.new(0.960741,    -2.49486,   -0.842322) * 0.25 },
    { uuid = sm.uuid.new("81b668f4-af00-4fbc-b359-dd1b35b939e5"), offset = sm.vec3.new(-0.960741,   -2.49486,   -0.842322) * 0.25 },
    { uuid = sm.uuid.new("195fdc52-d6f0-4638-b770-5de70f00c3f2"), offset = sm.vec3.new(0,            0.396581,    6.14909) * 0.25 },
    { uuid = sm.uuid.new("caa2bcc0-e207-4759-b841-6510a023c881"), offset = sm.vec3.new(-2.04222,    -1.0867,       2.6493) * 0.25 },
    { uuid = sm.uuid.new("187dbc85-b8af-4a08-9bb7-0dc764e927c0"), offset = sm.vec3.new(2.13494,     0.363002,     2.99947) * 0.25 },
    { uuid = sm.uuid.new("1cc59da0-8408-4b76-bac1-cea1e7e7ece6"), offset = sm.vec3.new(0,           0.847786,    1.69998) * 0.25 },
}