require 'rivenmods-common-v0-1-1'




function isTrainDebugLogged(train)
	return false
	-- return train.id == 21
end


function getLocomotiveCount(train)
	local count = 0
	for direction, locomotives in pairs(train.locomotives) do
		for idx, locomotive in ipairs(locomotives) do
			count = count + 1
		end
	end
	return count
end

function getCargoWagonCount(train)
	local count = 0
	for idx, wagon in ipairs(train.cargo_wagons) do
		count = count + 1
	end
	return count
end

function getFluidWagonCount(train)
	local count = 0
	for idx, wagon in ipairs(train.fluid_wagons) do
		count = count + 1
	end
	return count
end







function getEmptyTrainWeight(train)
	local weight = 0
	
	for direction, locomotives in pairs(train.locomotives) do
		for idx, locomotive in ipairs(locomotives) do
			weight = weight + prototypes.entity[locomotive.name].weight;
		end
	end
	
	for idx, wagon in ipairs(train.cargo_wagons) do
		weight = weight + prototypes.entity[wagon.name].weight;
	end

	for idx, wagon in ipairs(train.fluid_wagons) do
		weight = weight + prototypes.entity[wagon.name].weight;
	end
	
	return weight
end



function getTrainFuelStackUsage(train)
	local train_stack_used = 0.0;
	for direction, locomotives in pairs(train.locomotives) do
		for idx, locomotive in ipairs(locomotives) do
			local fuel_inventory = locomotive.get_fuel_inventory()
			if fuel_inventory ~= nil then -- mod: space elevator
				local fuel_contents = fuel_inventory.get_contents()
				if fuel_contents ~= nil then -- mod: space elevator
					for idy, icwq in ipairs(fuel_contents) do
						item_prototype = prototypes.item[icwq['name']]
						train_stack_used = train_stack_used + icwq['count'] / item_prototype.stack_size;
					end
				end
			end
		end
	end
	return train_stack_used;
end

function getTrainCargoStackUsage(train)
	local train_stack_used = 0.0;
	for idx, icwq in ipairs(train.get_contents()) do
		itemName = icwq['name']
		amount = icwq['count']
		local stackSize = prototypes.item[itemName].stack_size
		if script.active_mods['IntermodalContainers'] then
			local composition = getIntermodalContainerItemCompositionCached(itemName)			
			if composition ~= nil then
				stackSize = prototypes.item[composition.name].stack_size
				stackSize = stackSize * 2 -- the IntermodalContainers mod halves the stacksize, compensate
				train_stack_used = train_stack_used + amount * composition.amount / stackSize
			else
				train_stack_used = train_stack_used + amount / stackSize
			end			
		else
			train_stack_used = train_stack_used + amount / stackSize
		end
	end
	return train_stack_used;
end

function getTrainFluidWagonUsage(train)
	local train_stack_used = 0.0;
	for itemName, amount in pairs(train.get_fluid_contents()) do
		train_stack_used = train_stack_used + amount;
	end
	return train_stack_used;
end





function getIntermodalContainerItemComposition(itemName)
	if string.sub(itemName, 1, 3) ~= 'ic-' then
		return nil
	end
	
	for recipeName, recipe in pairs(prototypes.recipe) do
		if string.sub(recipeName, 1, 8) == 'ic-load-' then
			if recipe.main_product ~= nil and recipe.main_product.name == itemName then
				for idx, ingredient in pairs(recipe.ingredients) do
					if ingredient.name ~= 'ic-container' then
						return ingredient
					end
				end
			end
		end
	end
	
	return nil
end

function getIntermodalContainerItemCompositionCached(itemName)
	if storage.container2ingredient[itemName] ~= nil then
		return storage.container2ingredient[itemName]
	end
	
	storage.container2ingredient[itemName] = getIntermodalContainerItemComposition(itemName)
	return storage.container2ingredient[itemName]
end


