dofile "$GAME_DATA/Scripts/game/Explosive.lua"
dofile "$CHALLENGE_DATA/Scripts/game/Ball.lua"

---@class CannonBall : ShapeClass
CannonBall = class(Explosive)
--CannonBall.fireDelay = 4 * 40

function CannonBall:server_onCreate()
    Explosive.server_onCreate(self)
end

--[[function CannonBall:server_onCollision(other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal)
    if type(other) == "Character" and other:isPlayer() then
        return
    end


    if self.alive and self.shape.body.destructable then
        local vel = math.min(selfPointVelocity:length() * 0.25, 5)
        sm.physics.explode(self.shape.worldPosition, vel, vel, vel * 1.5, vel * 2.5, nil, self.shape)
        sm.physics.applyImpulse(self.shape, collisionNormal * 2 * self.shape.mass, true)

        if not self.counting then
            self:server_startCountdown()
            self.network:sendToClients("client_hitActivation", collisionPosition)
        end
    end
end]]

function CannonBall:client_onCreate()
    Explosive.client_onCreate(self)
    Ball.client_onCreate(self)
end

function CannonBall:client_onUpdate(dt)
    Explosive.client_onUpdate(self, dt)
    Ball.client_onUpdate(self, dt)
end
