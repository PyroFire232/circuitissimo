
local surfaces=lib.surfaces

chips=chips or {}

chips.chipcombo="circuitchip-combinator"
chips.combinators={"arithmetic-combinator","decider-combinator","constant-combinator"}
chips.wires={["red"]="red",["green"]="green"}

function chips.MakeChip(ent)
	local idx=#global.chips+1
	global.chips[idx]={index=idx,ent=ent,combos={},combocon={}}
	return global.chips[idx]
end
function chips.GetChip(ent)
	for k,v in pairs(global.chips)do if(v.ent==ent)then return v end end
end


-- Returns a player and the chip they're in, if they're in one.
remote.add_interface("circuitchips",{["GetChipByPlayer"]=function(player_index) return global.players[player_index] end})

function chips.DestroyChip(chip)
	if(chip.players)then
		for k,v in pairs(chip.players)do
			v.ply.teleport(v.pos,v.surface)
		end
	end
	if(chip.surface)then game.delete_surface(chip.surface) end
	if(chip.live_ents)then for k,v in pairs(chip.live_ents)do v.destroy() end end
end


function chips.MakeSurface(chip)
	local f=game.create_surface("circuitchip_"..chip.index,{
		width=32,height=16
	})
	chip.surface=f
	f.request_to_generate_chunks({0,0},4) f.force_generate_chunk_requests() f.destroy_decoratives({})
	local tiles={}
	for k,v in pairs(f.find_tiles_filtered({limit=100000}))do
		local vec=v.position
		if( (vec.x==-17 and vec.y==0) or (vec.x==17 and vec.y==0))then
			table.insert(tiles,{name="concrete",position=vec})
		elseif(math.abs(vec.x)>16 or math.abs(vec.y)>8)then

			table.insert(tiles,{name="out-of-map",position=vec})
		else
			table.insert(tiles,{name="concrete",position=vec})
		end
	end

	f.set_tiles(tiles)
	for k,v in pairs(f.find_entities())do v.destroy() end
	

	chip.input=entity.protect(f.create_entity{name="constant-combinator",position={-17,0},force=game.forces.player},false,false)
	chip.output=entity.protect(f.create_entity{name="constant-combinator",position={17,0},force=game.forces.player},false,false)

	return f
end

function chips.GetOrCreateSurface(chip) return chip.surface or chips.MakeSurface(chip) end

function chips.PlayerEntry(ply,ent)
	local chip=chips.GetChip(ent)
	if(not chip)then chip=chips.MakeChip(ent) else chips.Inflate(chip) end

	chip.players=chip.players or {}
	global.players[ply.index]={ply=ply,surface=ply.surface,pos=ply.position,chip=chip}
	table.insert(chip.players,global.players[ply.index])

	ply.teleport({0,0},chips.GetOrCreateSurface(chip))

	ply.gui.left.add{type="button",caption="Exit Circuit Chip",name="circuitissimo_exit"}
end
function chips.PlayerExit(ply)
	local chip=global.players[ply.index].chip
	local pk,pv
	for k,v in pairs(chip.players)do if(v.ply==ply)then pk,pv=k,v break end end
	ply.teleport(pv.pos,pv.surface)
	chip.players[pk]=nil
	global.players[ply.index]=nil

	if(table_size(chip.players)==0)then
		chips.Compile(chip)
		chips.Construct(chip)
	end
end
function chips.OnGuiClick(ev) if(ev.element.name=="circuitissimo_exit")then local ply=game.players[ev.player_index] chips.PlayerExit(ply) ev.element.destroy() end end
events.on_event(defines.events.on_gui_click,chips.OnGuiClick)

--[[
events.on_event(defines.events.on_player_used_capsule,function(ev) if(ev.item.name~="circuitchip-warp")then return end
	local ply=game.players[ev.player_index] local pos=ev.position local f=ply.surface
	if(global.players[ev.player_index])then return chips.PlayerExit(ply) end
	local ent
	for k,v in pairs(f.find_entities_filtered{position=pos,radius=1})do
		if(v.name==chips.chipcombo)then ent=v break end
	end
	if(not ent or not isvalid(ent))then return end
	local chip=chips.GetChip(ent)
	if(not chip)then chip=chips.MakeChip(ent) else chips.Inflate(chip) end -- return end
	chips.PlayerEntry(ply,ent)
	ply.insert{name=ev.item.name,count=1}

end)
]]


chips.LuaCombos={
	chips.chipcombo, -- Circuitissimo chips cannot be placed inside eachother
	"gui-signal-display", --https://mods.factorio.com/mod/visual-signals
}

