---@class CannonRocket : ShapeClass
CannonRocket = class()
CannonRocket.lifeTime = 15 * 40

function CannonRocket:server_onCreate()
    local publicData = self.interactable.publicData
    self.isPrimed = publicData ~= nil

    if self.isPrimed then
        self.sv_deathTick = sm.game.getServerTick() + self.lifeTime

        self.seat = publicData.seat

        local owner = publicData.owner

        self.dummy = sm.character.createCharacter(owner or sm.player.getAllPlayers()[1], sm.world.getCurrentWorld(), self.shape.worldPosition + vec3_up * 100)
        self.interactable:setSeatCharacter(self.dummy)

        self.network:setClientData({ owner = owner, deathTick = self.sv_deathTick })
    end
end

function CannonRocket:server_onDestroy()
    if self.destroyed then return end

    if sm.exists(self.seat) then
        SendEventToObject(self.seat, "sv_onRocketExplode", true)
    end

    self:sv_clearChunkLoader()
end

function CannonRocket:server_onProjectile()
    if not self.isPrimed then return end
    self:sv_explode()
end

function CannonRocket:server_onMelee()
    if not self.isPrimed then return end
    self:sv_explode()
end

function CannonRocket:server_onExplosion()
    if not self.isPrimed then return end
    self:sv_explode()
end

function CannonRocket:server_onCollision(other, position, selfPointVelocity, otherPointVelocity, normal)
    if not self.isPrimed then return end
    if other == self.seat then return end
    if type(self.seat) == "Interactable" then
        for k, v in pairs(self.seat.shape.body:getCreationShapes()) do
            if other == v then return end
        end
    end

    self:sv_explode(position)
end

local rayFilter = sm.physics.filter.dynamicBody + sm.physics.filter.staticBody + sm.physics.filter.terrainAsset + sm.physics.filter.terrainSurface + sm.physics.filter.harvestable
function CannonRocket:server_onFixedUpdate(dt)
    if not self.isPrimed then return end

    local pos = self.shape.worldPosition
    self.worldPos = pos

    local hit, result = sm.physics.spherecast(pos, pos + self.shape.at * 2, 0.1, self.shape, rayFilter)
    if hit then
        self:sv_explode(pos)
        return
    end

    self:sv_controlRocket(dt)

    if self.sv_deathTick - sm.game.getServerTick() <= 0 then
        self:sv_explode(pos)
    end
end

--external event
function CannonRocket:server_tryExplode()
    self:sv_explode()
end

function CannonRocket:sv_explode(position)
    if self.destroyed then return end

    self.destroyed = true

    if sm.exists(self.seat) then
        SendEventToObject(self.seat, "sv_onRocketExplode", position == nil)
    end

    self:sv_clearChunkLoader()

    self:sv_OnExplode(position or self.shape.worldPosition)

    self.shape:destroyShape()
end

function CannonRocket:sv_clearChunkLoader()
    local char = self.dummy
    if char and sm.exists(char) then
        if sm.exists(self.interactable) then
            self.interactable:setSeatCharacter(char)
        end

        char:setWorldPosition(vec3(self.worldPos.x, self.worldPos.y, -512))
        sm.log.warning("ROCKET LOADER DESTROYED")
    else
        sm.log.error("ROCKET LOADER NOT DESTROYED")
        sm.event.sendToTool(sm.MANNEDTURRET_turretAssistor, "sv_addCharToDestroyQueue", char)
    end
end

function CannonRocket:sv_OnExplode(position)
    sm.physics.explode(position, 7, 5, 7, 15, "PropaneTank - ExplosionBig", self.shape)
end

function CannonRocket:sv_controlRocket(dt)
    local shape = self.shape
    local fwd = shape.at

    local controlData = sm.exists(self.seat) and self.seat.publicData or { rocketBoost = 0, rocketRoll = 0 }
    sm.physics.applyImpulse(shape, ((fwd * (20 + controlData.rocketBoost * 10)) - ( shape.velocity * 0.3 )) * shape.mass, true)

    local body = shape.body
    sm.physics.applyTorque(body, (-body.angularVelocity * 0.5 + fwd * controlData.rocketRoll) * shape.mass * dt, true)
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
    self.thrustEffect:setOffsetRotation(quat_right_90deg)
end

function CannonRocket:client_onUpdate(dt)
    local char = self.interactable:getSeatCharacter()
    if char then
        char:setNameTag("")
    end

    if not self.isLocal then return end

    local x, y = sm.localPlayer.getMouseDelta()
    if x ~= 0 or y ~= 0 then
        self.network:sendToServer("sv_updateDir", { x = x , y = y })
    end

    local rotation
    local fraction = (self.deathTick - sm.game.getServerTick()) / self.lifeTime
    if fraction > 0.98 then
        rotation = self.shape.worldRotation
    else
        rotation = nlerp(sm.camera.getRotation(), self.shape.worldRotation, dt * 15)
    end

    SetPlayerCamOverride({
        cameraState = 7,
        cameraFov = 45,
        cameraPosition = self.shape:getInterpolatedWorldPosition() + self.shape.velocity * dt + self.shape:getInterpolatedAt(),
        cameraRotation = rotation
    })

    sm.gui.setProgressFraction(fraction)
end

function CannonRocket:client_onClientDataUpdate(data)
    self.isLocal = data.owner == sm.localPlayer.getPlayer()
    self.interactable:setSubMeshVisible("lambert1", not self.isLocal)
    self.thrustEffect:start()

    if self.isLocal then
        self.deathTick = data.deathTick
    end
end