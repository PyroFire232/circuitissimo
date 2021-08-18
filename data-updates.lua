require("lib/lib")
require("sound/sound")
local path = '__circuitissimo__'

local combos={"arithmetic-combinator","decider-combinator","constant-combinator"}

local todo={}
for i,dt in pairs(combos)do for nm,e in pairs(data.raw[dt])do todo[nm]=e end end

local polei=table.deepcopy(data.raw["item"]["small-electric-pole"])
polei.name="wire-pole"
polei.icon=path.."/graphics/icons/wire-pole.png"
polei.icon_size=32
polei.subgroup="circuit-network"
polei.order="b[wires]-b[wire-pole]"
polei.place_result="wire-pole"

local poler={type="recipe",name="wire-pole",result="wire-pole",result_count=1,requester_paster_multiplier=10}
poler.ingredients={{"small-electric-pole",1},{"red-wire",2},{"green-wire",2},{"iron-plate",2}}

local pole=table.deepcopy(data.raw["electric-pole"]["small-electric-pole"])
pole.name="wire-pole"
pole.place_result="wire-pole"
pole.icon=path.."/graphics/icons/wire-pole.png"
pole.icon_size=32
pole.selection_box={{-0.5,-0.5},{0.5,0.5}}
pole.minable.result="wire-pole"
pole.maximum_wire_distance=15
pole.supply_area_distance=0
pole.draw_copper_wires=false
pole.pictures={
	filename=path.."/graphics/entity/wire-pole/wire-pole.png",
	priority="extra-high",
	width=60,height=36,direction_count=4,shift=util.by_pixel(16,1)
}
pole.track_coverage_during_build_by_moving=false
pole.connection_points={
	{ shadow = {red = {0.6, 0.4},green = {0.9, 0.42}}, wire = {red = {-0.375, -0.35},green = {0.00625, -0.35}} },
	{ shadow = {red = {0.5, 0.1},green = {0.95, 0.4}}, wire = {red = {-0.31, -0.5},green = {-0.1, -0.34}} },
	{ shadow = {red = {0.85, 0.1},green = {0.85, 0.5}}, wire = {red = {-0.09, -0.525},green = {-0.08, -0.275}} },
	{ shadow = {red = {0.85, 0.2},green = {0.5, 0.48}}, wire = {red = {0.1, -0.45},green = {-0.125, -0.3}} },
}
pole.radius_visualisation_picture.filename=path.."/graphics/entity/wire-pole/wire-pole-radius-visualization.png"

data:extend{polei,poler,pole}

todo[pole.name]=pole



for nm,e in pairs(todo)do
	local ent=table.deepcopy(e)
	local rcp=table.deepcopy(data.raw.recipe[e.name])
	local item=table.deepcopy(data.raw.item[e.name])
	if(ent and rcp and item)then

	ent.name=""..e.name.."_tiny"
	ent.alert_icon_scale=0.1e-1000
	ent.localised_name={"entity-name."..e.name}
	item.name=ent.name
	item.place_result=ent.name
	ent.minable=nil --ent.minable.result=ent.name

	ent.flags=ent.flags or {}
	table.insert(ent.flags,"not-on-map")
	table.insert(ent.flags,"not-blueprintable")
	table.insert(ent.flags,"placeable-off-grid")
	table.insert(ent.flags,"hide-alt-info")
	table.insert(ent.flags,"not-deconstructable")
	table.insert(ent.flags,"not-upgradable")
	table.insert(ent.flags,"hidden")
	table.insert(ent.flags,"not-rotatable")
	ent.collision_mask={}


	rcp.name=ent.name
	rcp.result=ent.name
	rcp.enabled=false
	rcp.hidden=true
	proto.AutoResize(ent,0.125)
	data:extend{rcp,item,ent}

	end
end


local ent=table.deepcopy(data.raw["decider-combinator"]["decider-combinator"])
local rcp=table.deepcopy(data.raw.recipe["decider-combinator"])
local item=table.deepcopy(data.raw.item["decider-combinator"])

ent.name="circuitchip-combinator"
rcp.name=ent.name
rcp.result=ent.name
--rcp.enabled=true
item.name=ent.name
item.place_result=ent.name
ent.minable.result=ent.name
item.type="item-with-tags"
item.order="b[wires]-c[wire-pole]"

local tint={r=0.1,g=0.4,b=1,a=0.35}
for sdir,stbl in pairs(ent.sprites)do
	for x,y in pairs(stbl.layers)do
		y.tint=tint
		y.hr_version.tint=tint
	end
end
local tint={r=0.1,g=0.4,b=1,a=0.75}
if(rcp.icon)then rcp.icons={{icon=rcp.icon,tint=tint}} rcp.icon=nil elseif(rcp.icons)then rcp.icons[1].tint=tint end
if(item.icon)then item.icons={{icon=item.icon,tint=tint}} item.icon=nil elseif(item.icons)then item.icons[1].tint=tint end

data:extend{ent,rcp,item}




table.insert(data.raw.technology["circuit-network"].effects,{type="unlock-recipe",recipe="circuitchip-combinator"})
table.insert(data.raw.technology["circuit-network"].effects,{type="unlock-recipe",recipe="wire-pole"})



lib.lua()