function chips.OnBuiltEntity(ev)
	local e=ev.created_entity
	local f=e.surface
	if(f.name:sub(1,12)=="circuitchip_")then
		surfaces.EmitText(f,e.position,"This cannot be built inside a Circuitissimo Chip")
		if(ev.player_index)then game.players[ev.player_index].mine_entity(e,true) else
			local itm=f.create_entity{name="item-on-ground",position=e.position,stack={name=e.minable.result,count=1}} itm.order_deconstruction(e.force) e.destroy()
		end
	end
end
local filts={{filter="name",name="wire-pole",invert=true,mode="and"}}
for k,v in pairs(chips.combinators)do table.insert(filts,{filter="type",type=v,invert=true,mode="and"}) end
events.on_event(defines.events.on_built_entity,chips.OnBuiltEntity,filts)
events.on_event(defines.events.on_robot_built_entity,chips.OnBuiltEntity,filts)

function chips.Compile(chip)
	local f=chip.surface
	local cx={}

	local combos={}
	local combocon={}

	table.insert(combos,chip.input)
	table.insert(combos,chip.output)


	for k,v in pairs(f.find_entities_filtered{type=chips.combinators})do
		if(v.name~=chips.chipcombo and v~=chip.input and v~=chip.output)then
			if(not table.HasValue(chips.LuaCombos,v.name))then table.insert(combos,v) else game.print("An incompatible combinator was lost in a Circuitissimo chip: " .. v.name) end
		end
	end
	for k,v in pairs(f.find_entities_filtered{name="wire-pole"})do table.insert(combos,v) end
	for k,v in pairs(f.find_entities_filtered{type=chips.combinators,name="wire-pole",invert=true})do
		game.print("An entity was lost in a Circuitissimo chip: " .. v.name)
	end

	for k,v in pairs(combos)do if(k~=1 and k~=2)then -- connections now
		local nb=v.circuit_connection_definitions
		for kx,conn in pairs(nb)do
			for kdx,ve in pairs(combos)do if(ve==conn.target_entity)then
				if(not ((combocon[kdx] or {})[conn.wire] or {})[kdx])then
					combocon[k]=combocon[k] or {}
					combocon[k][conn.wire]=combocon[k][conn.wire] or {}
					combocon[k][conn.wire][kdx]=combocon[k][conn.wire][kdx] or {}
					table.insert(combocon[k][conn.wire][kdx],{source=conn.source_circuit_id,target=conn.target_circuit_id})
				end
			end end
		end
	end end

	chip.combocon=combocon
	chip.combos={}
	for k,v in pairs(combos)do -- store data
		local mode,data
		if(v.name~="wire-pole")then mode=v.get_or_create_control_behavior() data=table.deepcopy(mode.parameters) end
		local vpos=vector(v.position)/17 -- translate it to tiny
		chip.combos[k]={cls=v.name,position=vpos,direction=v.direction,parameters=data}
	end


	if(chip.surface)then
		game.delete_surface(chip.surface) chip.surface=nil
	end



end
function chips.Inflate(chip)

	local f=chips.GetOrCreateSurface(chip)
	local ents={}
	for k,v in pairs(chip.combos)do if(k~=1 and k~=2)then
		local vpos=vector(v.position)*17 -- translate tiny to big
		local ex=f.create_entity{name=v.cls,surface=f,position=vpos,direction=v.direction,force=game.forces.player}
		if(v.parameters)then local mode=ex.get_or_create_control_behavior() mode.parameters=table.deepcopy(v.parameters) end
		ents[tonumber(k)]=ex
	end end
	for kx,tbl in pairs(chip.combocon)do local k=tonumber(kx)
		for wire,vtbl in pairs(tbl)do
			for cbidx,ctbl in pairs(vtbl)do local cbid=tonumber(cbidx)
				for _,conn in pairs(ctbl)do
					if(cbid==1)then
						ents[k].connect_neighbour({wire=wire,target_entity=chip.input,source_circuit_id=conn.source,target_circuit_id=conn.target})
					elseif(cbid==2)then
						ents[k].connect_neighbour({wire=wire,target_entity=chip.output,source_circuit_id=conn.source,target_circuit_id=conn.target})
					else
						ents[k].connect_neighbour({wire=wire,target_entity=ents[tonumber(cbid)],source_circuit_id=conn.source,target_circuit_id=conn.target})
					end
				end
			end
		end
	end

	chip.internal_ents=ents
end

