local mapped, exists, focused = true, true, nil
local timers = {}
local listeners = {}
local raised = false
local shellPid = 1234
local foreignLayers = {}
hl = {
    on = function(name, callback)
        assert(name == 'layer.opened')
        local listener = {callback=callback, active=true}
        function listener:remove() self.active=false end
        listeners[#listeners+1]=listener
        return listener
    end,
    timer = function(callback)
        local timer = {callback=callback, enabled=true}
        function timer:set_enabled(value) self.enabled=value end
        timers[#timers+1]=timer
        return timer
    end,
    get_layers = function()
        local layers = {{namespace='switch-magic', pid=shellPid, mapped=mapped}}
        for _, layer in ipairs(foreignLayers) do layers[#layers+1]=layer end
        return layers
    end,
    get_window = function(selector) assert(selector=='address:0x123'); return exists end,
    dsp = {focus=function(spec) return spec.window end, window={bring_to_top=function() return "raise" end}},
    dispatch = function(target)
        if target == "raise" then
            assert(focused == "address:0x123", "focus the selected window before raising")
            raised = true
        else focused=target end
    end,
}
local function start() assert(loadfile('runtime/focus.lua'))('0x123', shellPid); return timers[#timers] end
local first=start()
for _=1,10 do first.callback() end
assert(not focused and first.enabled, 'wait through slow unmapping')
mapped=false; first.callback()
assert(focused=='address:0x123' and raised and not first.enabled)
focused=nil; exists=false
start().callback(); assert(not focused, 'closed windows must not be focused')
exists=true; mapped=true
local previous=start(); local current=start()
assert(not previous.enabled, 'new requests supersede pending focus')
for _=1,100 do current.callback() end
assert(not focused and not current.enabled, 'bound the wait when the picker remains open')
assert(not pcall(function() assert(loadfile('runtime/focus.lua'))('invalid') end))

local function openLayer(namespace, pid)
    for _, listener in ipairs(listeners) do
        if listener.active then listener.callback({namespace=namespace, pid=pid}) end
    end
end
local function tick(timer)
    if timer.enabled then timer.callback() end
end
raised=false
local pending=start()
openLayer('unrelated-panel')
assert(pending.enabled, 'unrelated layers must not cancel a selection')
openLayer('switch-magic', 9999)
openLayer('switch-magic')
openLayer('switch-magic', -1)
openLayer('unrelated-panel', shellPid)
assert(pending.enabled, 'foreign or unknown clients must not cancel pending focus')
openLayer('switch-magic', shellPid) -- Reopen the picker before the old layer finishes unmapping.
mapped=false -- Escape cancels the new picker without another window request.
tick(pending)
assert(not focused and not raised, 'reopening then cancelling must not activate the old selection')
assert(not pending.enabled, 'a new picker session must invalidate pending focus immediately')
pending.callback() -- Even a callback queued before cancellation must be harmless.
assert(not focused, 'invalidated callbacks must not focus a window')

mapped=true
pending=start()
openLayer('switch-magic', shellPid) -- Open Spaces instead of accepting another window.
mapped=false
focused='workspace:2'
tick(pending)
assert(focused=='workspace:2', 'the old window must not override a workspace selection')
focused=nil
foreignLayers={{namespace='switch-magic', pid=9999, mapped=true}, {namespace='switch-magic', mapped=true}, {namespace='unrelated-panel', pid=shellPid, mapped=true}}
start().callback()
assert(focused=='address:0x123', 'foreign layers must not block focus after the real picker unmaps')
for _, pid in ipairs({0, -1, 1.5, '1234', math.huge}) do
    assert(not pcall(function() assert(loadfile('runtime/focus.lua'))('0x123', pid) end), 'reject invalid shell process IDs')
end
assert(not pcall(function() assert(loadfile('runtime/focus.lua'))('0x123') end))
for _, listener in ipairs(listeners) do
    assert(not listener.active, 'completed, superseded and cancelled requests must release listeners')
end
print('Focus: asynchronous unmap, closed windows, supersession, timeout and picker-session invalidation passed.')
