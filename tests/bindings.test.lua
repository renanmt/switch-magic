local binds, timers, reloads, events, dispatched = {}, {}, 0, {}, {}
local down = {}
local currentSubmap, definingSubmap = "", ""
local layers = {}
hl = {
  dsp = { global = function(name) return name end, submap = function(name) return {submap=name} end },
  get_current_submap = function() return currentSubmap end,
  get_layers = function() return layers end,
  define_submap = function(name, callback) definingSubmap=name; callback(); definingSubmap="" end,
  unbind = function(chord) binds[chord] = nil end,
  bind = function(chord, action, opts)
    local b = {enabled=true, action=action}
    function b:is_enabled() return self.enabled end
    function b:set_enabled(value) self.enabled=value end
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
}
local function attach(owner, assignments) assert(loadfile('runtime/bindings.lua'))(owner, assignments or defaults) end
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
currentSubmap='user-mode'
first.layerOpened.callback({namespace='switch-magic'})
assert(currentSubmap=='switch-magic-picker')
press('switch-magic-picker:ALT + SUPER + TAB')
assert(dispatched[#dispatched]=='switch-magic:spaces' and first.hold=='ALT')
first.layerClosed.callback({namespace='other'})
assert(currentSubmap=='switch-magic-picker')
first.layerClosed.callback({namespace='switch-magic'})
assert(currentSubmap=='user-mode')
currentSubmap=''
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
local live=state(); live.layerOpened.callback({namespace='switch-magic'}); for i=1,7 do live.watchdog.callback() end
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
print('Runtime shortcuts: custom routes, modifiers, aliases, renewal, ownership, reload, expiry and rollback passed.')
