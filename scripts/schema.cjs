// Generate the schema from the same field catalogue used by the studio.
const fs = require('node:fs');
const path = require('node:path');
const fields = require('../lib/ViewFields.js').groups;
const object = properties => ({type:'object',additionalProperties:false,properties});
const view = object({id:{type:'string',pattern:'^[a-z][a-z0-9-]{0,79}$'},name:{type:'string',minLength:1,maxLength:60}});
for(const group of fields) for(const field of group.fields) {
    let shape;
    if(field.type==='boolean') shape={type:'boolean'};
    else if(field.type==='enum') shape={enum:field.options};
    else if(field.type==='color') shape={type:'string',pattern:'^(theme|#[0-9a-fA-F]{6})$'};
    else if(field.type==='text') shape={type:'string',minLength:1,maxLength:field.maxLength};
    else shape={type:field.step>=1?'integer':'number',minimum:field.min,maximum:field.max};
    shape.description=field.label+(field.unit?' ('+field.unit+')':'');
    let current=view;
    const segments=field.path.split('.');
    for(const segment of segments.slice(0,-1)) {
        if(!current.properties[segment]) current.properties[segment]=object({});
        current=current.properties[segment];
    }
    current.properties[segments.at(-1)]=shape;
}
function requireAll(node) {
    if(node.type!=='object') return;
    node.required=Object.keys(node.properties);
    Object.values(node.properties).forEach(requireAll);
}
requireAll(view);
const profile=object({shortcut:{type:'string',description:'Modifier chord such as ALT + TAB; empty disables this scope shortcut.'},view:{type:'string',description:'Built-in id or a custom view id'},preview:{enum:['view','live','snapshot','hybrid','icon']}});
const schema=object({
    '$schema':{type:'string'},id:{const:'renanmt.switch-magic'},version:{const:2},
    behavior:object({includeSpecial:{type:'boolean'},hoverSelect:{type:'boolean'},showLogo:{type:'boolean'},backgroundBlur:{type:'integer',minimum:0,maximum:100,description:'Background blur percentage; 0 disables blur.'}}),
    profiles:object({workspace:profile,monitor:profile,all:profile,spaces:profile}),
    customViews:{type:'array',maxItems:64,items:view},
    views:{type:'null',description:'Built-in templates are read-only and loaded from defaults.json.'},
    layouts:{type:'null',description:'Obsolete v1 field.'},appearance:{type:'null',description:'Obsolete v1 field; appearance belongs to each view.'}
});
schema['$schema']='https://json-schema.org/draft/2020-12/schema';
schema.title='Switch Magic 0.2 settings';
schema.description='Inline settings for the renanmt.switch-magic plugin. Custom views carry their complete definition. Built-in views cannot be overwritten.';
fs.writeFileSync(path.join(__dirname,'../settings.schema.json'),JSON.stringify(schema,null,2)+'\n');
