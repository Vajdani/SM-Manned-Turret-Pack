dofile "TurretBase.lua"

---@class CannonBase : TurretBase
CannonBase = class(TurretBase)
CannonBase.connectionInput = 2^14 + 2^15 + 2^16
CannonBase.seatUUID = "f2efb390-b77d-4587-b2ce-b895698e2fd5"
CannonBase.seatHologramUUID = "80196448-2fd0-40cc-8085-093f27f48158"
CannonBase.explosionDebrisData = {
    { uuid = sm.uuid.new("81b668f4-af00-4fbc-b359-dd1b35b939e5"), offset = sm.vec3.new(0.960741,    -2.49486,   -0.842322) * 0.25 },
    { uuid = sm.uuid.new("81b668f4-af00-4fbc-b359-dd1b35b939e5"), offset = sm.vec3.new(-0.960741,   -2.49486,   -0.842322) * 0.25 },
    --{ uuid = sm.uuid.new("5dde0f36-1cbb-47ba-a9ba-a0cc2b1db555"), offset = sm.vec3.new(-1.07416,    1.37402,      5.55211) * 0.25 },
    --{ uuid = sm.uuid.new("5dde0f36-1cbb-47ba-a9ba-a0cc2b1db555"), offset = sm.vec3.new(1.07416,     1.37402,      5.55211) * 0.25 },
    { uuid = sm.uuid.new("a58a7a52-6737-468f-a499-aee18faedabb"), offset = sm.vec3.new(0.971095,    1.18554,      2.06928) * 0.25 },
    { uuid = sm.uuid.new("17a8ce54-0617-422c-bac7-9c5c07203094"), offset = sm.vec3.new(-0.971095,   1.18554,      2.06928) * 0.25 },
    { uuid = sm.uuid.new("ea9511ab-26bf-4dcb-9929-7c688f2b240e"), offset = sm.vec3.new(1.45117,     -0.877968,    2.84755) * 0.25 },
    { uuid = sm.uuid.new("d793783b-6ac8-4fb7-b9b4-b7f2d159efed"), offset = sm.vec3.new(-1.45117,    -0.877968,    2.84755) * 0.25 },
}