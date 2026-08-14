---@class TurretInput : ToolClass
TurretInput = class()


function BindOnTurretLMB(obj, callback)
    table.insert(g_turretInput.callbacks[1], { obj, callback })
end

function BindOnTurretRMB(obj, callback)
    table.insert(g_turretInput.callbacks[2], { obj, callback })
end

function BindOnTurretF(obj, callback)
    table.insert(g_turretInput.callbacks[3], { obj, callback })
end


local function unbind(callbacks, obj)
    local index = -1
    for k, v in pairs(callbacks) do
        if v[1] == obj then
            index = k
            break
        end
    end

    if index == -1 then
        sm.log.error("TURRETINPUT: EVENT SUBSCRIBER NOT FOUND")
        return
    end

    table.remove(callbacks, index)
end

function UnBindOnTurretLMB(obj)
    unbind(g_turretInput.callbacks[1], obj)
end

function UnBindOnTurretRMB(obj)
    unbind(g_turretInput.callbacks[2], obj)
end

function UnBindOnTurretF(obj)
    unbind(g_turretInput.callbacks[3], obj)
end

function InvokeCallbacks(callbacks, value)
    for k, v in pairs(callbacks) do
        if sm.exists(v[1]) then
            SendEventToObject(v[1], v[2], value)
        else
            sm.log.error("TURRETINPUT: CALLBACK RECEIVER DOESNT EXIST", v[1])
        end
    end
end


function TurretInput:client_onCreate()
    if not self.tool:isLocal() then return end

    g_turretInput = self

    self.lmb = 0
    self.rmb = 0
    self.f = false

    self.callbacks = { {}, {}, {} }
end

function TurretInput:client_onEquippedUpdate(lmb, rmb, f)
    if self.lmb ~= lmb then
        InvokeCallbacks(self.callbacks[1], lmb)
    end

    if self.rmb ~= rmb then
        InvokeCallbacks(self.callbacks[2], rmb)
    end

    if self.f ~= f then
        InvokeCallbacks(self.callbacks[3], f)
    end

    return true, true
end