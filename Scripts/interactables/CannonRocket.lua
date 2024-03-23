---@class CannonRocket : ShapeClass
CannonRocket = class()
CannonRocket.lifeTime = 15 * 40

function CannonRocket:server_onCreate()
    if self.storage:load() then
        self.shape:destroyShape()
        return
    end

    local publicData = self.interactable.publicData
    self.isPrimed = publicData ~= nil

    if self.isPrimed then
        self.thrustActivate = 0
        self.sv_deathTick = sm.game.getServerTick() + self.lifeTime

        self.seat = self.interactable.publicData.seat

        self.network:setClientData({ owner = publicData.owner, deathTick = self.sv_deathTick })
    end
end

function CannonRocket:server_onUnload()
    self.storage:save(true)
    self:sv_explode()
end

function CannonRocket:server_onProjectile()
    if self.isPrimed then
        self:sv_explode()
    end
end

function CannonRocket:server_onMelee()
    if self.isPrimed then
        self:sv_explode()
    end
end

function CannonRocket:server_onExplosion()
    if self.isPrimed then
        self:sv_explode()
    end
end

function CannonRocket:server_onCollision(other, position, selfPointVelocity, otherPointVelocity, normal)
    if not self.isPrimed then return end

    self:sv_explode(position)
end

function CannonRocket:server_onFixedUpdate(dt)
    if not self.isPrimed then return end

    local pos = self.shape.worldPosition
    local hit, result = sm.physics.spherecast(pos, pos + self.shape.at * 2, 0.1, self.shape)
    if hit then
        self:sv_explode(pos)
        return
    end

    self:sv_controlRocket(dt)

    if self.sv_deathTick - sm.game.getServerTick() <= 0 then
        self:sv_explode(pos)
    end
end

function CannonRocket:sv_explode(position)
    sm.event.sendToHarvestable(self.seat, "sv_onRocketExplode", position == nil)

    sm.physics.explode( position or self.shape.worldPosition, 10, 10, 12, 25, "PropaneTank - ExplosionBig", self.shape )
    self.shape:destroyShape()
end

function CannonRocket:sv_controlRocket(dt)
    local shape = self.shape
    local fwd = shape.at

    self.thrustActivate = math.min(self.thrustActivate + dt, 1)
    local wrampUp = sm.util.easing("easeInSine", self.thrustActivate) * 10
    local controlData = self.seat.publicData
    sm.physics.applyImpulse(shape, ((fwd * wrampUp * 2) - ( shape.velocity * 0.3 ) + fwd * controlData.rocketBoost * wrampUp) * shape.mass, true)

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
    self.thrustEffect:setOffsetRotation(sm.quat.angleAxis(math.rad(90), vec3_right))
end

function CannonRocket:client_onDestroy()
    if self.isLocal then
        self.hud:close()
        self.hud:destroy()
    end
end

function CannonRocket:client_onUpdate(dt)
    if not self.isLocal then return end

    local x, y = sm.localPlayer.getMouseDelta()
    if x ~= 0 or y ~= 0 then
        self.network:sendToServer("sv_updateDir", { x = x , y = y })
    end

    sm.camera.setPosition(self.shape:getInterpolatedWorldPosition() + self.shape.velocity * dt)
    sm.camera.setRotation(nlerp(sm.camera.getRotation(), self.shape.worldRotation, dt * 15))

    sm.gui.setProgressFraction((self.deathTick - sm.game.getCurrentTick()) / self.lifeTime)
    --[[sm.gui.setInteractionText(
        sm.gui.getKeyBinding("Forward", true).."Boost\t",
        sm.gui.getKeyBinding("Backward", true).."Slow Down\t",
        sm.gui.getKeyBinding("StrafeLeft", true).."Roll Left\t",
        sm.gui.getKeyBinding("StrafeRight", true).."Roll Right\t",
        ""
    )
    sm.gui.setInteractionText("<p textShadow='false' bg='gui_keybinds_bg_orange' color='#66440C' spacing='9'>Mouse</p>Yaw/Pitch", "")]]
end

function CannonRocket:client_onClientDataUpdate(data)
    self.isLocal = data.owner == sm.localPlayer.getPlayer()
    self.interactable:setSubMeshVisible("lambert1", not self.isLocal)
    self.thrustEffect:start()

    if self.isLocal then
        self.deathTick = data.deathTick

        self.hud = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/RocketControlHud.layout", false,
            {
                isHud = true,
                isInteractive = false,
                needsCursor = false,
                hidesHotbar = false,
                isOverlapped = false,
                backgroundAlpha = 0
            }
        )
        --self.hud:playEffect("overlay", "Gui - PlayButtonShine", true)
        self.hud:open()
    end
end