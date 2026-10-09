const test = require('node:test');
const assert = require('node:assert/strict');
const M = require('../lib/Model.js');
const defaults = require('../defaults.json');
const fields = require('../lib/ViewFields.js').groups;
const valid = config => M.validate(config, defaults, fields);
const win = (address, workspaceId, monitorId, rank, extra = {}) => ({address, workspaceId, monitorId, rank, mapped:true, special:false, ...extra});
const windows = [win('a', 1, 0, 1), win('b', 2, 0, 0), win('c', 3, 1, 2), win('d', -1, 0, 3, {special:true}), win('e', 1, 0, 4, {hidden:true}), win('f', 1, 0, 5, {mapped:false})];
test('three scopes filter by workspace / monitor / all, ordered by MRU', () => {
    const ctx = {workspaceId:1, monitorId:0};
    assert.deepEqual(M.selectWindows(windows,'workspace',ctx,false).map(w=>w.address), ['a']);
    assert.deepEqual(M.selectWindows(windows,'monitor',ctx,false).map(w=>w.address), ['b','a']);
    assert.deepEqual(M.selectWindows(windows,'all',ctx,false).map(w=>w.address), ['b','a','c']);
    assert.deepEqual(M.selectWindows(windows,'all',ctx,true).map(w=>w.address), ['b','a','c','d']);
});
test('active special workspace and pinned windows remain reachable', () => {
    assert.deepEqual(M.selectWindows(windows,'workspace',{workspaceId:-1,monitorId:0},false).map(w=>w.address), ['d']);
    assert.equal(M.selectWindows([win('pin',9,0,0,{pinned:true})],'workspace',{workspaceId:1,monitorId:0},false).length,1);
});
test('initial selection, empty and single-window lists and negative wrapping', () => {
    assert.equal(M.initialIndex(windows,'a'),1);
    assert.equal(M.initialIndex([windows[0]],'a'),0);
    assert.equal(M.initialIndex([],''),0);
    assert.equal(M.wrap(-1,6),5);
});
test('closing selected or preceding windows preserves useful selection', () => {
    assert.equal(M.remaining(windows,['b','c'],1).index,0);
    assert.equal(M.remaining(windows,['a','c'],1).windows[1].address,'c');
    assert.deepEqual(M.remaining(windows,[],1),{windows:[],index:0});
});
test('settings merge retains defaults and rejects missing views and immutable edits', () => {
    assert.deepEqual(valid(defaults),[]);
    const conf=M.merge(defaults,{profiles:{all:{preview:'icon'}}});
    assert.equal(conf.profiles.all.view,'grid');
    assert.equal(defaults.profiles.all.preview,'hybrid');
    assert.deepEqual(valid(conf),[]);
    assert.ok(valid(M.merge(defaults,{profiles:{all:{view:'oops'}}})).length);
    const altered=M.clone(defaults); altered.views[0].geometry.cardWidth=600;
    assert.match(valid(altered).join(' '),/read-only/);
    assert.equal(M.merge({},JSON.parse('{"__proto__":{"polluted":true}}')).polluted,undefined);
});
test('all four layouts keep the selected card visible for every count and screen size', () => {
    for(const name of ['list','grid','carousel','fan']) for(const count of [1,2,3,6,7,31]) for(const size of [[2460,1140],[980,1620],[540,280]]) {
        const l=M.view(defaults,name).geometry, m=M.metrics(name,l,count,...size);
        assert.ok(m.width*m.scale<=size[0]+1);
        assert.ok(m.height*m.scale<=size[1]+1);
        for(let selected=0; selected<count; selected++) {
            const places=Array.from({length:count},(_,i)=>M.placement(name,l,i,selected,count,m));
            assert.equal(places[selected].visible,true,`${name} ${count} ${selected}`);
            assert.equal(places.filter(p=>p.visible).length, ['fan','carousel'].includes(name) ? Math.min(m.capacity,count) : Math.min(m.capacity,count-Math.floor(selected/m.capacity)*m.capacity));
            for(const p of places) assert.ok(Number.isFinite(p.x)&&Number.isFinite(p.y)&&p.width>0&&p.height>0);
        }
    }
});