remote.add_interface("train-speeds", {
	printTrainMass = function(trainId)
			if storage.trainId2train[trainId] == nil or storage.trainId2train[trainId].valid == false then
				game.print('Train #' .. trainId .. ' not found.')
				return
			end
			
			local train = storage.trainId2train[trainId]
			
			local emptyWeight = getEmptyTrainWeight(train)
			local fuelWeight  = getTrainFuelStackUsage(train)  * storage.settings.cargoStackWeight
			local cargoWeight = getTrainCargoStackUsage(train) * storage.settings.cargoStackWeight
			local fluidWeight = getTrainFluidWagonUsage(train) * storage.settings.fluidLiterWeight
			
			local totalWeight = emptyWeight + fuelWeight + cargoWeight + fluidWeight
			local totalWeightDisplay = tonumber(string.format("%.1f", totalWeight / 1000))
		
			game.print('Train #' .. trainId .. ' weighs ' .. totalWeightDisplay .. 'T ' ..
					'(carriages: ' .. math.floor(emptyWeight) .. 'kg, ' .. --
					' fuel: '      .. math.floor(fuelWeight)  .. 'kg, ' .. --
					' cargo: '     .. math.floor(cargoWeight) .. 'kg, ' .. --
					' fluid: '     .. math.floor(fluidWeight) .. 'kg)'
					)
	end
})



function getTrainMass(train)
	local emptyWeight = getEmptyTrainWeight(train);
	
	local cargoWeight = 0.0;
	cargoWeight = cargoWeight + getTrainFuelStackUsage(train)  * storage.settings.cargoStackWeight; -- default 250: 3 stacks  --> 750 kg
	cargoWeight = cargoWeight + getTrainCargoStackUsage(train) * storage.settings.cargoStackWeight; -- default 250: 40 stacks  --> 10K kg
	cargoWeight = cargoWeight + getTrainFluidWagonUsage(train) * storage.settings.fluidLiterWeight; -- default 0.4: 25K liters --> 10K kg
	
	if isTrainDebugLogged(train) then
		game.print('train weight: empty='  .. emptyWeight .. ', cargo=' .. cargoWeight);
	end
	
	local total = emptyWeight + cargoWeight;	
	--game.print('--- train id: ' .. train.id);
	--game.print('train weight: ' .. emptyWeight);
	--game.print('cargo weight: ' .. getTrainCargoStackUsage(train));
	--game.print('fluid weight: ' .. getTrainFluidWagonUsage(train));
	
	return total
end



function isTrainActuallyMini(train)
	for direction, locomotives in pairs(train.locomotives) do
		for idx, locomotive in ipairs(locomotives) do
			if locomotive.name == 'mini-locomotive' then
				return true
			end
		end
	end
	
	for idx, cargo_wagon in ipairs(train.cargo_wagons) do
		if cargo_wagon.name == 'mini-cargo-wagon' then
			return true
		end
	end
	
	for idx, fluid_wagon in ipairs(train.fluid_wagons) do
		if fluid_wagon.name == 'mini-fluid-wagon' then
			return true
		end
	end
	
	return false
end



function isTrainActuallyCargoShipInstead(train)
	for direction, locomotives in pairs(train.locomotives) do
		for idx, locomotive in ipairs(locomotives) do
			if locomotive.name == 'cargo_ship_engine'
			or locomotive.name == 'boat_engine' then
				return true
			end
		end
	end
	
	return false
end



function isTrainActuallyPoweredElectrically(train)
	for direction, locomotives in pairs(train.locomotives) do
		for idx, locomotive in ipairs(locomotives) do		
			if locomotive.prototype.name == 'bet-locomotive' then
				return true
			end
			
			if locomotive.prototype.name:find('ret-modular-locomotive') ~= nil then
				return true
			end
		end
	end
	
	return false
end



function getTrainForceMultiplier(train)
	local multiplier = 0;
	for direction, locomotives in pairs(train.locomotives) do
		for idx, locomotive in ipairs(locomotives) do
			multiplier = multiplier + --
				getLocomotiveEngineForceMultiplier(locomotive) * --
				getLocomotiveFuelForceMultiplier(locomotive) * --
				locomotive.get_health_ratio()
		end
	end
	return multiplier;
end

function getTrainForceMultiplier2(train)
	local combinedForce = 0;
	for direction, locomotives in pairs(train.locomotives) do
		for idx, locomotive in ipairs(locomotives) do
			combinedForce = combinedForce + --
				locomotive.prototype.get_max_energy_usage() * --
				locomotive.get_health_ratio()
		end
	end
	return combinedForce;
