ControlHud = class()

function ControlHud:init(frames, dt)
    self.maxFrameCount = frames
    self.timeBetweenFrames = dt
    self.timeCounter = 0
    self.tick = 0

    self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/RocketControlHud.layout", false,
        {
            isHud = true,
            isInteractive = false,
            needsCursor = false,
            hidesHotbar = false,
            isOverlapped = false,
            backgroundAlpha = 0
        }
    )
    self:setHudFrame(self.tick)

    return self
end

function ControlHud:update(dt)
    self.timeCounter = self.timeCounter + dt
    if self.timeCounter >= self.timeBetweenFrames then
        self.timeCounter = 0
        self.tick = self.tick + 1
        self:setHudFrame(self.tick)
    end
end

function ControlHud:setHudFrame(frame)
    self.gui:setImage("overlay", ("$CONTENT_DATA/Gui/ControlHudImages/RocketControlHud%s.png"):format(frame%self.maxFrameCount))
end



function ControlHud:open()
    self.gui:open()
    sm.effect.playEffect("ControlHud - Open", sm.camera.getPosition())
end

function ControlHud:close()
    self.gui:close()
    sm.effect.playEffect("ControlHud - Close", sm.camera.getPosition())
end

function ControlHud:destroy()
    self.gui:destroy()
end

function ControlHud:isActive()
    return self.gui:isActive()
end