test('duplicate, rename, delete and profile reassignment preserve the originals', () => {
    const original=JSON.stringify(defaults);
    const created=M.duplicate(defaults,'fan','Midnight cards');
    assert.equal(created.id,'custom-midnight-cards');
    let config=M.changeView(created.config,created.id,'card.titleSize',20);
    config=M.changeView(config,created.id,'animation.duration',350);
    assert.equal(M.view(config,created.id).card.titleSize,20);
    assert.equal(M.view(config,'fan').card.titleSize,14);
    config=M.changeView(config,created.id,'name','My midnight cards');
    assert.equal(M.view(config,created.id).name,'My midnight cards');
    config.profiles.workspace.view=created.id;
    assert.deepEqual(valid(config),[]);
    const deleted=M.removeView(config,created.id);
    assert.equal(deleted.profiles.workspace.view,'fan');
    assert.equal(M.view(deleted,created.id),null);
    assert.equal(JSON.stringify(defaults),original);
    for(const id of ['list','grid','carousel','fan']) {
        assert.throws(()=>M.changeView(config,id,'card.radius',0),/read-only/);
        assert.throws(()=>M.removeView(config,id),/cannot be deleted/);
    }
});
test('names and IDs cannot shadow templates or collide with each other', () => {
    assert.throws(()=>M.duplicate(defaults,'list','List'),/already/);
    assert.throws(()=>M.duplicate(defaults,'list','  '),/name/);
    let a=M.duplicate(defaults,'list','A B');
    const b=M.duplicate(a.config,'grid','A-B');
    assert.notEqual(a.id,b.id);
    assert.throws(()=>M.changeView(b.config,b.id,'name','a b'),/already/);
    assert.throws(()=>M.changeView(b.config,b.id,'id','list'),/cannot/);
    assert.throws(()=>M.changeView(b.config,b.id,'__proto__.oops',1),/Invalid/);
});
test('every editable field is present in templates and invalid values are rejected', () => {
    const a=M.duplicate(defaults,'fan','Example');
    for(const group of fields) for(const f of group.fields) {
        for(const view of defaults.views) assert.notEqual(M.get(view,f.path),undefined,f.path);
        const bad=M.changeView(a.config,a.id,f.path, f.type==='boolean' ? 'true' : f.type==='enum' ? 'unknown' : f.type==='color' ? 'not-color' : f.type==='text' ? '' : f.max+1);
        assert.ok(valid(bad).length, f.path);
    }
});
test('v1 migration preserves shortcut choices and differing styles in custom copies', () => {
    const legacy={version:1,appearance:{radius:24},profiles:{workspace:{layout:'fan',preview:'live',animation:{duration:190}},monitor:{layout:'fan',preview:'snapshot',animation:{duration:240}}},layouts:{fan:{cardWidth:400}}};
    const migrated=M.normalize(defaults,legacy);
    const current=M.view(migrated,migrated.profiles.workspace.view);
    assert.equal(current.engine,'fan');
    assert.equal(current.card.radius,24);
    assert.equal(current.geometry.cardWidth,400);
    assert.equal(current.animation.duration,190);
    assert.equal(migrated.profiles.workspace.preview,'live');
    assert.deepEqual(valid(migrated),[]);
    assert.deepEqual(migrated.views,defaults.views);
    assert.deepEqual(M.normalize(defaults,M.persisted(migrated)),migrated);
});
test('v2 rejects built-in overrides and restores custom views across reload', () => {
    const created=M.duplicate(defaults,'grid','Gallery');
    created.config.profiles.all.view=created.id;
    assert.deepEqual(M.normalize(defaults,M.persisted(created.config)),created.config);
    const modified=M.clone(defaults.views);modified[0].name='Fake';
    assert.throws(()=>M.normalize(defaults,{version:2,views:modified}),/read-only/);
    assert.throws(()=>M.normalize(defaults,{version:99}),/version/);
});

