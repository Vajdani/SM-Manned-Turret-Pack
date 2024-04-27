dofile "TurretSeat.lua"

---@class MinigunSeat : TurretSeat
MinigunSeat = class(TurretSeat)
MinigunSeat.baseUUID = "ae0a8816-00d8-4515-932b-00661ef20a0a"
MinigunSeat.ammoTypes = {
    {
        name = "AA Rounds",
        damage = 50,
        velocity = 450,
        recoilStrength = 0.25,
        fireCooldown = 3,
        spread = 12.5,
        overheatPerShot = 0.015,
        effect = "Turret - Shoot",
        ammo = sm.uuid.new("cabf45e9-a47d-4086-8f5f-4f806d5ec3a2"),
        uuid = sm.uuid.new("fad5bb05-b6da-46ec-92f7-9ffb38bd6c9b")
    }
}



function MinigunSeat:client_onCreate()
    TurretSeat.client_onCreate(self)

    self.fireCharge = 0

    self.overheatProgress = 0
    self.overheated = false

    self.barrelSpin = 0
end

function MinigunSeat:client_onUpdate(dt)
    if not sm.exists(self.cl_base) then return end

    self.barrelSpin = self.barrelSpin + dt * 100 --* self.fireCharge
    local one = (math.sin(0-2*math.pi*(self.barrelSpin+17)/134)+1)/2
    local two = (math.cos(2*math.pi*(self.barrelSpin+17)/134)+1)/2
    self.harvestable:setPoseWeight(0, one)
    self.harvestable:setPoseWeight(1, two)

    if self.seated then
        SetPlayerCamOverride({ cameraState = 5 })

        self:cl_displayAmmoInfo()

        sm.gui.setProgressFraction(self.fireCharge)
        local red = math.ceil(self.overheatProgress * 1000/100)
        sm.gui.setInteractionText(("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>[%s%s#444444]</p>"):format(string.rep("#ff0000|", red), string.rep("#00f000|", 10 - red)))
    end
end

function MinigunSeat:client_onFixedUpdate(dt)
    if not sm.exists(self.cl_base) then return end

    local col = self.cl_base.shape.color
    if self.col ~= col then
        self.col = col
        self.harvestable:setColor(col)
    end

    local isFiring = self.shootState ~= ShootState.null
    if isFiring and not self.overheated then
        self.fireCharge = math.min(self.fireCharge + dt * 2, 1)
        if self.fireCharge < 1 then
            return
        end
    else
        if self.overheated then
            self.fireCharge = 0
            self.overheatProgress = math.max(self.overheatProgress - dt * 0.1, 0)
            self.overheated = self.overheatProgress > 0
        else
            self.fireCharge = math.max(self.fireCharge - dt * 0.5, 0)
            self.overheatProgress = math.max(self.overheatProgress - dt * 0.2, 0)
        end

        return
    end

    if not self.seated then return end

    if self.cl_base.body:isOnLift() and isFiring then
        self.shootState = ShootState.null
        self:cl_updateHotbar()
    end

    local parent = self.cl_base:getSingleParent()
    if parent ~= self.parent then
        self.ammoType = self:getAmmoType(parent)
        self.parent = parent
    end

    self.shootTimer = math.max(self.shootTimer - 1, 0)
    if isFiring and self.shootTimer <= 0 then
        self.shootTimer = self:getAmmoData().fireCooldown
        self.network:sendToServer("sv_shoot", self.ammoType)
    end
end

function MinigunSeat:cl_shoot(args)
    if args.canShoot then
        local ammoData = self:getAmmoData(args.ammoType)
        self.overheatProgress = math.min(self.overheatProgress + ammoData.overheatPerShot, 1)
        if self.overheatProgress >= 1 then
            --self.overheated = true
        end

        sm.effect.playEffect(ammoData.effect, args.pos, vec3_zero, sm.vec3.getRotation(vec3_up, args.dir))

        local rot = self.harvestable.worldRotation
        sm.debris.createDebris(
            sm.uuid.new("0dba257b-b907-4919-baaf-2fefe19f4e24"),
            args.pos - rot * vec3_up,
            rot,
            rot * sm.quat.angleAxis(math.rad(30), vec3_up) * vec3_forward * 5,
            sm.vec3.new(math.random(-100, 100) * 0.01, math.random(-100, 100) * 0.01, math.random(-100, 100) * 0.01):normalize() * 10,
            sm.color.new("ffff00")
        )
    else
        sm.effect.playEffect("Turret - FailedShoot", args.pos)
    end
end

function MinigunSeat:getFirePos()
    local pos = self:getTurretPosition()
    local rot = self.harvestable.worldRotation
    local offsetBase = vec3_forward * 0.22
    return pos + rot * offsetBase, pos + rot * (vec3_up * 2 + offsetBase)
end