-- Layer unmapping is asynchronous. Wait for the compositor to release the
-- picker's exclusive keyboard focus instead of guessing a frame delay.
local address = ...
assert(type(address) == 'string' and address:match('^0x%x+$'), 'Invalid window address')
local slot = '__switch_magic_focus_v1'
local previous = _G[slot]
if previous then previous:stop() end
local request = {}
function request:stop()
    if _G[slot] ~= self then return end
    if self.timer then self.timer:set_enabled(false) end
    if self.opened then self.opened:remove() end
    if _G[slot] == self then _G[slot] = nil end
end
_G[slot] = request
-- A new picker session supersedes the accepted selection even when it ends
-- with Escape, settings dismissal or a workspace selection rather than a
-- second window request. Cancel here, where the pending timer is owned.
request.opened = hl.on('layer.opened', function(layer)
    if layer.namespace == 'switch-magic' then request:stop() end
end)
local attempts = 0
request.timer = hl.timer(function()
    if _G[slot] ~= request then return end
    attempts = attempts + 1
    local mapped = false
    for _, layer in ipairs(hl.get_layers()) do
        if layer.namespace == 'switch-magic' and layer.mapped then mapped = true; break end
    end
    if mapped and attempts < 100 then return end
    request:stop()
    if not mapped and hl.get_window('address:' .. address) then
        hl.dispatch(hl.dsp.focus({window = 'address:' .. address}))
        -- Focusing a floating window does not raise it above overlapping
        -- windows. Match Omarchy's own Alt+Tab reveal behavior.
        hl.dispatch(hl.dsp.window.bring_to_top())
    end
end, {timeout = 10, type = 'repeat'})