test('changing a copied list or fan to grid starts with multiple columns and rows', () => {
    for (const engine of ['list', 'fan', 'carousel']) {
        const copy=M.duplicate(defaults,engine,'Grid from '+engine);
        const changed=M.changeView(copy.config,copy.id,'engine','grid');
        const v=M.view(changed,copy.id);
        assert.equal(v.geometry.columns,3);
        assert.equal(v.geometry.rows,2);
        assert.equal(v.geometry.cardWidth,M.view(copy.config,copy.id).geometry.cardWidth);
        assert.deepEqual(valid(changed),[]);
        const m=M.metrics('grid',v.geometry,8,2460,1140);
        assert.ok(m.columns>1);
        const first=M.placement('grid',v.geometry,0,0,8,m);
        const second=M.placement('grid',v.geometry,1,0,8,m);
        assert.ok(second.x>first.x);assert.equal(second.y,first.y);
    }
});
test('grid caps rows and columns using actual tile dimensions and paginates overflow', () => {
    const geometry={...M.view(defaults,'grid').geometry,columns:8,rows:8,cardWidth:500,cardHeight:250,gap:20,maxVisible:1};
    assert.deepEqual(M.gridLimits(geometry,1600,810),{columns:3,rows:3});
    assert.deepEqual(M.gridLimits(geometry,1000,540),{columns:1,rows:2});
    assert.deepEqual(M.gridLimits(geometry,500,250),{columns:1,rows:1});
    assert.deepEqual(M.gridLimits({...geometry,columns:2,rows:1},1600,810),{columns:2,rows:1});
    const m=M.metrics('grid',geometry,23,1600,810);
    assert.equal(m.capacity,9,'grid capacity comes from rows × columns, not hidden maxVisible');
    assert.equal(m.scale,1,'fitting columns must not rely on shrinking a larger grid');
    for(let selected=0;selected<23;selected++) {
        const places=Array.from({length:23},(_,i)=>M.placement('grid',geometry,i,selected,23,m));
        assert.ok(places[selected].visible);
        for(const p of places.filter(p=>p.visible)) {
            assert.ok(p.x>=0 && p.x+p.width<=1600);
            assert.ok(p.y>=0 && p.y+p.height<=810);
        }
    }
    const small=M.metrics('grid',geometry,1,280,180);
    assert.equal(small.capacity,1);
    assert.ok(small.width*small.scale<=280 && small.height*small.scale<=180);
});
test('older custom views gain row limits while keeping their styling and assignments', () => {
    const copy=M.duplicate(defaults,'grid','Existing grid');
    const stored=M.persisted(copy.config);
    stored.profiles.workspace.view=copy.id;
    const v=stored.customViews[0];
    delete v.geometry.rows;v.geometry.maxVisible=12;v.geometry.columns=4;v.card.radius=7;
    const normalized=M.normalize(defaults,stored);
    const migrated=M.view(normalized,copy.id);
    assert.equal(migrated.geometry.rows,3);
    assert.equal(migrated.geometry.columns,4);
    assert.equal(migrated.card.radius,7);
    assert.equal(normalized.profiles.workspace.view,copy.id);
    assert.deepEqual(valid(normalized),[]);
    assert.deepEqual(M.normalize(defaults,M.persisted(normalized)),normalized);
});

test('fresh installs ship only the four original views and no personal presets', () => {
    for (const entry of [undefined, {}, {id:'renanmt.switch-magic'}, {version:2}]) {
        const config=M.normalize(defaults,entry);
        assert.deepEqual(config.customViews,[]);
        assert.deepEqual(M.catalog(config).map(v=>v.id),['list','grid','carousel','fan']);
        assert.deepEqual(config.profiles,defaults.profiles);
        assert.deepEqual(valid(config),[]);
    }
});