end



function getLocomotiveEngineForceMultiplier(locomotive)	
	-- energy-usage of 10000 (per tick) means 600kW (60fps x 10000 J)
	local n = locomotive.prototype.get_max_energy_usage() / 10000
	
	-- ships have exactly 3.3333 times too much power
	if locomotive.name == 'cargo_ship_engine'
	or locomotive.name == 'boat_engine' then
		n = n / 3.3333
	end

	-- make higher power trains disproportionally stronger
	-- to make up for old ratios
	return math.pow(n, 1.25)
end

--function getLocomotiveEngineForceMultiplier(locomotive)
--	local protoname = locomotive.name	
--	if protoname == 'locomotive' then
--		return 1.00 -- 600kW
--	elseif protoname == 'mini-locomotive' then
--		return 0.50 -- 313kW
--	elseif protoname == 'bob-locomotive-2' then
--		return 1.50 -- 750kW mk2
--	elseif protoname == 'bob-locomotive-3' then
--		return 2.00 -- 857kW mk3
--	elseif protoname == 'bob-armoured-locomotive' then
--		return 1.25 -- 750kW mk1
--	elseif protoname == 'bob-armoured-locomotive-2' then
--		return 1.50 -- 833kW mk2
--	else
--		return 1.00
--	end
--end



function getLocomotiveFuelForceMultiplier(locomotive)
	-- wood: 2M            --> 0.30
	-- coal: 4M            --> 0.60
	-- solid fuel: 12M     --> 1.08
	-- rocket fuel: 100M   --> 2.00
	-- nuclear: 1210M      --> 3.08

	local fuel_value = 0;
	if locomotive.burner ~= nil then -- mod: space elevator
		local burning_item = locomotive.burner.currently_burning
		if burning_item ~= nil then
			local burn_value = math.log(burning_item.name.fuel_value / 1000000) / math.log(10)
			fuel_value = fuel_value + burn_value
		end
	end
	return math.min(fuel_value, 4.00) -- to work around mods with insane fuel-values
end



function getTrainPullingForce(train)
	local absTrainSpeed = math.abs(getTrainSpeed(train));
	
	local pullingForce = storage.settings.locomotivePullforce  * 0.5;
	
	if isTrainActuallyPoweredElectrically(train) then
		-- low speed, high torque
		-- high speed, low torque
		local forceMultiplier = 1.25;
		local lowSpeedLimit = 33;
		local lowSpeedBonus = math.max(0, lowSpeedLimit - absTrainSpeed) / lowSpeedLimit;
		pullingForce = pullingForce * ((forceMultiplier - 1.0) + lowSpeedBonus);
	elseif isTrainActuallyCargoShipInstead(train) then
		local weight = getEmptyTrainWeight(train);
		if weight < 50000 then
			pullingForce = weight * 0.010
		else
			pullingForce = weight * 0.020
		end
	end
	
	if storage.settings.fuelTypeBasedAcceleration then
		pullingForce = pullingForce * getTrainForceMultiplier(train);
	else
		pullingForce = pullingForce * getLocomotiveCount(train);
	end
	
	if isTrainDebugLogged(train) then
		if isTrainActuallyCargoShipInstead(train) then
			game.print('ship FUEL');
		else
			if isTrainActuallyPoweredElectrically(train) then
				game.print('train ELEC');
			else
				game.print('train FUEL');
			end
		end
	end
	
	return pullingForce
end



function getTrainFrictionForce(train)
	local absTrainSpeed = math.abs(getTrainSpeed(train));
	
	local totalFriction = 0.0;
	
	if isTrainActuallyCargoShipInstead(train) then
		local mass = getTrainMass(train);
		local dragFriction  = storage.settings.trainWheelfrictionCoefficient * (25 + absTrainSpeed) * (mass / 100.0 / 1000.0);
		local waterFriction = 0.0 -- storage.settings.shipWaterfrictionCoefficient  *  math_pow2(absTrainSpeed);
		
		totalFriction = dragFriction + waterFriction;
	else
		local vehicleCount  = getLocomotiveCount(train) + getCargoWagonCount(train) + getFluidWagonCount(train);
		local wheelFriction = storage.settings.trainWheelfrictionCoefficient * absTrainSpeed * vehicleCount;
		local airFriction   = storage.settings.trainAirfrictionCoefficient   * math_pow2(absTrainSpeed);
		
		totalFriction = wheelFriction + airFriction;
	end
	
	return totalFriction;
