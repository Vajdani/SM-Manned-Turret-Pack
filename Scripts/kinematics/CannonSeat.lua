dofile "TurretSeat.lua"

---@class CannonSeat : TurretSeat
CannonSeat = class(TurretSeat)
CannonSeat.ammoTypes = {
    {
        name = "Cannon Ball",
        velocity = 50,
        fireCooldown = 20, --2.5 * 40,
        effect = "SpudgunBasic - BasicMuzzel",
        ammo = sm.uuid.new("6d8215fc-8d35-4754-a580-6d1974b87fb7"),
        uuid = sm.uuid.new("24d5e812-3902-4ac3-b214-a0c924a5c40f")
    }
}
CannonSeat.containerToAmmoType = {
    ["d9e6453a-2e8c-47f8-a843-d0e700957d39"] = 1,
}
CannonSeat.baseUUID = "a0c96d35-37ca-4cf9-82d8-9b9077132918"



local rayFilter = sm.physics.filter.dynamicBody + sm.physics.filter.staticBody + sm.physics.filter.terrainAsset + sm.physics.filter.terrainSurface + sm.physics.filter.harvestable
function CannonSeat:sv_shoot(ammoType, caller)
    self.shotCounter = self.shotCounter + 1
    local startPos, endPos = self:getFirePos()
    local rot = self.harvestable.worldRotation
    local hit, result = sm.physics.raycast(startPos, endPos, self.harvestable, rayFilter)
    if hit then
        print("abort")
        self.network:sendToClients("cl_shoot", { canShoot = false, pos = endPos })
        return
    end

    local dir = rot * vec3_up
    local canShoot = self:canShoot(ammoType)
    if canShoot then
        local ammoData = self.ammoTypes[ammoType]

        local projectileRot = rot * sm.quat.angleAxis(math.rad(90), vec3_right)
        local projectile = sm.shape.createPart(ammoData.uuid, endPos - projectileRot * sm.item.getShapeOffset(ammoData.uuid), projectileRot)
        sm.physics.applyImpulse(projectile, dir * ammoData.velocity * projectile.mass, true)
    end

    self.network:sendToClients("cl_shoot", { canShoot = canShoot, pos = endPos, dir = dir, shotCount = self.shotCounter, ammoType = ammoType })
end



function CannonSeat:client_onUpdate(dt)
    if not sm.exists(self.cl_base) then return end

    local speed = dt * 7.5
    self.recoil_r = math.max(self.recoil_r - speed, 0)
    self.harvestable:setPoseWeight(1, sm.util.easing("easeOutCubic", self.recoil_r))

    if self.seated then
        sm.localPlayer.getPlayer().clientPublicData.customCameraData = { cameraState = 5 }

        local parent = self.cl_base:getSingleParent()
        if parent then
            local container = parent:getContainer(0)
            local uuid = self.ammoTypes[self.ammoType].ammo
            sm.gui.setInteractionText(("<p textShadow='false' bg='gui_keybinds_bg_white' color='#444444' spacing='9'>%d / %d</p>"):format(sm.container.totalQuantity(container, uuid), container:getSize() * container:getMaxStackSize()))
        end
    end
end

function CannonSeat:getFirePos()
    local pos = self.harvestable.worldPosition
    local rot = self.harvestable.worldRotation

    local offsetBase = vec3_forward * 0.35
    return pos + rot * offsetBase, pos + rot * (vec3_up * 1.8 + offsetBase)
end

function CannonSeat:cl_shoot(args)
    if args.canShoot then
        self.recoil_r = 1
        sm.effect.playEffect(self.ammoTypes[args.ammoType].effect, args.pos, vec3_zero, sm.vec3.getRotation(vec3_up, args.dir))
    else
        sm.audio.play("Lever off", args.pos)

        if self.seated then
            self.shootState = ShootState.null
            self:cl_updateHotbar()
        end
    end
end