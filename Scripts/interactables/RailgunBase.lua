dofile "TurretBase.lua"

---@class RailgunBase : TurretBase
RailgunBase = class(TurretBase)
RailgunBase.connectionInput = connectiontype_railgunspike
RailgunBase.seatUUID = "ce51d535-7a28-4532-82e2-f39f7f41ac36"
RailgunBase.seatHologramUUID = "417e0474-5a69-4966-b561-74fc0feccc71"
RailgunBase.explosionDebrisData = {
    { uuid = sm.uuid.new("81b668f4-af00-4fbc-b359-dd1b35b939e5"), offset = vec3(0.960741,    -2.49486,   -0.842322) * 0.25 },
    { uuid = sm.uuid.new("81b668f4-af00-4fbc-b359-dd1b35b939e5"), offset = vec3(-0.960741,   -2.49486,   -0.842322) * 0.25 },
    { uuid = sm.uuid.new("195fdc52-d6f0-4638-b770-5de70f00c3f2"), offset = vec3(0,            0.396581,    6.14909) * 0.25 },
    { uuid = sm.uuid.new("caa2bcc0-e207-4759-b841-6510a023c881"), offset = vec3(-2.04222,    -1.0867,       2.6493) * 0.25 },
    { uuid = sm.uuid.new("187dbc85-b8af-4a08-9bb7-0dc764e927c0"), offset = vec3(2.13494,     0.363002,     2.99947) * 0.25 },
    { uuid = sm.uuid.new("1cc59da0-8408-4b76-bac1-cea1e7e7ece6"), offset = vec3(0,           0.847786,     1.69998) * 0.25 },
}