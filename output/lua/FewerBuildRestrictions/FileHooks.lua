local files = {
	{"BuildingMixin", "post"},
	{"BuildUtility", "replace"},
	{"Commander_GhostStructure", "replace"},
	{"ConstructMixin", "post"},
	{"GUIResourceDisplay", "replace"},
	{"PlayingTeam", "post"},
	{"ScriptActor", "post"},
	{"Shift", "post"},
	{"TeleportMixin", "post"},
	{"UnitStatusMixin", "post"}
};

for _, v in ipairs(files) do
	assert(ModLoader.SetupFileHook("lua/" .. v[1] .. ".lua", "lua/FewerBuildRestrictions/" .. v[1] .. ".lua", v[2]));
end

assert(ModLoader.SetupFileHook("lua/Hud/Commander/GhostModel.lua", "lua/FewerBuildRestrictions/GhostModel.lua", "post"));
--assert(ModLoader.SetupFileHook("lua/ConstructMixin.lua", "lua/FewerBuildRestrictions/TestFile.lua", "post"));
--ModLoader.SetupFileHook("lua/Welder.lua", "lua/FewerBuildRestrictions/Welder.lua", "post"); -- Not needed currently