function chips.Construct(chip) -- Place it on the world
	if(chip.live_ents)then for k,v in pairs(chip.live_ents)do if(isvalid(v))then v.destroy() end end end
	if(not chip.combos)then return end
	local ent=chip.ent
	local pos=vector(ent.position)
	local f=ent.surface
	local clones={}
	for k,v in pairs(chip.combos)do if(k~=1 and k~=2)then
		local vo=ent.direction if(ent.direction==0 or ent.direction==4)then vo=((ent.direction+2)%8)/8 else vo=((ent.direction-2)%8)/8 end
		local tpos=pos+vector.SnapOrientation(v.position,vo) --pos+vector(v.position)
		local ex=f.create_entity{name=v.cls.."_tiny",position=tpos,force=game.forces.player,direction=((v.direction+ent.direction+2))%8}
		if(v.parameters)then local mode=ex.get_or_create_control_behavior() mode.parameters=table.deepcopy(v.parameters) end
		clones[tonumber(k)]=ex
	end end
	for kx,tbl in pairs(chip.combocon)do local k=tonumber(kx) for wire,vtbl in pairs(tbl)do for kdxx,conntbl in pairs(vtbl)do local kdx=tonumber(kdxx) for i,conn in pairs(conntbl)do
		if(kdx==1)then -- input
			clones[k].connect_neighbour({wire=wire,target_entity=ent,source_circuit_id=conn.source,target_circuit_id=1})
		elseif(kdx==2)then -- output
			clones[k].connect_neighbour({wire=wire,target_entity=ent,source_circuit_id=conn.source,target_circuit_id=2})
		elseif(clones[kdx])then
			clones[k].connect_neighbour({wire=wire,target_entity=clones[kdx],source_circuit_id=conn.source,target_circuit_id=conn.target})
		end
	end end end end
	chip.live_ents=clones
end

function chips.on_init()
	global.chips={}
	global.players={}
end
events.on_init(chips.on_init)

function chips.on_config()
	global.chips=global.chips or {}
end



function chips.on_destroy(ent)
end

cache.ent(chips.chipcombo,{
	gui_opened=function(e,ev)
		game.players[ev.player_index].opened=nil
		chips.PlayerEntry(game.players[ev.player_index],e)
	end,
	create=function(e,ev)
		local chip=chips.MakeChip(e)
		if(ev.tags and ev.tags.circuitchip)then
			chip.combos=table.deepcopy(ev.tags.circuitchip.combos)
			chip.combocon=table.deepcopy(ev.tags.circuitchip.combocon)
			chips.Construct(chip)
		end
		--error(serpent.block(ev.tags))
	end,
	mined=function(e,ev)
		local chip=chips.GetChip(e)
		if(chip and chip.combos)then
			if(ev.robot)then
				local items={} for k,v in pairs(chip.combos)do items[v.cls]=(items[v.cls] or 0)+1 end
				for k,v in pairs(items)do e.surface.spill_item_stack(e.position,{name=k,count=v},false,e.force,false) end
			else
				local ply=game.players[ev.player_index]
				for k,v in pairs(chip.combos)do if(k~=1 and k~=2)then ply.insert{name=v.cls,count=1} end end
			end
		end
	end,
	destroy=function(e)
		local chip=chips.GetChip(e)
		if(chip)then chips.DestroyChip(chip) end
	end,
	clone=function(e,ev)
		local src=ev.source
		local schip=chips.GetChip(src)
		if(schip)then
			local vchip=chips.MakeChip(e)
			vchip.combos=table.deepcopy(schip.combos)
			vchip.combocon=table.deepcopy(schip.combocon)
			chips.Construct(vchip)
		end
	end,
	rotate=function(e)
		local chip=chips.GetChip(e)
		if(chip)then chips.Construct(chip) end
	end,
	settings_pasted=function(e,ev)
		local ply=game.players[ev.player_index]
		local vchip=chips.GetChip(ev.destination)
		if(vchip and vchip.combos)then
			local ply=game.players[ev.player_index]
			for k,v in pairs(vchip.combos)do if(k~=1 and k~=2)then ply.insert{name=v.cls,count=1} end end
		end
		local schip=chips.GetChip(ev.source)
		if(schip and schip.combos)then

			local rcombo={} for k,v in pairs(schip.combos)do if(k>2)then rcombo[v.cls]=(rcombo[v.cls] or 0)+1 end end
			local can=true for k,v in pairs(rcombo)do if(ply.get_item_count(k)<v)then can=false break end end
			if(can)then
				for k,v in pairs(rcombo)do ply.remove_item{name=k,count=v} end
				vchip.combos=table.deepcopy(schip.combos)
				vchip.combocon=table.deepcopy(schip.combocon)
				chips.Construct(vchip)
			end	
		else
			vchip.combos={}
			vchip.combocon={}
			chips.Construct(chip)
		end
	end,
})


function chips.GetByCombo(cb) -- need some fish for them chips
	for k,v in pairs(global.chips)do if(v.live_ents)then
		for i,e in pairs(v.live_ents)do if(isvalid(e))then
			if(e==cb)then
				return v,i
			end
		end end
	end end
end

