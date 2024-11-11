local vanilla_loc = data.raw["locomotive"]["locomotive"]

if vanilla_loc ~= nil then
	-- vanilla_loc.energy_source.smoke = {}
	
	for idx, smoke_source in ipairs(vanilla_loc.energy_source.smoke) do
		smoke_source.frequency = 0
	end
end