end



function getTrainForce(train)
	local pullingForce  = getTrainPullingForce(train);		
	local totalFriction = getTrainFrictionForce(train);

	if isTrainDebugLogged(train) then
		game.print('train pulling: '  .. string.format("%.2f", pullingForce));
		game.print('train friction: ' .. string.format("%.2f", totalFriction));
		game.print('train power: '    .. string.format("%.2f", getTrainForceMultiplier2(train)));
	end

	return math.max(0.0, pullingForce - totalFriction);
end


function getTrainBrakingDistance(speed, maxDeceleration)
	return speed * speed / maxDeceleration * 0.5
end

function getTrainBrakingForce(train)
	return 20000.0 * getLocomotiveCount(train) +
			1000.0 * getCargoWagonCount(train) +
			1000.0 * getFluidWagonCount(train);
end


function adjustTrainAcceleration(train)
	local currSpeed = getTrainSpeed(train);
	if not storage.trainId2speed[train.id] then
		storage.trainId2speed[train.id] = currSpeed;
		return
	end
	
	if storage.trainId2accelForce[train.id] == nil then
		storage.trainId2accelForce[train.id] = getTrainForce(train);
	end
	
	if storage.trainId2mass[train.id] == nil then
		storage.trainId2mass[train.id] = getTrainMass(train);
	end
	
	if storage.trainId2brakeForce[train.id] == nil then
		storage.trainId2brakeForce[train.id] = getTrainBrakingForce(train);
	end
	
	local currSpeedSign = math_sign(currSpeed);	
	local prevSpeed = storage.trainId2speed[train.id];
	
	if currSpeedSign == -1 then
		currSpeed = currSpeed * currSpeedSign
		prevSpeed = prevSpeed * currSpeedSign
	end
	
	local acceleration = (currSpeed - prevSpeed) / 3.6 * GAME_FRAMERATE;
	local origAcceleration = acceleration;
	local didChange = 0;
	
	local trainForce = storage.trainId2accelForce[train.id] * 20.0;
	local trainMass  = storage.trainId2mass[train.id];	
	local maxAcceleration = trainForce / trainMass;
	
	if currSpeed > 0.1 and acceleration > maxAcceleration then
		acceleration = maxAcceleration;
		didChange = 1;
	end
	
	if train.has_path and currSpeed > 0.1 then
		local maxDeceleration = storage.trainId2brakeForce[train.id] / trainMass;
		local remainingDistance = train.path.total_distance - train.path.travelled_distance
		local minBrakingDistance = getTrainBrakingDistance(math.min(currSpeed, prevSpeed) / 3.6, maxDeceleration)		
		if minBrakingDistance > remainingDistance then
			acceleration = math.min(acceleration, -maxDeceleration)
			didChange = 1
		end
	end
	
	if didChange == 1 then
		currSpeed = prevSpeed + acceleration * 3.6 / GAME_FRAMERATE;
		setTrainSpeed(train, currSpeed * currSpeedSign);
	end
	
	if currSpeed > 0.01 and acceleration == maxAcceleration then
		renderTrainPuff(train, 0.2)
	elseif acceleration > 0.01 then
		renderTrainPuff(train, 0.1)
	end
	
	if isTrainDebugLogged(train) then
		for idx, wagon in ipairs(train.cargo_wagons) do
			game.print('name=' .. wagon.name);
		end
	
		game.print('train ' .. train.id .. ' acceleration: change=' .. didChange .. ' -> '
		   .. ' mass='      .. string.format("%.2f", trainMass)
		   .. ' cur.acc='   .. string.format("%.2f", acceleration     * GAME_FRAMERATE)
		   .. ' max.acc='   .. string.format("%.2f", maxAcceleration  * GAME_FRAMERATE)
		   .. ' orig.acc='  .. string.format("%.2f", origAcceleration * GAME_FRAMERATE)
		);
	end
	
	storage.trainId2speed[train.id] = getTrainSpeed(train);
