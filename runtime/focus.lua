-- Layer unmapping is asynchronous. Wait for the compositor to release the
-- picker's exclusive keyboard focus instead of guessing a frame delay.
local address = ...
assert(type(address) == 'string' and address:match('^0x%x+$'), 'Invalid window address')
local slot = '__switch_magic_focus_v1'
local previous = _G[slot]
if previous then previous:set_enabled(false) end
local attempts = 0
local timer
timer = hl.timer(function()
    attempts = attempts + 1
    local mapped = false
    for _, layer in ipairs(hl.get_layers()) do
        if layer.namespace == 'switch-magic' and layer.mapped then mapped = true; break end
    end
    if mapped and attempts < 100 then return end
    timer:set_enabled(false)
    if _G[slot] == timer then _G[slot] = nil end
    if not mapped and hl.get_window('address:' .. address) then
        hl.dispatch(hl.dsp.focus({window = 'address:' .. address}))
    end
end, {timeout = 10, type = 'repeat'})
_G[slot] = timer
