-- UMG panel, created on demand on the game thread. No HUD draw hook is needed.
local Menu = {}
local white = {R=0.96, G=0.97, B=1.0, A=1.0}
local muted = {R=0.68, G=0.73, B=0.80, A=1.0}
local accent = {R=1.0, G=0.78, B=0.28, A=1.0}
local function valid(obj) return obj ~= nil and obj:IsValid() end
local function construct(name, outer)
    local class = StaticFindObject("/Script/UMG." .. name)
    assert(valid(class), "Falta la clase UMG " .. name)
    local obj = StaticConstructObject(class, outer)
    assert(valid(obj), "No se pudo crear " .. name)
    return obj
end
local function set_color(text, color)
    text:SetColorAndOpacity({SpecifiedColor=color, ColorUseRule=0})
end
local function label(tree, box, text, size, color, top, bottom)
    local widget = construct("TextBlock", tree)
    widget:SetText(FText(text))
    local font = widget.Font
    font.Size = size
    widget:SetFont(font)
    set_color(widget, color)
    local slot = box:AddChildToVerticalBox(widget)
    slot:SetPadding({Left=0, Top=top or 0, Right=0, Bottom=bottom or 0})
    return widget
end
function Menu.destroy(ui)
    if ui and valid(ui.widget) then pcall(function() ui.widget:RemoveFromParent() end) end
end
function Menu.create(pc)
    -- A tiny, existing, non-interactive UserWidget supplies a concrete class.
    -- Replace its tree BEFORE AddToViewport, using only reflected UMG methods.
    local path = "/Game/UI/Menu/InventoryCategoryTitle.InventoryCategoryTitle_C"
    local class = StaticFindObject(path)
    if not valid(class) then class = LoadAsset(path) end
    assert(valid(class), "No se pudo cargar InventoryCategoryTitle")
    local library = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    assert(valid(library), "WidgetBlueprintLibrary no disponible")
    local widget = library:Create(pc, class, pc)
    assert(valid(widget), "No se pudo crear el menu")
    local ok, result = pcall(function()
        local tree = widget.WidgetTree
        assert(valid(tree), "El widget no expone WidgetTree")
        local canvas = construct("CanvasPanel", tree)
        tree.RootWidget = canvas
        local border = construct("Border", tree)
        border:SetBrushColor({R=0.035, G=0.045, B=0.065, A=0.98})
        border:SetPadding({Left=24, Top=20, Right=24, Bottom=20})
        local position = canvas:AddChildToCanvas(border)
        position:SetAnchors({Minimum={X=1,Y=0}, Maximum={X=1,Y=0}})
        position:SetAlignment({X=1,Y=0})
        position:SetPosition({X=-24,Y=24})
        position:SetSize({X=580,Y=660})
        local box = construct("VerticalBox", tree)
        border:SetContent(box)
        label(tree, box, "OAR Mod Menu", 30, white, 0, 3)
        local session = label(tree, box, "Comprobando sesión...", 18, muted, 0, 16)
        local current = label(tree, box, "Mapa actual: --", 18, white, 0, 16)
        local page = label(tree, box, "Mapas de atraco", 18, muted, 0, 8)
        local lines = {}
        for i=1,7 do lines[i] = label(tree, box, "", 22, white, 0, 7) end
        label(tree, box, "F5 sección    F7 anterior    F8 siguiente", 18, muted, 12, 6)
        label(tree, box, "F9 aplicar    F6 cerrar", 18, white, 0, 12)
        local status = label(tree, box, "", 18, accent, 0, 0)
        status:SetAutoWrapText(true)
        widget:AddToViewport(9000)
        -- HitTestInvisible: the panel does not steal mouse clicks or game focus.
        widget:SetVisibility(4)
        return {widget=widget, session=session, current=current, page=page,
            lines=lines, status=status}
    end)
    if not ok then Menu.destroy({widget=widget}); error(result) end
    return result
end
function Menu.render(ui, state, context, maps)
    assert(ui and valid(ui.widget), "El menu ya no existe")
    local role = context.host and (context.online and "Anfitrión online" or "Individual") or "Cliente: controla el anfitrión"
    ui.session:SetText(FText(role))
    ui.current:SetText(FText("Mapa actual: " .. (context.currentName or context.level or "--")))
    local first = math.floor((state.selected-1)/7)*7+1
    ui.page:SetText(FText(string.format("%s · %d-%d / %d",state.sectionTitle or "Mapas",#maps>0 and first or 0,math.min(first+6,#maps),#maps)))
    for row=1,7 do
        local index = first+row-1
        local map = maps[index]
        local selected = index == state.selected
        ui.lines[row]:SetText(FText(map and ((selected and ">  " or "   ") .. map.name) or (#maps==0 and row==1 and "Sin objetos disponibles" or "")))
        set_color(ui.lines[row], selected and accent or white)
    end
    ui.status:SetText(FText(state.status or ""))
end
return Menu
