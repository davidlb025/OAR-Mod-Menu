-- Verified against Steam build 26319483 (2026-10-31).
-- Only playable heists; asset demonstration and development maps are excluded.
local root = "/Game/Maps/HeistMaps/"
local shop = "/Game/Maps/Menu/BP/Shop/Maps/"
local rows = {
    {"Jewellery Store", "JewelleryStore", "JewelleryStore"},
    {"Pegasus Museum of Art", "Museum_night", "Museum"},
    {"Liberty Hawk Bank", "Small_Bank", "Small_Bank"},
    {"Lundenburg Liquors", "Map_WineStore", "WineShop"},
    {"Orbital Bank", "Knightsbridge_day", "OrbitalBank"},
    {"Esco Bar", "Bar_drugs", "EscoBar"},
    {"FIA Offices", "CIA_Base", "FIA"},
    {"Rodman Research Facility", "Map_Sciencelab", "Sciencelab"},
    {"Black Diamond Casino", "Casino", "BlackDiamondCasino"},
    {"Mansion", "Mansion_Car", "CarMansion"},
    {"Harbour", "Map_Harbour", "Harbour"},
    {"Postal Office", "Map_PostalOffice", "PostOffice"},
    {"Data Center", "Map_AIDataCenter", "Datacenter"},
    {"Haunted Mansion", "Halloween_Mansion", "Halloween"},
}
local maps = {}
for _, row in ipairs(rows) do
    local asset = "ShopItem_Map_" .. row[3]
    maps[#maps + 1] = {
        name = row[1], filename = row[2], package = root .. row[2],
        class = shop .. asset .. "." .. asset .. "_C",
    }
end
return maps
