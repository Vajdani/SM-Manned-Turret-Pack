---@class CannonRocket : ShapeClass
CannonRocket = class()
CannonRocket.lifeTime = 15 * 40

function CannonRocket:server_onCreate()
    local publicData = self.interactable.publicData
    self.isPrimed = publicData ~= nil

    if self.isPrimed then
        self.thrustActivate = 0
        self.deathTick = sm.game.getServerTick() + self.lifeTime

        self.seat = self.interactable.publicData.seat

        self.network:setClientData({ owner = publicData.owner, deathTick = self.deathTick })
    end
end

function CannonRocket:server_onCollision(other, position, selfPointVelocity, otherPointVelocity, normal)
    if not self.isPrimed then return end

    self:sv_explode(position)
end

function CannonRocket:server_onFixedUpdate(dt)
    if not self.isPrimed then return end

    self:sv_controlRocket(dt)

    if self.deathTick - sm.game.getServerTick() <= 0 then
        self:sv_explode(self.shape.worldPosition)
    end
end

function CannonRocket:sv_explode(position)
    sm.event.sendToHarvestable(self.seat, "sv_onRocketExplode", position == nil)

    sm.physics.explode( position or self.shape.worldPosition, 10, 10, 12, 25, "PropaneTank - ExplosionBig", self.shape )
    self.shape:destroyShape()
end

function CannonRocket:sv_controlRocket(dt)
    local shape = self.shape

    self.thrustActivate = math.min(self.thrustActivate + dt, 1)
    local target = shape.at * sm.util.easing("easeInSine", self.thrustActivate) * 10
    sm.physics.applyImpulse(shape, ((target * 2) - ( shape.velocity * 0.3 )) * shape.mass, true)

    local body = shape.body
    sm.physics.applyTorque(body, (-body.angularVelocity * 0.5 + shape.at * self.seat.publicData.rocketRoll) * shape.mass * dt, true)
end

function CannonRocket:sv_updateDir(dir)
    local body, mass = self.shape.body, self.shape.mass
    sm.physics.applyTorque(body, vec3_up * dir.x * mass * 0.5)
    sm.physics.applyTorque(body, vec3_right * dir.y * mass * 0.5)
end



function CannonRocket:client_onCreate()
    self.isLocal = false
    self.deathTick = 0

    self.thrustEffect = sm.effect.createEffect("Thruster - Level 5", self.interactable)
    self.thrustEffect:setOffsetPosition(-vec3_forward * 0.25)
    self.thrustEffect:setOffsetRotation(sm.quat.angleAxis(math.rad(90), vec3_right))
end

function CannonRocket:client_onUpdate(dt)
    if not self.isLocal then return end

    local x, y = sm.localPlayer.getMouseDelta()
    if x ~= 0 or y ~= 0 then
        local dir = { x = x , y = y }
        self.network:sendToServer("sv_updateDir", dir)
    end

    sm.localPlayer.getPlayer().clientPublicData.customCameraData = { cameraState = 3 }
    sm.camera.setPosition(self.shape:getInterpolatedWorldPosition() + self.shape.velocity * dt)
    sm.camera.setRotation(nlerp(sm.camera.getRotation(), self.shape.worldRotation, dt * 15))

    sm.gui.setProgressFraction((self.deathTick - sm.game.getCurrentTick()) / self.lifeTime)
end

function CannonRocket:client_onClientDataUpdate(data)
    self.isLocal = data.owner == sm.localPlayer.getPlayer()
    self.interactable:setSubMeshVisible("lambert1", not self.isLocal)
    self.thrustEffect:start()

    if self.isLocal then
        self.deathTick = data.deathTick
    end
end