-- Runtime-only shortcut lease. The QML service passes its instance token as ...
-- No configuration is written. Detaching restores the saved Hyprland config.
local owner = ...
assert(type(owner) == 'string' and owner:match('^[%w%-]+$'), 'Invalid Switch Magic owner')
local slot = '__switch_magic_runtime_v1'
local prior = _G[slot]
if prior and prior.owner == owner and prior:valid() then
    prior.remaining = 8
    return
end
if prior then prior:stop(false) end
local state = { owner = owner, remaining = 8, binds = {}, active = true }
_G[slot] = state
function state:valid()
    if not self.active or #self.binds ~= 4 then return false end
    for _, bind in ipairs(self.binds) do
        if bind:is_enabled() ~= true then return false end
    end
    return true
end
function state:stop(restore)
    if not self.active then return end
    self.active = false
    if self.watchdog then self.watchdog:set_enabled(false) end
    if self.keys then self.keys:remove() end
    -- Disable immediately; the config reload removes all temporary callbacks.
    for _, bind in ipairs(self.binds) do bind:set_enabled(false) end
    if _G[slot] == self then _G[slot] = nil end
    if restore then hl.exec_cmd('hyprctl reload config-only') end
end
local function emit(name)
    if state.active then hl.dispatch(hl.dsp.global('switch-magic:' .. name)) end
end
local ok, err = pcall(function()
    -- Omarchy spells its Former workspace chord in this order. Lua unbind
    -- matches the chord spelling, so remove it as well as our own spelling.
    hl.unbind('SUPER + CTRL + TAB')
    for _, chord in ipairs({
        {'ALT + TAB', 'spaces', 'Switch Magic: workspace overview'},
        {'ALT + SHIFT + TAB', 'monitor', 'Switch Magic: current monitor'},
        {'CTRL + ALT + TAB', 'all', 'Switch Magic: all workspaces'},
        {'CTRL + SUPER + TAB', 'workspace-chord', 'Switch Magic: current workspace'},
    }) do
        hl.unbind(chord[1])
        state.binds[#state.binds + 1] = hl.bind(chord[1], hl.dsp.global('switch-magic:' .. chord[2]), {description = chord[3], repeating = true})
    end
    state.keys = hl.on('input.keyboard.key', function(keycode, _, value)
        if not state.active or value ~= 0 or (keycode ~= 64 and keycode ~= 108) then return end
        hl.timer(function()
            if not hl.is_key_down('Alt_L') and not hl.is_key_down('Alt_R') then emit('commit') end
        end, {timeout = 1, type = 'oneshot'})
    end)
    state.watchdog = hl.timer(function()
        state.remaining = state.remaining - 1
        if state.remaining <= 0 then state:stop(true) end
    end, {timeout = 1000, type = 'repeat'})
end)
if not ok then state:stop(true); error(err) end