test('shortcuts migrate to defaults, canonicalize aliases and reject duplicate or unsafe chords', () => {
    assert.equal(defaults.profiles.workspace.shortcut, 'ALT + TAB');
    assert.equal(defaults.profiles.spaces.shortcut, 'ALT + SUPER + TAB');
    assert.equal(M.normalizeShortcut(' win + control + k '), 'CTRL + SUPER + K');
    assert.equal(M.normalizeShortcut('super + alt + tab'), 'ALT + SUPER + TAB');
    for (const chord of ['TAB', 'CTRL + CTRL + K', 'ALT +', 'ALT + ESC', 'ALT + TAB; os.execute("bad")', 'CTRL + a\nK'])
        assert.throws(() => M.normalizeShortcut(chord));
    const old=M.persisted(defaults);
    for (const scope of M.scopes) delete old.profiles[scope].shortcut;
    assert.deepEqual(M.normalize(defaults,old).profiles,defaults.profiles);
    const duplicate=M.clone(defaults);
    duplicate.profiles.spaces.shortcut='Alt+Tab';
    assert.match(valid(duplicate).join(' '),/already assigned/);
    const custom=M.assignShortcut(defaults,'spaces','win+control+k',false);
    assert.equal(custom.profiles.spaces.shortcut,'CTRL + SUPER + K');
    assert.deepEqual(M.normalize(defaults,M.persisted(custom)),custom);
});
test('confirmed shortcut reassignment leaves the previous scope unassigned and survives reload', () => {
    const original=JSON.stringify(defaults);
    assert.equal(M.shortcutOwner(defaults,'alt+tab','spaces'),'workspace');
    assert.throws(()=>M.assignShortcut(defaults,'spaces','alt+tab',false),/already assigned/);
    const reassigned=M.assignShortcut(defaults,'spaces','alt+tab',true);
    assert.equal(reassigned.profiles.workspace.shortcut,'');
    assert.equal(reassigned.profiles.spaces.shortcut,'ALT + TAB');
    assert.deepEqual(valid(reassigned),[]);
    assert.deepEqual(M.normalize(defaults,M.persisted(reassigned)),reassigned);
    assert.equal(JSON.stringify(defaults),original);
    assert.ok(!M.bindingCode(reassigned).includes('"workspace"'));
    let disabled=M.clone(defaults);
    for (const scope of M.scopes) disabled=M.assignShortcut(disabled,scope,'',false);
    assert.equal(M.bindingCode(disabled),'{}');
    assert.deepEqual(valid(disabled),[]);
});
test('reset restores all shipped settings while retaining complete custom views', () => {
    const created=M.duplicate(defaults,'fan','Keep this');
    let changed=M.changeView(created.config,created.id,'card.radius',7);
    changed.profiles.workspace={view:created.id,preview:'icon',shortcut:'CTRL + K'};
    changed.behavior.showLogo=false;
    changed.behavior.hoverSelect=true;
    const reset=M.resetSettings(changed,defaults);
    assert.deepEqual(reset.profiles,defaults.profiles);
    assert.deepEqual(reset.behavior,defaults.behavior);
    assert.deepEqual(reset.customViews,changed.customViews);
    assert.equal(M.view(reset,created.id).card.radius,7);
    assert.notEqual(reset.customViews,changed.customViews);
    assert.deepEqual(valid(reset),[]);
});

test('background blur defaults to 20%, persists percentages and rejects invalid values', () => {
    assert.equal(M.normalize(defaults, {version:2,behavior:{showLogo:false}}).behavior.backgroundBlur,20);
    for (const amount of [0, 35, 100]) {
        const config=M.merge(defaults,{behavior:{backgroundBlur:amount}});
        assert.deepEqual(valid(config),[]);
        assert.equal(M.normalize(defaults,M.persisted(config)).behavior.backgroundBlur,amount);
        assert.equal(M.resetSettings(config,defaults).behavior.backgroundBlur,20);
    }
    for (const amount of [-1,101,1.5,'50',null])
        assert.match(valid(M.merge(defaults,{behavior:{backgroundBlur:amount}})).join(' '),/backgroundBlur/);
});
