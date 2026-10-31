-- Native cosmetic catalogue. No grants, purchase calls or inventory rewrites.
local appearance = require("appearance_catalog")
local C = {}
C.sections = {
    {id="maps", title="Mapas"}, {id="masks", title="Máscaras y gorros", category=10, field="Mask_equipped"},
    {id="outfits", title="Atuendos", category=11, field="OutfitEquipped"},
    {id="emotes", title="Bailes y gestos", category=12, field="EmoteEquipped"},
    {id="primary", title="Skin del arma principal", weaponCategory=0},
    {id="secondary", title="Skin del arma secundaria", weaponCategory=1},
}
local function valid(obj) return obj ~= nil and obj:IsValid() end
local function text(value)
    if type(value)=="string" then return value end
    if value==nil then return "" end
    local ok,result=pcall(function() return value:ToString() end)
    return ok and result or tostring(value)
end
local function each(array,fn)
    if array==nil then return end
    if type(array)=="table" then for _,value in ipairs(array) do fn(value) end
    else array:ForEach(function(_,param) fn(param:get()) end) end
end
local function copy(array)
    local out={}; each(array,function(v) out[#out+1]=v end); return out
end
local function path(class)
    return assert(class:GetFullName():match("^[^ ]+ (.+)$"),"Clase de objeto no reconocida")
end
local function load_class(value)
    local class=StaticFindObject(value)
    if not valid(class) then class=LoadAsset(value) end
    assert(valid(class),"El objeto ya no está disponible en esta versión")
    return class
end
local function weapon(pc,category)
    local found
    each(pc.Weapons_Equipped,function(class)
        if valid(class) and tonumber(class:GetCDO()["Item category"])==category then found=found or class end
    end)
    return found
end
function C.list(ctx,section)
    local result,seen={},{}
    if section.weaponCategory~=nil then
        if not weapon(ctx.pc,section.weaponCategory) then return {},"Equipa primero un arma de este tipo en Loadout." end
        local data=load_class("/Game/BP/Guns/WeaponSkins/DT_WeaponSkins.DT_WeaponSkins")
        result[1]={key="skin:0",name="De fábrica",skinID=0,weaponCategory=section.weaponCategory}
        -- Read the installed catalogue, including skins absent from inventory.
        -- GetRowMap returns live structs: copy only IDs/names, never modify rows.
        for _,row in pairs(data:GetRowMap()) do
            local id=tonumber(row.SteamID_10_600466014F11F08532ED01A7636FC70F)
            local category=tonumber(row.Category_25_015332554026C0835714BA9A31C47CD9)
            -- ID 300 is the game's internal "Test skin", not a player cosmetic.
            if category==0 and id and id>0 and id~=300 and not seen[id] then
                seen[id]=true
                result[#result+1]={key="skin:"..id,name=text(row.Name_2_5C3EFC9840D99D71E80AE2AAA8AC6754),
                    skinID=id,weaponCategory=section.weaponCategory}
            end
        end
        table.sort(result,function(a,b) if a.key==b.key then return false end; if a.skinID==0 then return true end; if b.skinID==0 then return false end; return a.name<b.name end)
        return result,"Catálogo completo. F9 prueba la skin en el arma equipada."
    end
    local function add(class)
        if not valid(class) then return end
        local defaults=class:GetCDO()
        if tonumber(defaults["Item category"])~=section.category then return end
        local classPath=path(class)
        if seen[classPath] then return end
        seen[classPath]=true
        local name=text(defaults.Name)
        result[#result+1]={key=classPath,classPath=classPath,name=name~="" and name or classPath:match("%.([^%.]+)$"),field=section.field}
    end
    local missing=0
    for _,classPath in ipairs(appearance[section.category] or {}) do
        local ok,class=pcall(load_class,classPath)
        if ok then add(class) else missing=missing+1 end
    end
    -- Include newer owned and equipped legacy items as well as the fixed catalogue.
    each(ctx.pc.ItemInventory,add)
    each(ctx.pc[section.field],add)
    table.sort(result,function(a,b) return a.name<b.name end)
    local message="Catálogo completo. F9 prueba el objeto y guarda la apariencia."
    if missing>0 then message=message.." No disponibles en este build: "..missing.."." end
    return result,#result==0 and "No hay objetos disponibles. Vuelve a abrir el menú con F6 para actualizar." or message
end
function C.apply(ctx,section,selected)
    -- Resolve again at action time; game assets can change between versions.
    local rows=C.list(ctx,section)
    local row
    for _,candidate in ipairs(rows) do if candidate.key==selected.key then row=candidate; break end end
    assert(row,"El objeto ya no está disponible. Vuelve a abrir el menú con F6 para actualizar.")
    if row.skinID~=nil then
        local gun=assert(weapon(ctx.pc,row.weaponCategory),"No hay un arma equipada")
        ctx.pc:EquipSkin(row.skinID,gun,0)
        return "Skin equipada: "..row.name.."."
    end
    local masks,outfits,emotes,armor=copy(ctx.pc.Mask_equipped),copy(ctx.pc.OutfitEquipped),copy(ctx.pc.EmoteEquipped),copy(ctx.pc.ArmorEquipped)
    local selectedClass=load_class(row.classPath)
    if row.field=="Mask_equipped" then masks={selectedClass}
    elseif row.field=="OutfitEquipped" then outfits={selectedClass}
    elseif row.field=="EmoteEquipped" then emotes={selectedClass}
    else error("Categoría no admitida") end
    ctx.pc:UpdateAppearance(masks,outfits,emotes,armor,ctx.pc.SkinColor)
    -- On a client this is an RPC. Save only after the selected array replicates
    -- back, so a slow server cannot cause the previous appearance to be saved.
    local address,field,expected=ctx.pc:GetAddress(),row.field,row.classPath
    local function save_when_ready(attempt)
        ExecuteWithDelay(250,function() ExecuteInGameThread(function()
            for _,pc in ipairs(FindAllOf("PlayerController") or {}) do
                if valid(pc) and pc:IsLocalController() and pc:GetAddress()==address then
                    local matched=false
                    each(pc[field],function(class) if valid(class) and path(class)==expected then matched=true end end)
                    if matched then pc:SaveAppearance()
                    elseif attempt<8 then save_when_ready(attempt+1) end
                    return
                end
            end
        end) end)
    end
    save_when_ready(1)
    return "Cambio enviado: "..row.name.."."
end
return C
