local binds, timers, reloads, events, dispatched = {}, {}, 0, {}, {}
local down = {}
hl = {
  dsp = { global = function(name) return name end },
  unbind = function(chord) binds[chord] = nil end,
  bind = function(chord, action, opts)
    local b = {enabled=true, action=action}
    function b:is_enabled() return self.enabled end
    function b:set_enabled(value) self.enabled=value end
    binds[chord]=b; return b
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
  dispatch = function(action) dispatched[#dispatched+1]=action end,
  is_key_down = function(key) return down[key] or false end,
}
local function attach(owner) assert(loadfile('runtime/bindings.lua'))(owner) end
local function state() return _G.__switch_magic_runtime_v1 end
binds.UNRELATED={enabled=true}
-- Stock Omarchy uses the opposite modifier order for this same key chord.
binds['SUPER + CTRL + TAB']={enabled=true, action='former-workspace'}
binds['CTRL + SUPER + TAB']={enabled=true, action='custom-workspace'}
attach('first')
assert(binds.UNRELATED.enabled)
assert(binds['SUPER + CTRL + TAB']==nil, 'remove the stock Former workspace action before opening the picker')
assert(binds['ALT + TAB'].action=='switch-magic:spaces')
assert(binds['ALT + SHIFT + TAB'].action=='switch-magic:monitor')
assert(binds['CTRL + ALT + TAB'].action=='switch-magic:all')
assert(binds['CTRL + SUPER + TAB'].action=='switch-magic:workspace-chord')
local first=state()
first.remaining=1; attach('first'); assert(first==state() and first.remaining==8 and #events==1)
events[1].callback(64, nil, 0); timers[#timers].callback(); assert(dispatched[1]=='switch-magic:commit')
down.Alt_R=true; events[1].callback(64,nil,0); timers[#timers].callback(); assert(#dispatched==1)
down.Alt_R=false
attach('second'); assert(not first.active and first.keys.removed and not first.watchdog.enabled and reloads==0)
first:stop(true); assert(reloads==0)
local second=state(); second.binds[1].enabled=nil
attach('second'); assert(state()~=second and not second.active)
local live=state(); for i=1,7 do live.watchdog.callback() end
assert(reloads==0); attach('second'); assert(live.remaining==8)
for i=1,8 do live.watchdog.callback() end
assert(reloads==1 and state()==nil and not live.active)
live:stop(true); assert(reloads==1)
local oldbind=hl.bind
hl.bind=function() error('simulated failure') end
assert(not pcall(attach,'broken')); assert(state()==nil and reloads==2)
hl.bind=oldbind
print('Runtime shortcuts: routes, release, renewal, ownership, reload, expiry and rollback passed.')
