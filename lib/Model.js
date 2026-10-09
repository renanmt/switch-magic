// Pure functions shared by QML and the Node test suite. No desktop side effects.
function clone(value) { return JSON.parse(JSON.stringify(value)); }
function plain(value) { return value !== null && typeof value === "object" && !Array.isArray(value); }
function merge(base, patch) {
    var out = clone(base);
    if (!plain(patch)) return out;
    Object.keys(patch).forEach(function(key) {
        if (key === "__proto__" || key === "constructor" || key === "prototype") return;
        out[key] = plain(out[key]) && plain(patch[key]) ? merge(out[key], patch[key]) : clone(patch[key]);
    });
    return out;
}
function wrap(value, length) { return length ? ((value % length) + length) % length : 0; }
function selectWindows(windows, scope, context, includeSpecial) {
    return windows.filter(function(w) {
        if (!w.mapped || w.hidden) return false;
        if (!includeSpecial && w.special && !(scope === "workspace" && w.workspaceId === context.workspaceId)) return false;
        if (scope === "workspace") return w.workspaceId === context.workspaceId || (w.pinned && w.monitorId === context.monitorId);
        if (scope === "monitor") return w.monitorId === context.monitorId;
        return true;
    }).sort(function(a, b) {
        // Some compositors report -1 for windows never focused.
        var ar = a.rank < 0 ? 1e9 : a.rank, br = b.rank < 0 ? 1e9 : b.rank;
        return ar - br || a.address.localeCompare(b.address);
    });
}
function selectWorkspaces(workspaces, monitorId) {
    return workspaces.filter(function(w) {
        return Number.isInteger(w.id) && !w.special && w.monitorId === monitorId;
    }).sort(function(a, b) { return a.id - b.id; });
}
function initialIndex(windows, activeAddress) {
    var index = windows.findIndex(function(w) { return w.address === activeAddress; });
    return index < 0 ? 0 : wrap(index + 1, windows.length);
}
function remaining(windows, addresses, selected) {
    var chosen = windows[selected];
    var rows = windows.filter(function(w) { return addresses.indexOf(w.address) >= 0; });
    var index = chosen ? rows.findIndex(function(w) { return w.address === chosen.address; }) : -1;
    return { windows: rows, index: index >= 0 ? index : Math.max(0, Math.min(selected, rows.length - 1)) };
}
function gridLimits(layout, availableWidth, availableHeight) {
    // Fit full-sized tiles and gaps first. Only an oversized single tile scales.
    var columns = Math.max(1, Math.min(layout.columns, Math.floor((availableWidth + layout.gap) / (layout.cardWidth + layout.gap))));
    var maxRows = layout.rows === undefined ? Math.max(1, Math.ceil(layout.maxVisible / layout.columns)) : layout.rows;
    var rows = Math.max(1, Math.min(maxRows, Math.floor((availableHeight + layout.gap) / (layout.cardHeight + layout.gap))));
    return { columns: columns, rows: rows };
}
function metrics(name, layout, count, availableWidth, availableHeight) {
    var limits = name === "grid" ? gridLimits(layout, availableWidth, availableHeight) : {columns: 1, rows: 1};
    var columns = Math.min(limits.columns, count || 1);
    var capacity = Math.max(1, Math.min(name === "grid" ? columns * limits.rows : layout.maxVisible, count || 1));
    if (name === "list") capacity = Math.min(capacity, Math.max(1, Math.floor((availableHeight + layout.gap) / (layout.cardHeight + layout.gap))));
    var width = name === "list" ? layout.width : name === "grid" ? columns * (layout.cardWidth + layout.gap) - layout.gap : layout.width;
    var height = name === "list" ? capacity * (layout.cardHeight + layout.gap) - layout.gap : name === "grid" ? Math.ceil(capacity / columns) * (layout.cardHeight + layout.gap) - layout.gap : layout.cardHeight + 150;
    var scale = Math.min(1, availableWidth / width, availableHeight / height);
    return { width: width, height: height, scale: Math.max(0.1, scale), columns: columns, rows: limits.rows, capacity: capacity };
}
function placement(name, layout, index, selected, count, m) {
    var active = index === selected;
    var page = Math.floor(selected / m.capacity), slot = index - page * m.capacity;
    var x = 0, y = 0, angle = 0, scale = active ? 1 : layout.inactiveScale, visible;
    if (name === "list" || name === "grid") {
        visible = slot >= 0 && slot < m.capacity;
        x = name === "list" ? (m.width - layout.cardWidth) / 2 : (slot % m.columns) * (layout.cardWidth + layout.gap);
        y = name === "list" ? slot * (layout.cardHeight + layout.gap) : Math.floor(slot / m.columns) * (layout.cardHeight + layout.gap);
    } else {
        var distance = wrap(index - selected + Math.floor(count / 2), count) - Math.floor(count / 2);
        var left = Math.floor(m.capacity / 2), right = m.capacity - 1 - left;
        visible = distance >= -left && distance <= right;
        x = (m.width - layout.cardWidth) / 2 + distance * layout.spread;
        y = 45 + Math.abs(distance) * layout.depth;
        angle = name === "fan" ? distance * layout.angle : 0;
        scale = Math.pow(layout.inactiveScale, Math.abs(distance));
    }
    return { x: x, y: y, width: layout.cardWidth, height: layout.cardHeight, rotation: angle, scale: scale,
        opacity: visible ? (active ? 1 : layout.inactiveOpacity) : 0, visible: visible, z: active ? 100 : 50 - Math.abs(index - selected) };
}
function equal(a, b) {
    if (a === b) return true;
    if (a === null || b === null || typeof a !== "object" || typeof b !== "object") return false;
    if (Array.isArray(a) !== Array.isArray(b)) return false;
    var ak = Object.keys(a), bk = Object.keys(b);
    return ak.length === bk.length && ak.every(function(k) { return Object.prototype.hasOwnProperty.call(b, k) && equal(a[k], b[k]); });
}
function catalog(config) { return (config.views || []).concat(config.customViews || []); }
function view(config, id) { return catalog(config).find(function(v) { return v.id === id; }) || null; }
function builtin(config, id) { return (config.views || []).some(function(v) { return v.id === id; }); }
function get(object, path) { return path.split(".").reduce(function(v, k) { return v && v[k]; }, object); }
function put(object, path, value) {
    var keys = path.split("."), current = object;
    if (keys.some(function(k) { return ["__proto__", "constructor", "prototype"].indexOf(k) >= 0; })) throw new Error("Invalid property");
    for (var i = 0; i < keys.length - 1; i++) current = current[keys[i]];
    current[keys[keys.length - 1]] = value;
}
function newId(config, name) {
    var base = "custom-" + name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 45);
    if (base === "custom-") base += "view";
    var id = base, counter = 2;
    while (view(config, id)) id = base + "-" + counter++;
    return id;
}
function nameError(config, name, exceptId) {
    if (typeof name !== "string" || !name.trim() || name.trim().length > 60) return "Use a name between 1 and 60 characters.";
    if (/[\x00-\x1f]/.test(name)) return "View names cannot contain control characters.";
    if (catalog(config).some(function(v) { return v.id !== exceptId && v.name.toLowerCase() === name.trim().toLowerCase(); })) return "A view already has that name.";
    return "";
}
function duplicate(config, sourceId, name) {
    var source = view(config, sourceId);
    if (!source) throw new Error("Unknown source view");
    if ((config.customViews || []).length >= 64) throw new Error("The library can hold up to 64 custom views.");
    var error = nameError(config, name);
    if (error) throw new Error(error);
    var next = clone(config), copy = clone(source);
    copy.id = newId(next, name); copy.name = name.trim();
    next.customViews.push(copy);
    return { config: next, id: copy.id };
}
function changeView(config, id, path, value) {
    if (builtin(config, id)) throw new Error("Built-in views are read-only. Duplicate this view to customize it.");
    var next = clone(config), target = view(next, id);
    if (!target) throw new Error("Unknown view");
    if (path === "id") throw new Error("View identifiers cannot be changed.");
    if (path === "name") { var error = nameError(config, value, id); if (error) throw new Error(error); value = value.trim(); }
    if (path === "engine" && value === "grid" && target.engine !== "grid") {
        // Other engines commonly carry an unused columns=1. Start a real grid.
        var template = view(config, "grid");
        target.geometry.columns = template.geometry.columns;
        target.geometry.rows = template.geometry.rows;
    }
    put(target, path, value);
    return next;
}
function removeView(config, id) {
    if (builtin(config, id)) throw new Error("Built-in views cannot be deleted.");
    var target = view(config, id);
    if (!target) throw new Error("Unknown view");
    var next = clone(config);
    next.customViews = next.customViews.filter(function(v) { return v.id !== id; });
    Object.keys(next.profiles).forEach(function(scope) { if (next.profiles[scope].view === id) next.profiles[scope].view = target.engine; });
    return next;
}
function normalize(defaults, stored) {
    stored = stored || {};
    if (!plain(stored)) throw new Error("Settings must be an object");
    if (stored.version !== undefined && stored.version !== 1 && stored.version !== 2) throw new Error("Unsupported settings version");
    var result = clone(defaults);
    if (stored.behavior) result.behavior = merge(result.behavior, stored.behavior);
    if (stored.version === 2) {
        if (stored.views && !equal(stored.views, defaults.views)) throw new Error("Built-in views are read-only; use customViews.");
        if (stored.profiles) result.profiles = merge(result.profiles, stored.profiles);
        if (stored.customViews !== undefined) result.customViews = clone(stored.customViews);
        if (Array.isArray(result.customViews)) result.customViews.forEach(function(v) {
            if (plain(v) && plain(v.geometry) && v.geometry.rows === undefined)
                v.geometry.rows = v.engine === "grid" ? Math.min(8, Math.max(1, Math.ceil(v.geometry.maxVisible / v.geometry.columns))) : 2;
        });
        return result;
    }
    // v1 migration retains each scope's geometry and motion in named copies
    // only when it differs from a shipped template. Originals stay immutable.
    ["workspace", "monitor", "all"].forEach(function(scope) {
        var p = stored.profiles && stored.profiles[scope];
        if (!p) return;
        var source = view(result, p.layout);
        if (!source) throw new Error("Unknown legacy layout: " + p.layout);
        var candidate = clone(source);
        if (stored.layouts && stored.layouts[p.layout]) candidate.geometry = merge(candidate.geometry, stored.layouts[p.layout]);
        if (candidate.engine === "grid") candidate.geometry.rows = Math.min(8, Math.max(1, Math.ceil(candidate.geometry.maxVisible / candidate.geometry.columns)));
        if (p.animation) candidate.animation = merge(candidate.animation, p.animation);
        var a = stored.appearance || {};
        ["radius", "showWorkspace"].forEach(function(k) { if (a[k] !== undefined) candidate.card[k] = a[k]; });
        ["dimOpacity", "accent", "showHints"].forEach(function(k) { if (a[k] !== undefined) candidate.scene[k] = a[k]; });
        var id = source.id;
        if (!equal(candidate, source)) {
            candidate.name = source.name + " · " + scope;
            candidate.id = newId(result, candidate.name);
            result.customViews.push(candidate); id = candidate.id;
        }
        result.profiles[scope] = { view: id, preview: p.preview || "view" };
    });
    return result;
}
function persisted(config) {
    // Null removes obsolete data from use even though Omarchy's inline writer
    // merges keys. Bundled templates are deliberately never persisted as edits.
    return { version: 2, behavior: clone(config.behavior), profiles: clone(config.profiles), customViews: clone(config.customViews), views: null, layouts: null, appearance: null };
}
function validate(config, defaults, groups) {
    var errors = [];
    if (!plain(config) || config.version !== 2) return ["version must be 2"];
    if (!plain(config.profiles) || !plain(config.behavior) || !Array.isArray(config.views) || !Array.isArray(config.customViews)) return ["Invalid settings structure"];
    if (defaults && !equal(config.views, defaults.views)) errors.push("Built-in views are read-only; duplicate a view instead.");
    if (config.customViews.length > 64) errors.push("At most 64 custom views are supported.");
    ["includeSpecial", "hoverSelect", "showLogo"].forEach(function(k) { if (typeof config.behavior[k] !== "boolean") errors.push("behavior." + k + " must be true or false"); });
    var ids = {}, names = {};
    catalog(config).forEach(function(v) {
        if (!plain(v) || typeof v.id !== "string" || typeof v.name !== "string") { errors.push("Every view needs an id and name."); return; }
        var path = v.name + ": ";
        if (!/^[a-z][a-z0-9-]{0,79}$/.test(v.id) || ids[v.id]) errors.push(path + "invalid or duplicate id");
        ids[v.id] = true;
        var normalizedName = v.name.trim().toLowerCase();
        if (!normalizedName || v.name.length > 60 || /[\x00-\x1f]/.test(v.name) || names[normalizedName]) errors.push(path + "invalid or duplicate name");
        names[normalizedName] = true;
        (groups || []).forEach(function(group) {
            group.fields.forEach(function(field) {
                var value = get(v, field.path), error = "";
                if (field.type === "boolean") { if (typeof value !== "boolean") error = "must be true or false"; }
                else if (field.type === "enum") { if (field.options.indexOf(value) < 0) error = "has an unknown value"; }
                else if (field.type === "color") { if (typeof value !== "string" || !/^(theme|#[0-9a-fA-F]{6})$/.test(value)) error = "must be theme or #rrggbb"; }
                else if (field.type === "text") { if (typeof value !== "string" || !value.trim() || value.length > field.maxLength) error = "must be a non-empty font name"; }
                else if (typeof value !== "number" || !isFinite(value) || value < field.min || value > field.max || (field.step >= 1 && value % 1)) error = "must be between " + field.min + " and " + field.max;
                if (error) errors.push(path + field.path + " " + error);
            });
        });
    });
    ["workspace", "monitor", "all", "spaces"].forEach(function(scope) {
        var p = config.profiles[scope];
        if (!plain(p) || !view(config, p.view)) errors.push("profiles." + scope + ": unknown view");
        if (!plain(p) || ["view", "live", "snapshot", "hybrid", "icon"].indexOf(p.preview) < 0) errors.push("profiles." + scope + ": unknown preview mode");
    });
    return errors;
}
if (typeof module !== "undefined") module.exports = { clone: clone, merge: merge, equal: equal, validate: validate, normalize: normalize, persisted: persisted, catalog: catalog, view: view, builtin: builtin, get: get, put: put, duplicate: duplicate, changeView: changeView, removeView: removeView, nameError: nameError, wrap: wrap, selectWindows: selectWindows, selectWorkspaces: selectWorkspaces, initialIndex: initialIndex, remaining: remaining, gridLimits: gridLimits, metrics: metrics, placement: placement };
