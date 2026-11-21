local binds, timers, reloads, events, dispatched = {}, {}, 0, {}, {}
local down = {}
local currentSubmap, definingSubmap = "", ""
local layers = {}
local shellPid = 1234
local function normalize(chord) return (chord:gsub(' ', ''):lower()) end
local keybindMeta = {__tostring = function(b) return b.expired and 'HL.Keybind(expired)' or 'HL.Keybind(0x1)' end}
hl = {
  dsp = { global = function(name) return name end, submap = function(name) return {submap=name} end },
  get_current_submap = function() return currentSubmap end,
  get_layers = function() return layers end,
  define_submap = function(name, callback) definingSubmap=name; callback(); definingSubmap="" end,
  -- Like Hyprland, unbind matches the normalized chord in every submap, and
  -- the removed bind's Lua handle expires. Hyprland 0.56 crashes on any method
  -- of an expired handle; only tostring() is safe.
  unbind = function(chord)
    for name, b in pairs(binds) do
      if normalize(name:gsub('^[%w%-]+:', '')) == normalize(chord) then
        binds[name] = nil
        if type(b) == 'table' then b.expired = true end
      end
    end
  end,
  bind = function(chord, action, opts)
    local b = setmetatable({enabled=true, action=action}, keybindMeta)
    function b:is_enabled() assert(not self.expired, 'is_enabled() on an expired keybind crashes Hyprland'); return self.enabled end
    function b:set_enabled(value) assert(not self.expired, 'set_enabled() on an expired keybind crashes Hyprland'); self.enabled=value end
    binds[definingSubmap == "" and chord or definingSubmap..":"..chord]=b; return b
  end,
  on = function(name, callback)
    local e={callback=callback}; function e:remove() self.removed=true end
    events[#events+1]=e; return e
  end,
  timer = function(callback, opts)
    local t={callback=callback,opts=opts,enabled=true}
    function t:set_enabled(value) self.enabled=value end
    timers[#timers+1]=t; return t
  end,
  exec_cmd = function(cmd) assert(cmd=='hyprctl reload config-only'); reloads=reloads+1 end,
  dispatch = function(action)
    if type(action)=="table" then currentSubmap=action.submap=="reset" and "" or action.submap
    else dispatched[#dispatched+1]=action end
  end,
  is_key_down = function(key) return down[key] or false end,
}
local defaults = {
  {'ALT + TAB', 'workspace'}, {'ALT + SHIFT + TAB', 'monitor'},
  {'CTRL + ALT + TAB', 'all'}, {'ALT + SUPER + TAB', 'spaces'},
  {'ALT + GRAVE', 'app'},
}
local function attach(owner, assignments, pid) assert(loadfile('runtime/bindings.lua'))(owner, assignments or defaults, pid or shellPid) end
local function state() return _G.__switch_magic_runtime_v1 end
local function press(chord) binds[chord].action() end
local function release(key) state().keys.callback(key,nil,0); timers[#timers].callback() end
binds.UNRELATED={enabled=true}
binds['SUPER + ALT + TAB']={enabled=true, action='group-next'}
attach('first')
assert(binds.UNRELATED.enabled)
assert(binds['SUPER + ALT + TAB']==nil, 'remove alternate modifier order')
for _, assignment in ipairs(defaults) do
  press(assignment[1]); assert(dispatched[#dispatched]=='switch-magic:'..assignment[2])
end
local first=state()
first.remaining=1; attach('first'); assert(first==state() and first.remaining==8 and #events==3)
-- Only the picker layer temporarily owns keyboard routing.
first.layerOpened.callback({namespace='other'})
assert(currentSubmap=='')
for _, layer in ipairs({{namespace='switch-magic', pid=9999}, {namespace='switch-magic'}, {namespace='switch-magic', pid=-1}, {namespace='other', pid=shellPid}}) do
  first.layerOpened.callback(layer)
  assert(currentSubmap=='', 'only the shell process may enter the picker submap')
end
currentSubmap='user-mode'
first.layerOpened.callback({namespace='switch-magic', pid=shellPid})
assert(currentSubmap=='switch-magic-picker')
press('switch-magic-picker:ALT + SUPER + TAB')
assert(dispatched[#dispatched]=='switch-magic:spaces' and first.hold=='ALT')
press('switch-magic-picker:ALT + GRAVE')
assert(dispatched[#dispatched]=='switch-magic:app' and first.hold=='ALT')
press('switch-magic-picker:ALT + GRAVE')
assert(dispatched[#dispatched]=='switch-magic:app')
first.layerClosed.callback({namespace='other'})
assert(currentSubmap=='switch-magic-picker')
for _, layer in ipairs({{namespace='switch-magic', pid=9999}, {namespace='switch-magic'}, {namespace='switch-magic', pid=-1}}) do
  first.layerClosed.callback(layer)
  assert(currentSubmap=='switch-magic-picker', 'foreign or unknown clients must not leave the picker submap')
end
first.layerClosed.callback({namespace='switch-magic', pid=shellPid})
assert(currentSubmap=='user-mode')
currentSubmap=''
press('ALT + GRAVE')
release(64); assert(dispatched[#dispatched]=='switch-magic:commit')
press('ALT + TAB')
release(64); assert(dispatched[#dispatched]=='switch-magic:commit')
press('ALT + SHIFT + TAB')
local before=#dispatched
-- Releasing Shift must not commit an Alt-based chord.
state().keys.callback(50,nil,0); assert(#dispatched==before)
down.Alt_R=true; release(64); assert(#dispatched==before)
down.Alt_R=false; release(108); assert(dispatched[#dispatched]=='switch-magic:commit')
attach('second'); assert(not first.active and first.keys.removed and not first.watchdog.enabled and reloads==0)
first:stop(true); assert(reloads==0)
local second=state(); second.binds[1].enabled=nil
attach('second'); assert(state()~=second and not second.active)
-- Custom chords route to their configured scope and use the relevant modifier.
local custom={{'CTRL + SUPER + K','spaces'}}
binds['SUPER + CTRL + K']={enabled=true,action='saved-action'}
local old=state(); attach('second',custom)
assert(not old.active and #state().binds==1 and binds['SUPER + CTRL + K']==nil)
press('CTRL + SUPER + K'); assert(dispatched[#dispatched]=='switch-magic:spaces')
before=#dispatched
state().keys.callback(37,nil,0); assert(#dispatched==before)
down.Super_R=true; release(133); assert(#dispatched==before)
down.Super_R=false; release(134); assert(dispatched[#dispatched]=='switch-magic:commit')
attach('second',{{'CTRL + K','workspace'}})
press('CTRL + K'); release(37); assert(dispatched[#dispatched]=='switch-magic:commit')
attach('second',{{'SHIFT + F6','monitor'}})
press('SHIFT + F6'); release(50); assert(dispatched[#dispatched]=='switch-magic:commit')
attach('second',{}); assert(state():valid() and #state().binds==0)
attach('second')
local live=state(); live.layerOpened.callback({namespace='switch-magic', pid=shellPid}); for i=1,7 do live.watchdog.callback() end
assert(reloads==0); attach('second'); assert(live.remaining==8)
for i=1,8 do live.watchdog.callback() end
assert(reloads==1 and state()==nil and not live.active and currentSubmap=='')
assert(live.layerOpened.removed and live.layerClosed.removed)
for _, bind in ipairs(live.navigationBinds) do assert(not bind.enabled) end
live:stop(true); assert(reloads==1)
local oldbind=hl.bind
hl.bind=function() error('simulated failure') end
assert(not pcall(attach,'broken')); assert(state()==nil and reloads==2)
hl.bind=oldbind
-- Another client (e.g. hyprshell claiming Alt+Tab over IPC) unbinds a chord
-- while the runtime is live. No path may call a method on the expired handle.
attach('third'); local claimed=state()
hl.unbind('alt + Tab')
assert(tostring(claimed.binds[1])=='HL.Keybind(expired)' and tostring(claimed.navigationBinds[1])=='HL.Keybind(expired)')
assert(not claimed:valid(), 'an expired shortcut needs reinstalling')
-- The 2 s refresh reinstalls and takes the chord back.
attach('third'); assert(state()~=claimed and not claimed.active)
assert(binds['ALT + TAB'].enabled and binds['switch-magic-picker:ALT + TAB'].enabled)
press('ALT + TAB'); assert(dispatched[#dispatched]=='switch-magic:workspace')
-- Watchdog expiry with an expired handle.
local leased=state(); local reloadsBefore=reloads
hl.unbind('ALT + SHIFT + TAB')
for i=1,8 do leased.watchdog.callback() end
assert(not leased.active and state()==nil and reloads==reloadsBefore+1)
for _, bind in ipairs(leased.binds) do assert(bind.expired or not bind.enabled) end
-- Detach with an expired handle.
attach('third'); local detached=state()
hl.unbind('CTRL + ALT + TAB')
detached:stop(true); assert(not detached.active and state()==nil and reloads==reloadsBefore+2)
-- Expiring only a picker handle must reach the navigation-list validation;
-- the shared-chord unbind cases above return early on the desktop handle.
attach('picker-only'); local pickerOnly=state()
pickerOnly.navigationBinds[1].expired=true
assert(not pickerOnly:valid(), 'an expired picker-only shortcut needs reinstalling')
attach('picker-only')
assert(state()~=pickerOnly and not pickerOnly.active)
assert(binds['switch-magic-picker:ALT + TAB'].enabled)
state():stop(false)

-- Reattachment must not adopt an already-mapped layer owned by another client.
layers={{namespace='switch-magic', pid=9999, mapped=true}, {namespace='switch-magic', mapped=true}}
attach('startup')
assert(currentSubmap=='', 'startup discovery must reject foreign and unknown clients')
state():stop(false)
layers[#layers+1]={namespace='switch-magic', pid=shellPid, mapped=true}
attach('startup')
assert(currentSubmap=='switch-magic-picker', 'startup discovery must adopt the real picker')
local oldProcess=state()
attach('startup', nil, shellPid+1)
assert(state()~=oldProcess and not oldProcess.active and currentSubmap=='', 'renewal must not retain a different process identity')
state():stop(false)
for _, pid in ipairs({0, -1, 1.5, '1234', math.huge}) do
  assert(not pcall(attach, 'invalid-pid', nil, pid), 'reject invalid shell process IDs')
end
assert(not pcall(function() assert(loadfile('runtime/bindings.lua'))('missing-pid', defaults) end))
print('Picker bindings: process identity, foreign events, startup discovery and renewal passed.')
print('Runtime shortcuts: custom routes, modifiers, aliases, renewal, ownership, reload, expiry, rollback and foreign unbinds passed.')
