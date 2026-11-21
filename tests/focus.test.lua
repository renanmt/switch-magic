local mapped, exists, focused = true, true, nil
local timers = {}
local listeners = {}
local raised = false
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
    get_layers = function() return {{namespace='switch-magic', mapped=mapped}} end,
    get_window = function(selector) assert(selector=='address:0x123'); return exists end,
    dsp = {focus=function(spec) return spec.window end, window={bring_to_top=function() return "raise" end}},
    dispatch = function(target)
        if target == "raise" then
            assert(focused == "address:0x123", "focus the selected window before raising")
            raised = true
        else focused=target end
    end,
}
local function start() assert(loadfile('runtime/focus.lua'))('0x123'); return timers[#timers] end
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

local function openLayer(namespace)
    for _, listener in ipairs(listeners) do
        if listener.active then listener.callback({namespace=namespace}) end
    end
end
local function tick(timer)
    if timer.enabled then timer.callback() end
end
raised=false
local pending=start()
openLayer('unrelated-panel')
assert(pending.enabled, 'unrelated layers must not cancel a selection')
openLayer('switch-magic') -- Reopen the picker before the old layer finishes unmapping.
mapped=false -- Escape cancels the new picker without another window request.
tick(pending)
assert(not focused and not raised, 'reopening then cancelling must not activate the old selection')
assert(not pending.enabled, 'a new picker session must invalidate pending focus immediately')
pending.callback() -- Even a callback queued before cancellation must be harmless.
assert(not focused, 'invalidated callbacks must not focus a window')

mapped=true
pending=start()
openLayer('switch-magic') -- Open Spaces instead of accepting another window.
mapped=false
focused='workspace:2'
tick(pending)
assert(focused=='workspace:2', 'the old window must not override a workspace selection')
focused=nil
start().callback()
assert(focused=='address:0x123', 'a new selection must still focus normally after cancellation')
for _, listener in ipairs(listeners) do
    assert(not listener.active, 'completed, superseded and cancelled requests must release listeners')
end
print('Focus: asynchronous unmap, closed windows, supersession, timeout and picker-session invalidation passed.')