end

function renderTrainPuff(train, rndmThreshold)
	for direction, locomotives in pairs(train.locomotives) do
		for idx, locomotive in ipairs(locomotives) do
			if storage.rndm() < rndmThreshold then
				renderLocomotivePuff(locomotive)
			end
		end
	end
end

function renderLocomotivePuff(locomotive)
	if locomotive.prototype.name ~= 'locomotive' then
		return
	end


	locomotive.surface.create_trivial_smoke({
		name='train-smoke',
		position={
			x=locomotive.position.x,
			y=locomotive.position.y - 1.5 - storage.rndm()
		}
	})
	
	if storage.rndm() < 0.1 then
		locomotive.surface.create_particle({
			name='spark-particle-debris',
			position=locomotive.position,
			movement={
				x=(storage.rndm()*2-1)*0.05,
				y=(storage.rndm()*2-1)*0.05
			},
			height=1,
			vertical_speed=0.05,
			frame_speed=1
		})
	end
end


function ensure_mod_context()
	ensure_global_rndm()
	ensure_global_mapping('trainId2train')
	ensure_global_mapping('trainId2mass')
	ensure_global_mapping('trainId2brakeForce')
	ensure_global_mapping('trainId2accelForce')
	ensure_global_mapping('trainId2speed')
	ensure_global_mapping('container2ingredient')
end



function refresh_mod_settings()
	storage.settings = {
		fuelTypeBasedAcceleration     = settings.global["modtrainspeeds-fuel-type-based-acceleration"].value,
		locomotivePullforce           = settings.global["modtrainspeeds-locomotive-pullforce"].value,
		cargoStackWeight              = settings.global["modtrainspeeds-cargo-stack-weight"].value,
		fluidLiterWeight              = settings.global["modtrainspeeds-fluid-liter-weight"].value,
		trainAirfrictionCoefficient   = settings.global["modtrainspeeds-train-airfriction-coefficient"].value,
		shipWaterfrictionCoefficient  = settings.global["modtrainspeeds-ship-waterfriction-coefficient"].value,
		trainWheelfrictionCoefficient = settings.global["modtrainspeeds-train-wheelfriction-coefficient"].value
	}
end

function needs_refresh_mod_settings()
	return storage.settings == nil
		or storage.settings.fuelTypeBasedAcceleration == nil
		or storage.settings.locomotivePullforce == nil
		or storage.settings.cargoStackWeight == nil
		or storage.settings.fluidLiterWeight == nil
		or storage.settings.trainAirfrictionCoefficient == nil
		or storage.settings.shipWaterfrictionCoefficient == nil
		or storage.settings.trainWheelfrictionCoefficient == nil
end



script.on_event({defines.events.on_tick},
	function (e)
		ensure_mod_context();
		
		if needs_refresh_mod_settings() or e.tick % GAME_FRAMERATE == 0 then
			refresh_mod_settings();
		end
		
		
		local trainDiscoveryInterval = 120;
		local measureWeightInterval = 120;
		local measureForceInterval = 30;
		local adjustInterval = 1;
		
		if (e.tick % trainDiscoveryInterval == 0) then
			findTrains();
		end
		
		for trainId, train in pairs(storage.trainId2train) do
			if train.valid then
				if (e.tick % measureWeightInterval == trainId % measureWeightInterval) then
					storage.trainId2mass[trainId]  = getTrainMass(train);
				end
				
				if (e.tick % measureForceInterval == trainId % measureForceInterval) then
					storage.trainId2accelForce[train.id] = getTrainForce(train);
					storage.trainId2brakeForce[train.id] = getTrainBrakingForce(train);
				end
			end
		end
		
		for trainId, train in pairs(storage.trainId2train) do
			if train.valid then
				if (e.tick % adjustInterval == trainId % adjustInterval) then
					if train.state == defines.train_state.on_the_path
					or train.state == defines.train_state.manual_control
					or train.state == defines.train_state.arrive_station
					or train.state == defines.train_state.arrive_signal then
						adjustTrainAcceleration(train);
					end
				end
			end
		end
	end
)




