local maps = require("catalog")
local Menu = require("menu")
local Cosmetics = require("cosmetics")
local state = {
    selected=1, visible=false, status="F9 carga el mapa seleccionado.",
    ui=nil, worldAddress=nil, pending=nil, confirmation=nil, queued=false,
    section=1, rows=maps, sectionTitle="Mapas",
}
local function log(message) print("[OARModMenu] " .. tostring(message) .. "\n") end
local function valid(obj) return obj ~= nil and obj:IsValid() end
local function close()
    Menu.destroy(state.ui)
    state.ui=nil
    state.visible=false
    state.confirmation=nil
end
local function context()
    -- UEHelpers v3.0.1 caches the first pawn and can select a remote player on a
    -- listen server. Resolve the local controller every time, including menus.
    for _, pc in ipairs(FindAllOf("PlayerController") or {}) do
        if valid(pc) and pc:IsLocalController() then
            local world = pc:GetWorld()
            if valid(world) then
                -- Read the world's native object name with UE4SS. On this
                -- build, marshalling GetCurrentLevelName's FString through
                -- UE4SS 3.0.1 can crash before Lua can catch an error.
                local level = assert(world:GetFullName():match("%.([^%.:]+)$"), "No se reconoce el mundo actual")
                local currentIndex, currentName
                for i,map in ipairs(maps) do
                    if level == map.filename then currentIndex=i; currentName=map.name; break end
                end
                return {pc=pc, world=world, address=world:GetAddress(),
                    host=valid(world.AuthorityGameMode), online=valid(world.NetDriver),
                    level=level, currentIndex=currentIndex, currentName=currentName,
                    gi=FindFirstOf("RobberGI_C")}
            end
        end
    end
    error("No hay un jugador local listo. Espera a que termine la carga.")
end
local function refresh_rows(ctx)
    local section=Cosmetics.sections[state.section]
    state.sectionTitle=section.title
    state.rows={}
    if section.id=="maps" then state.rows=maps; state.status="F9 carga el mapa seleccionado."
    else state.rows,state.status=Cosmetics.list(ctx,section) end
    state.selected=math.min(math.max(state.selected,1),math.max(#state.rows,1))
end
local function render(ctx)
    if not state.visible then return end
    if state.ui and state.worldAddress ~= ctx.address then close(); return end
    if not state.ui or not valid(state.ui.widget) then
        state.ui=Menu.create(ctx.pc)
        state.worldAddress=ctx.address
    end
    Menu.render(state.ui, state, ctx, state.rows)
end
local function announce(message)
    state.status=message
    log(message)
end
local function guard(action)
    ExecuteInGameThread(function()
        local ok, err = pcall(function() action(context()) end)
        if not ok then
            state.confirmation=nil
            log(tostring(err))
            local message=tostring(err):match("^[^\r\n]+") or "Error desconocido"
            message=message:gsub("^.-%.lua:%d+:%s*","")
            if #message>150 then message="No se pudo completar la acción. Consulta UE4SS.log y vuelve a abrir el menú con F6." end
            announce(message)
            -- A UI failure must not leave an invisible menu or consume inputs.
            if state.visible and (not state.ui or not valid(state.ui.widget)) then close() end
        end
    end)
end
local function toggle(ctx)
    if state.visible then close(); return end
    state.visible=true
    if state.section==1 and ctx.currentIndex then state.selected=ctx.currentIndex end
    refresh_rows(ctx)
    render(ctx)
end
local function select_map(ctx, delta)
    if not state.visible or state.pending then return end
    if #state.rows==0 then return end
    state.selected=((state.selected-1+delta)%#state.rows)+1
    state.confirmation=nil
    state.status=state.section==1 and "F9 carga el mapa seleccionado." or "F9 equipa el objeto seleccionado."
    render(ctx)
end
local function request_travel(ctx)
    if not state.visible then return end
    if not ctx.host then
        announce("El cambio de mapa lo ejecuta el anfitrion de la sala.")
        render(ctx); return
    end
    if state.pending then announce("Ya hay un mapa cargando. Espera."); render(ctx); return end
    local target=maps[state.selected]
    if not target then
        announce("Selecciona un mapa disponible.")
        render(ctx); return
    end
    local key="load:" .. target.package
    local now=os.time()
    if not state.confirmation or state.confirmation.key ~= key or now > state.confirmation.expires then
        state.confirmation={key=key, expires=now+5}
        announce("Pulsa F9 otra vez: cargar " .. target.name .. ".")
        render(ctx); return
    end
    -- A real server-side travel keeps the listen server and tells clients to
    -- follow. Never call OpenLevel or ClientTravel here: those can split a lobby.
    assert(valid(ctx.gi), "GameInstance no disponible")
    local mapClass=StaticFindObject(target.class)
    if not valid(mapClass) then mapClass=LoadAsset(target.class) end
    assert(valid(mapClass), "Mapa no disponible en esta version: " .. target.filename)
    -- The game's UpdateMap updates SelectedMap, Map and the Steam lobby map name.
    ctx.gi:UpdateMap(mapClass)
    state.pending={filename=target.filename, address=ctx.address, started=now}
    announce("Cargando " .. target.name .. "...")
    close()
    local ok, err=pcall(function() ctx.pc:SwitchLevel(target.package) end)
    if not ok then state.pending=nil; error(err) end
end
RegisterKeyBind(Key.F6, function() guard(toggle) end)
RegisterKeyBind(Key.F7, function() guard(function(ctx) select_map(ctx,-1) end) end)
RegisterKeyBind(Key.F8, function() guard(function(ctx) select_map(ctx,1) end) end)
RegisterKeyBind(Key.F9, function() guard(function(ctx)
    if not state.visible or state.pending then return end
    if state.section==1 then request_travel(ctx)
    elseif state.rows[state.selected] then
        announce(Cosmetics.apply(ctx,Cosmetics.sections[state.section],state.rows[state.selected]))
        render(ctx)
    end
end) end)
RegisterKeyBind(Key.F5, function() guard(function(ctx)
    if not state.visible or state.pending then return end
    state.section=(state.section % #Cosmetics.sections)+1
    state.selected=1; state.confirmation=nil
    refresh_rows(ctx); render(ctx)
end) end)
LoopAsync(1000, function()
    if (not state.visible and not state.pending) or state.queued then return false end
    state.queued=true
    ExecuteInGameThread(function()
        state.queued=false
        if state.pending and os.time()-state.pending.started > 45 then
            state.pending=nil
            announce("No se confirmó el cambio. Abre F6 y vuelve a intentarlo.")
        end
        local ok, ctx=pcall(context)
        if not ok then return end -- transient: objects are unavailable during travel
        if state.pending then
            if ctx.address ~= state.pending.address and ctx.level == state.pending.filename then
                log("Mapa cargado: " .. ctx.level)
                state.pending=nil
                state.status="Mapa cargado. F6 abre el menu."
            end
        end
        if state.confirmation and os.time() > state.confirmation.expires then
            state.confirmation=nil
            state.status=state.section==1 and "F9 carga el mapa seleccionado." or "F9 equipa el objeto seleccionado."
        end
        local rendered, err=pcall(function() render(ctx) end)
        if not rendered then log(err); close() end
    end)
    return false
end)
log("v1.0.0 cargado. F6 abre el selector; F5 cambia de sección. Catalogo: " .. #maps .. " atracos.")
