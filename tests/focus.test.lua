local mapped, exists, focused = true, true, nil
local timers = {}
local raised = false
hl = {
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
print('Focus: asynchronous unmap, closed windows, supersession and timeout passed.')
