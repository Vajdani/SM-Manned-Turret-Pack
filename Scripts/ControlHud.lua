ControlHud = class()

local maxFrameCount = 40
local animationDt = 1/maxFrameCount
local function GetAnimationFrame(index)
    return ("$CONTENT_DATA/Gui/ControlHudImages/RocketControlHud%s.png"):format(index%maxFrameCount)
end

function ControlHud:init()
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
    if self.timeCounter >= animationDt then
        self.timeCounter = 0
        self.tick = self.tick + 1
        self:setHudFrame(self.tick)
        print("update gui", self.tick, self.tick%maxFrameCount)
    end
end

function ControlHud:setHudFrame(frame)
    self.gui:setImage("overlay", GetAnimationFrame(frame))
end



function ControlHud:open()
    self.gui:open()
end

function ControlHud:close()
    self.gui:close()
end

function ControlHud:destroy()
    self.gui:destroy()
end

function ControlHud:isActive()
    return self.gui:isActive()
end