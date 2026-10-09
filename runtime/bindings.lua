-- Runtime-only shortcut lease. QML supplies an owner and validated assignments.
-- No configuration is written. Detaching restores the saved Hyprland config.
local owner, assignments = ...
assert(type(owner) == 'string' and owner:match('^[%w%-]+$'), 'Invalid Switch Magic owner')
assert(type(assignments) == 'table', 'Missing shortcut assignments')
local scopes = {workspace=true, monitor=true, all=true, spaces=true}
local modifierKeys = {
    ALT = {'Alt_L', 'Alt_R', 64, 108},
    CTRL = {'Control_L', 'Control_R', 37, 105},
    SHIFT = {'Shift_L', 'Shift_R', 50, 62},
    SUPER = {'Super_L', 'Super_R', 133, 134},
}
local signature, seen = {}, {}
for _, assignment in ipairs(assignments) do
    assert(type(assignment[1]) == 'string' and assignment[1]:match('^[A-Z0-9_ +]+$') and scopes[assignment[2]], 'Invalid shortcut assignment')
    assert(not seen[assignment[1]] and not seen[assignment[2]], 'Duplicate shortcut assignment')
    seen[assignment[1]], seen[assignment[2]] = true, true
    signature[#signature + 1] = assignment[1] .. ':' .. assignment[2]
end
signature = table.concat(signature, '|')
local slot = '__switch_magic_runtime_v1'
local prior = _G[slot]
if prior and prior.owner == owner and prior.signature == signature and prior:valid() then
    prior.remaining = 8
    return
end
if prior then prior:stop(false) end
local pickerSubmap = "switch-magic-picker"
local state = { navigationBinds = {}, actions = {}, owner = owner, signature = signature, remaining = 8, binds = {}, active = true }
_G[slot] = state
function state:valid()
    if not self.active or #self.binds ~= #assignments then return false end
    for _, bind in ipairs(self.binds) do
        if bind:is_enabled() ~= true then return false end
    end
    for _, bind in ipairs(self.navigationBinds) do
        if bind:is_enabled() ~= true then return false end
    end
    return true
end
function state:stop(restore)
    if not self.active then return end
    self.active = false
    if self.watchdog then self.watchdog:set_enabled(false) end
    if self.keys then self.keys:remove() end
    if self.layerOpened then self.layerOpened:remove() end
    if self.layerClosed then self.layerClosed:remove() end
    self:leavePicker()
    for _, bind in ipairs(self.navigationBinds) do bind:set_enabled(false) end
    for _, bind in ipairs(self.binds) do bind:set_enabled(false) end
    if _G[slot] == self then _G[slot] = nil end
    if restore then hl.exec_cmd('hyprctl reload config-only') end
end
function state:enterPicker()
    if hl.get_current_submap() == pickerSubmap then return end
    self.previousSubmap = hl.get_current_submap()
    hl.dispatch(hl.dsp.submap(pickerSubmap))
end
function state:leavePicker()
    if hl.get_current_submap() == pickerSubmap then
        hl.dispatch(hl.dsp.submap(self.previousSubmap ~= "" and self.previousSubmap or "reset"))
    end
    self.previousSubmap = nil
end
local function emit(name)
    if state.active then hl.dispatch(hl.dsp.global('switch-magic:' .. name)) end
end
-- Lua unbind matches modifier spelling/order. Remove every ordering of the
-- assigned chord so saved actions cannot fire alongside the picker.
local function unbindPermutations(modifiers, key, prefix)
    if #modifiers == 0 then hl.unbind(prefix .. key); return end
    for i, modifier in ipairs(modifiers) do
        local rest = {}
        for j, candidate in ipairs(modifiers) do if i ~= j then rest[#rest + 1] = candidate end end
        unbindPermutations(rest, key, prefix .. modifier .. ' + ')
    end
end
local ok, err = pcall(function()
    for _, assignment in ipairs(assignments) do
        local parts = {}
        for part in assignment[1]:gmatch('[A-Z0-9_]+') do parts[#parts + 1] = part end
        local key = table.remove(parts)
        assert(#parts > 0, 'Shortcuts need a modifier')
        local modifiers = {}
        for _, modifier in ipairs(parts) do
            assert(modifierKeys[modifier] and not modifiers[modifier], 'Invalid shortcut modifier')
            modifiers[modifier] = true
        end
        -- Preserve Alt switching: releasing Shift in Alt+Shift+Tab does not
        -- commit. For other chords hold Super, then Ctrl, then Shift.
        local hold = modifiers.ALT and 'ALT' or modifiers.SUPER and 'SUPER' or modifiers.CTRL and 'CTRL' or 'SHIFT'
        unbindPermutations(parts, key, '')
        local action = function()
            state.hold = hold
            emit(assignment[2])
        end
        state.actions[assignment[1]] = action
        state.binds[#state.binds + 1] = hl.bind(assignment[1], action, {description = 'Switch Magic: ' .. assignment[2], repeating = true})
    end
    -- Isolate the picker from desktop modifier+arrow actions. Unbound keys
    -- reach QML normally; shortcut chords still cycle or change scope.
    hl.define_submap(pickerSubmap, function()
        for _, assignment in ipairs(assignments) do
            state.navigationBinds[#state.navigationBinds + 1] = hl.bind(assignment[1], state.actions[assignment[1]], {repeating = true})
        end
    end)
    state.layerOpened = hl.on('layer.opened', function(layer)
        if layer.namespace == 'switch-magic' then state:enterPicker() end
    end)
    state.layerClosed = hl.on('layer.closed', function(layer)
        if layer.namespace == 'switch-magic' then state:leavePicker() end
    end)
    for _, layer in ipairs(hl.get_layers()) do
        if layer.namespace == 'switch-magic' and layer.mapped then state:enterPicker(); break end
    end
    state.keys = hl.on('input.keyboard.key', function(keycode, _, value)
        local hold = state.hold
        local keys = hold and modifierKeys[hold]
        if not state.active or value ~= 0 or not keys or (keycode ~= keys[3] and keycode ~= keys[4]) then return end
        hl.timer(function()
            if state.hold == hold and not hl.is_key_down(keys[1]) and not hl.is_key_down(keys[2]) then
                state.hold = nil
                emit('commit')
            end
        end, {timeout = 1, type = 'oneshot'})
    end)
    state.watchdog = hl.timer(function()
        state.remaining = state.remaining - 1
        if state.remaining <= 0 then state:stop(true) end
    end, {timeout = 1000, type = 'repeat'})
end)
if not ok then state:stop(true); error(err) end