events.on_event(defines.events.on_player_setup_blueprint,function(ev)
	local ply=game.players[ev.player_index]
	local bp=ply.blueprint_to_setup
	if(not bp or not bp.valid_for_read)then bp=ply.cursor_stack end if(not bp or not bp.valid_for_read)then return end
	chips.tag_blueprint(ply.surface,ev.area,bp,ev.alt)
end)

--[[
if(v.name==chips.chipcombo)then
			local chip,idx=chips.GetChip(vent)
			if(chip)then
				stack.set_blueprint_entity_tags(v.entity_number,{circuitchip={chip.combos,chip.combocon}}) game.print("set tags")
			end
		else

events.on_event(defines.events.on_built_entity,function(ev) local e=ev.created_entity
	if(e.type~="entity-ghost")then return end
	if(e.name:sub(-5)=="_tiny")then e.destroy() return end -- todo migrate.json and e.name:sub(5)=="circuitchip_")then

	local tags=ev.tags
	if(tags and tags.circuitchip)then
		local chip=chips.MakeChip(ev.created_entity)
		chip.combos=tags.circuitchip[1]
		chip.combocon=tags.circuitchip[2]
		--game.print("got tags!!")
	end
end)
]]

--[[ Blueprint Area ]]--
-- https://github.com/mrvn/factorio-example-entity-with-tags/blob/master/control.lua


local rail_types = {}
rail_types["straight-rail"] = true
rail_types["curved-rail"] = true
rail_types["rail-signal"] = true
rail_types["rail-chain-signal"] = true
rail_types["train-stop"] = true

function deghost(e) local n=e.name if(n=="entity-ghost")then return e.ghost_name,e.ghost_type else return n,e.prototype.type end end
function chips.tag_blueprint(surface,area,bp,alt)
	local bpents=bp.get_blueprint_entities() if(not bpents)then return end
	local bphas={} for k,v in pairs(bpents)do bphas[v.name]=true end
	local rails=false
	local vmin={x=2147483647,y=2147483647}
	local vmax={x=-2147483648,y=-2147483648}

	local ents=surface.find_entities(area)
	for _,ent in pairs(ents)do
		local nm,tp=deghost(ent)
		if(not alt or bphas[nm])then
			if(rail_types[tp])then rails=true end
			local box=ent.bounding_box -- or ent.selection_box
			if(box)then
				if(box.left_top.x<vmin.x)then vmin.x=box.left_top.x end
				if(box.left_top.y<vmin.y)then vmin.y=box.left_top.y end
				if(box.right_bottom.x>vmax.x)then vmax.x=box.right_bottom.x end
				if(box.right_bottom.y>vmax.y)then vmax.y=box.right_bottom.y end
			end
		end
	end
	local btiles=bp.get_blueprint_tiles()
	if(btiles)then
		local bthas={} for k,v in pairs(btiles)do bthas[v.name]=true end
		local mtiles=surface.find_tiles_filtered{area=area}
		for _,tile in pairs(mtiles)do
			local nm=tile.name
			if(tile.prototype.can_be_part_of_blueprint and tile.prototype.items_to_place_this)then
				if(nm=="tile-ghost")then nm=tile.prototype.name end
				if(not alt or bthas[nm])then
					local pos=tile.position
					if(pos.x<vmin.x)then vmin.x=pos.x end
					if(pos.y<vmin.y)then vmin.y=pos.y end
					if(pos.x+1>vmax.x)then vmax.x=pos.x+1 end
					if(pos.y+1>vmax.y)then vmax.y=pos.y+1 end
				end
			end
		end
	end
	local cx,cy
	if(rails)then
		cx=math.floor( (math.floor(vmin.x)+math.ceil(vmax.x)) /4) *2 + 1
		cy=math.floor( (math.floor(vmin.y)+math.ceil(vmax.y)) /4) *2 + 1
	else
		cx=math.floor( (math.floor(vmin.x)+math.ceil(vmax.x)) /2) +0.5
		cy=math.floor( (math.floor(vmin.y)+math.ceil(vmax.y)) /2) +0.5
	end

	local cache={}
	for k,v in pairs(bpents)do cache[v.position.x.."_"..v.position.y.."_"..v.name]=v end
	for k,v in pairs(ents)do local nm,tp=deghost(v) if(bphas[nm])then
		local bpe=cache[v.position.x-cx .."_".. v.position.y-cy .."_"..nm]
		if(bpe)then
			if(bpe.name==chips.chipcombo)then local chip=chips.GetChip(v)
				if(chip)then bp.set_blueprint_entity_tag(bpe.entity_number,"circuitchip",{combos=table.deepcopy(chip.combos),combocon=table.deepcopy(chip.combocon)}) end
			elseif(bpe.name:sub(-5)=="_tiny")then
				bp.set_blueprint_entity_tag(bpe.entity_number,"circuitchips_tiny",true)
			end
		end
	end end
end


