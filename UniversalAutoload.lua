-- ============================================================= --
-- Universal Autoload MOD - SPECIALISATION
-- ============================================================= --
UniversalAutoload = {}

UniversalAutoload.name = g_currentModName
UniversalAutoload.path = g_currentModDirectory
UniversalAutoload.specName = ("spec_%s.universalAutoload"):format(g_currentModName)
UniversalAutoload.globalKey = "universalAutoload"
UniversalAutoload.savegameStateKey = ".currentState"
UniversalAutoload.savegameConfigKey = ".configuration"
UniversalAutoload.postLoadKey = ".FS25_UniversalAutoload.universalAutoload.currentState"
UniversalAutoload.savegameStateSchemaKey = "vehicles.vehicle(?).FS25_UniversalAutoload.universalAutoload.currentState"
UniversalAutoload.savegameConfigSchemaKey = "vehicles.vehicle(?).FS25_UniversalAutoload.universalAutoload.configuration"
UniversalAutoload.vehicleKey = "universalAutoload.vehicleConfigurations.vehicle(%d)"
UniversalAutoload.vehicleConfigKey = UniversalAutoload.vehicleKey .. ".configuration(%d)"
UniversalAutoload.vehicleSchemaKey = "universalAutoload.vehicleConfigurations.vehicle(?)"
UniversalAutoload.containerKey = "universalAutoload.containerConfigurations.container(%d)"
UniversalAutoload.containerSchemaKey = "universalAutoload.containerConfigurations.container(?)"

UniversalAutoload.OBJECTS_LOOKUP = {}
UniversalAutoload.VEHICLES_LOOKUP = {}
UniversalAutoload.SPLITSHAPES_LOOKUP = {}

UniversalAutoload.ALL = "ALL"
UniversalAutoload.SPACING = 0.0
UniversalAutoload.DELAY_TIME = 200
UniversalAutoload.LOG_SPACE = 0.25
UniversalAutoload.MAX_LAYER_COUNT = 20
UniversalAutoload.ROTATED_BALE_FACTOR = 0.85355339

UniversalAutoload.showLoading = false

local debugKeys = false
local debugSchema = false
local debugConsole = false
local debugLoading = false
local debugPallets = false
local debugVehicles = false
local debugSpecial = false

-- local disablePhysicsAfterLoading = true

UniversalAutoload.MASK = {}
UniversalAutoload.MASK.object = CollisionFlag.VEHICLE + CollisionFlag.DYNAMIC_OBJECT --+ CollisionFlag.TREE
UniversalAutoload.MASK.everything = UniversalAutoload.MASK.object + CollisionFlag.STATIC_OBJECT + CollisionFlag.PLAYER


-- EVENTS
source(g_currentModDirectory.."events/CycleContainerEvent.lua")
source(g_currentModDirectory.."events/CycleMaterialEvent.lua")
source(g_currentModDirectory.."events/PlayerTriggerEvent.lua")
source(g_currentModDirectory.."events/RaiseActiveEvent.lua")
source(g_currentModDirectory.."events/ResetLoadingEvent.lua")
source(g_currentModDirectory.."events/SetBaleCollectionModeEvent.lua")
source(g_currentModDirectory.."events/SetContainerTypeEvent.lua")
source(g_currentModDirectory.."events/SetFilterEvent.lua")
source(g_currentModDirectory.."events/SetHorizontalLoadingEvent.lua")
source(g_currentModDirectory.."events/SetLoadsideEvent.lua")
source(g_currentModDirectory.."events/SetMaterialTypeEvent.lua")
source(g_currentModDirectory.."events/SetTipsideEvent.lua")
source(g_currentModDirectory.."events/StartLoadingEvent.lua")
source(g_currentModDirectory.."events/StopLoadingEvent.lua")
source(g_currentModDirectory.."events/UnloadingEvent.lua")
source(g_currentModDirectory.."events/UpdateActionEvents.lua")
source(g_currentModDirectory.."events/WarningMessageEvent.lua")


-- REQUIRED SPECIALISATION FUNCTIONS
function UniversalAutoload.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(TensionBelts, specializations)
end
--
function UniversalAutoload.initSpecialization()
	local globalKey = UniversalAutoload.globalKey

	g_vehicleConfigurationManager:addConfigurationType("universalAutoload", g_i18n:getText("configuration_universalAutoload"), globalKey, "autoload", nil, nil, ConfigurationUtil.SELECTOR_MULTIOPTION)
	
	local function registerConfig(schema, rootKey, tbl, parentKey)
		parentKey = parentKey or ""
		for _, v in pairs(tbl) do
			if type(v) == "table" then
				local currentKey = parentKey .. (v.key or "")
				if v.valueType then
					schema:register(XMLValueType[v.valueType], rootKey .. currentKey, v.description or "", v.default)
					if debugSchema then print("  " .. rootKey .. currentKey) end
				end
				if v.data then
					registerConfig(schema, rootKey, v.data, currentKey)
				end
			end
		end
	end

	UniversalAutoload.xmlSchema = XMLSchema.new(globalKey)
	print("*** REGISTER XML SCHEMAS ***")
	if debugSchema then print("GLOBAL_DEFAULTS:") end
	registerConfig(UniversalAutoload.xmlSchema, UniversalAutoload.globalKey, UniversalAutoload.GLOBAL_DEFAULTS)
	if debugSchema then print("CONTAINER_DEFAULTS:") end
	registerConfig(UniversalAutoload.xmlSchema, UniversalAutoload.containerKey, UniversalAutoload.CONTAINER_DEFAULTS)
	if debugSchema then print("VEHICLE_DEFAULTS:") end
	registerConfig(UniversalAutoload.xmlSchema, UniversalAutoload.vehicleSchemaKey, UniversalAutoload.VEHICLE_DEFAULTS)
	if debugSchema then print("SAVEGAME_STATE_DEFAULTS:") end
	registerConfig(Vehicle.xmlSchemaSavegame, UniversalAutoload.savegameStateSchemaKey, UniversalAutoload.SAVEGAME_STATE_DEFAULTS)
	if debugSchema then print("SAVEGAME_CONFIG_DEFAULTS:") end
	registerConfig(Vehicle.xmlSchemaSavegame, UniversalAutoload.savegameConfigSchemaKey, UniversalAutoload.CONFIG_DEFAULTS)

end
--
function UniversalAutoload.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "ualGetIsMoving", UniversalAutoload.ualGetIsMoving)
	SpecializationUtil.registerFunction(vehicleType, "ualGetIsFilled", UniversalAutoload.ualGetIsFilled)
	SpecializationUtil.registerFunction(vehicleType, "ualGetIsCovered", UniversalAutoload.ualGetIsCovered)
	SpecializationUtil.registerFunction(vehicleType, "ualGetIsFolding", UniversalAutoload.ualGetIsFolding)
	SpecializationUtil.registerFunction(vehicleType, "ualOnDeleteVehicle_Callback", UniversalAutoload.ualOnDeleteVehicle_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualOnDeleteLoadedObject_Callback", UniversalAutoload.ualOnDeleteLoadedObject_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualOnDeleteAvailableObject_Callback", UniversalAutoload.ualOnDeleteAvailableObject_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualOnDeleteAutoLoadingObject_Callback", UniversalAutoload.ualOnDeleteAutoLoadingObject_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualTestLocation_Callback", UniversalAutoload.ualTestLocation_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualTestUnloadLocation_Callback", UniversalAutoload.ualTestUnloadLocation_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualTestLocationOverlap_Callback", UniversalAutoload.ualTestLocationOverlap_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualPlayerTrigger_Callback", UniversalAutoload.ualPlayerTrigger_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualLoadingTrigger_Callback", UniversalAutoload.ualLoadingTrigger_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualUnloadingTrigger_Callback", UniversalAutoload.ualUnloadingTrigger_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualAutoLoadingTrigger_Callback", UniversalAutoload.ualAutoLoadingTrigger_Callback)
	-- --- Courseplay functions
	SpecializationUtil.registerFunction(vehicleType, "ualHasLoadedBales", UniversalAutoload.ualHasLoadedBales)
	SpecializationUtil.registerFunction(vehicleType, "ualIsFull", UniversalAutoload.ualIsFull)
	SpecializationUtil.registerFunction(vehicleType, "ualGetLoadedBales", UniversalAutoload.ualGetLoadedBales)
	SpecializationUtil.registerFunction(vehicleType, "ualIsObjectLoadable", UniversalAutoload.ualIsObjectLoadable)
	-- --- Autodrive functions
	SpecializationUtil.registerFunction(vehicleType, "ualStartLoad", UniversalAutoload.ualStartLoad)
	SpecializationUtil.registerFunction(vehicleType, "ualStopLoad", UniversalAutoload.ualStopLoad)
	SpecializationUtil.registerFunction(vehicleType, "ualUnload", UniversalAutoload.ualUnload)
	SpecializationUtil.registerFunction(vehicleType, "ualSetUnloadPosition", UniversalAutoload.ualSetUnloadPosition)
	SpecializationUtil.registerFunction(vehicleType, "ualGetFillUnitCapacity", UniversalAutoload.ualGetFillUnitCapacity)
	SpecializationUtil.registerFunction(vehicleType, "ualGetFillUnitFillLevel", UniversalAutoload.ualGetFillUnitFillLevel)
	SpecializationUtil.registerFunction(vehicleType, "ualGetFillUnitFreeCapacity", UniversalAutoload.ualGetFillUnitFreeCapacity)
end
--
function UniversalAutoload.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getFullName", UniversalAutoload.ualGetFullName)
	-- SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanStartFieldWork", UniversalAutoload.getCanStartFieldWork)
	-- SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanImplementBeUsedForAI", UniversalAutoload.getCanImplementBeUsedForAI)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getDynamicMountTimeToMount", UniversalAutoload.getDynamicMountTimeToMount)
end

-- function UniversalAutoload:getCanStartFieldWork(superFunc)
	-- local spec = self.spec_universalAutoload
	-- if spec and spec.isAutoloadAvailable and spec.baleCollectionMode then
		-- if debugSpecial then print("getCanStartFieldWork...") end
		-- --return true
	-- end
	-- return superFunc(self)
-- end
-- function UniversalAutoload:getCanImplementBeUsedForAI(superFunc)
	-- local spec = self.spec_universalAutoload
	-- if spec and spec.isAutoloadAvailable then
		-- if debugSpecial then print("*** getCanImplementBeUsedForAI ***") end
		-- --DebugUtil.printTableRecursively(self.spec_aiImplement, "--", 0, 1)
		-- --return true
	-- end
	-- return superFunc(self)
-- end
--
function UniversalAutoload:getDynamicMountTimeToMount(superFunc)
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		return superFunc(self)
	end
	return UniversalAutoload.getIsLoadingVehicleAllowed(self) and -1 or math.huge
end
--
function UniversalAutoload:ualGetFullName(superFunc)
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		return superFunc(self)
	end
	return superFunc(self).." - UAL #"..tostring(self.rootNode)
end

function UniversalAutoload.registerEventListeners(vehicleType)
	print("  Register vehicle type: " .. vehicleType.name)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", UniversalAutoload)
	
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateEnd", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onDraw", UniversalAutoload)
	
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onPreDelete", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", UniversalAutoload)
	
	SpecializationUtil.registerEventListener(vehicleType, "onActivate", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onDeactivate", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onFoldStateChanged", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onMovingToolChanged", UniversalAutoload)

	--- Courseplay event listeners.
	SpecializationUtil.registerEventListener(vehicleType, "onAIImplementStart", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onAIImplementEnd", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onAIFieldWorkerStart", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onAIFieldWorkerEnd", UniversalAutoload)
end

function UniversalAutoload.removeEventListeners(vehicleType)
	-- print("REMOVE EVENT LISTENERS")
	
	SpecializationUtil.removeEventListener(vehicleType, "onLoad", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onPostLoad", UniversalAutoload)
	
	SpecializationUtil.removeEventListener(vehicleType, "onUpdate", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onUpdateTick", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onUpdateEnd", UniversalAutoload)	
	SpecializationUtil.removeEventListener(vehicleType, "onDraw", UniversalAutoload)
	
	SpecializationUtil.removeEventListener(vehicleType, "onDelete", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onPreDelete", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onRegisterActionEvents", UniversalAutoload)

	SpecializationUtil.removeEventListener(vehicleType, "onActivate", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onDeactivate", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onFoldStateChanged", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onMovingToolChanged", UniversalAutoload)
	
	SpecializationUtil.removeEventListener(vehicleType, "onAIImplementStart", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onAIImplementEnd", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onAIFieldWorkerStart", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onAIFieldWorkerEnd", UniversalAutoload)
end

-- -- ACTION EVENT FUNCTIONS
function UniversalAutoload:clearActionEvents()
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable and spec.actionEvents then
		self:clearActionEventsTable(spec.actionEvents)
	end
end
-- --
function UniversalAutoload:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient and g_dedicatedServer==nil then
		local spec = self.spec_universalAutoload
		UniversalAutoload.clearActionEvents(self)

		if isActiveForInput then
			-- print("onRegisterActionEvents: "..self:getFullName())
			UniversalAutoload.updateActionEventKeys(self)
		end
	end
end
-- --
function UniversalAutoload:updateActionEventKeys()
	if self.isClient and g_dedicatedServer==nil then
		local spec = self.spec_universalAutoload

		if spec and spec.isAutoloadAvailable and spec.actionEvents and next(spec.actionEvents) == nil then
			if debugKeys then print("updateActionEventKeys: "..self:getFullName()) end
			local actions = UniversalAutoload.ACTIONS
			local ignoreCollisions = true
			
			local topPriority = GS_PRIO_HIGH
			local midPriority = GS_PRIO_NORMAL
			local lowPriority = GS_PRIO_LOW
			if UniversalAutoload.highPriority == true then
				topPriority = GS_PRIO_VERY_HIGH
				midPriority = GS_PRIO_HIGH
				lowPriority = GS_PRIO_NORMAL
			end

			local valid, actionEventId = self:addActionEvent(spec.actionEvents, actions.UNLOAD_ALL, self, UniversalAutoload.actionEventUnloadAll, false, true, false, true, nil, nil, ignoreCollisions, true)
			g_inputBinding:setActionEventTextPriority(actionEventId, topPriority)
			spec.unloadAllActionEventId = actionEventId
			if debugKeys then print("  UNLOAD_ALL: "..tostring(valid)) end
			spec.updateToggleLoading = true
			
			if not UniversalAutoload.manualLoadingOnly then
				
				if spec.isBaleTrailer then
					local valid, actionEventId = self:addActionEvent(spec.actionEvents, actions.TOGGLE_BALE_COLLECTION, self, UniversalAutoload.actionEventToggleBaleCollectionMode, false, true, false, true, nil, nil, ignoreCollisions, true)
					g_inputBinding:setActionEventTextPriority(actionEventId, topPriority)
					spec.toggleBaleCollectionModeEventId = actionEventId
					if debugKeys then print("  TOGGLE_BALE_COLLECTION: "..tostring(valid)) end
				end
				
				local valid, actionEventId = self:addActionEvent(spec.actionEvents, actions.TOGGLE_LOADING, self, UniversalAutoload.actionEventToggleLoading, false, true, false, true, nil, nil, ignoreCollisions, true)
				g_inputBinding:setActionEventTextPriority(actionEventId, topPriority)
				spec.toggleLoadingActionEventId = actionEventId
				if debugKeys then print("  TOGGLE_LOADING: "..tostring(valid)) end
				
				local startLoadingText = g_i18n:getText("universalAutoload_startLoading")
				g_inputBinding:setActionEventText(spec.toggleLoadingActionEventId, startLoadingText)
				g_inputBinding:setActionEventActive(spec.toggleLoadingActionEventId, true)
				g_inputBinding:setActionEventTextVisibility(spec.toggleLoadingActionEventId, true)

				if not spec.isLogTrailer then
					local valid, actionEventId = self:addActionEvent(spec.actionEvents, actions.TOGGLE_FILTER, self, UniversalAutoload.actionEventToggleFilter, false, true, false, true, nil, nil, ignoreCollisions, true)
					g_inputBinding:setActionEventTextPriority(actionEventId, midPriority)
					spec.toggleLoadingFilterActionEventId = actionEventId
					if debugKeys then print("  TOGGLE_FILTER: "..tostring(valid)) end
					spec.updateToggleFilter = true
				end
			end
			
			if not spec.isLogTrailer then
				local valid, actionEventId = self:addActionEvent(spec.actionEvents, actions.TOGGLE_HORIZONTAL, self, UniversalAutoload.actionEventToggleHorizontalLoading, false, true, false, true, nil, nil, ignoreCollisions, true)
				g_inputBinding:setActionEventTextPriority(actionEventId, midPriority)
				spec.toggleHorizontalLoadingActionEventId = actionEventId
				if debugKeys then print("  TOGGLE_HORIZONTAL: "..tostring(valid)) end
				spec.updateHorizontalLoading = true
				
				local valid, actionEventId = self:addActionEvent(spec.actionEvents, actions.CYCLE_MATERIAL_FW, self, UniversalAutoload.actionEventCycleMaterial_FW, false, true, false, true, nil, nil, ignoreCollisions, true)
				g_inputBinding:setActionEventTextPriority(actionEventId, midPriority)
				spec.cycleMaterialActionEventId = actionEventId
				if debugKeys then print("  CYCLE_MATERIAL_FW: "..tostring(valid)) end

				local valid, actionEventId = self:addActionEvent(spec.actionEvents, actions.CYCLE_MATERIAL_BW, self, UniversalAutoload.actionEventCycleMaterial_BW, false, true, false, true, nil, nil, ignoreCollisions, true)
				g_inputBinding:setActionEventTextPriority(actionEventId, lowPriority)
				g_inputBinding:setActionEventTextVisibility(actionEventId, false)
				if debugKeys then print("  CYCLE_MATERIAL_BW: "..tostring(valid)) end
				
				local valid, actionEventId = self:addActionEvent(spec.actionEvents, actions.SELECT_ALL_MATERIALS, self, UniversalAutoload.actionEventSelectAllMaterials, false, true, false, true, nil, nil, ignoreCollisions, true)
				g_inputBinding:setActionEventTextPriority(actionEventId, midPriority)
				g_inputBinding:setActionEventTextVisibility(actionEventId, false)
				if debugKeys then print("  SELECT_ALL_MATERIALS: "..tostring(valid)) end
				spec.updateCycleMaterial = true
				
				if UniversalAutoload.chatKeyConflict ~= true then
					local valid, actionEventId = self:addActionEvent(spec.actionEvents, actions.CYCLE_CONTAINER_FW, self, UniversalAutoload.actionEventCycleContainer_FW, false, true, false, true, nil, nil, ignoreCollisions, true)
					g_inputBinding:setActionEventTextPriority(actionEventId, midPriority)
					spec.cycleContainerActionEventId = actionEventId
					if debugKeys then print("  CYCLE_CONTAINER_FW: "..tostring(valid)) end

					local valid, actionEventId = self:addActionEvent(spec.actionEvents, actions.CYCLE_CONTAINER_BW, self, UniversalAutoload.actionEventCycleContainer_BW, false, true, false, true, nil, nil, ignoreCollisions, true)
					g_inputBinding:setActionEventTextPriority(actionEventId, lowPriority)
					g_inputBinding:setActionEventTextVisibility(actionEventId, false)
					if debugKeys then print("  CYCLE_CONTAINER_BW: "..tostring(valid)) end

					local valid, actionEventId = self:addActionEvent(spec.actionEvents, actions.SELECT_ALL_CONTAINERS, self, UniversalAutoload.actionEventSelectAllContainers, false, true, false, true, nil, nil, ignoreCollisions, true)
					g_inputBinding:setActionEventTextPriority(actionEventId, midPriority)
					g_inputBinding:setActionEventTextVisibility(actionEventId, false)
					if debugKeys then print("  SELECT_ALL_CONTAINERS: "..tostring(valid)) end
					spec.updateCycleContainer = true
				end
			
			end

			if not spec.isCurtainTrailer and not spec.rearUnloadingOnly and not spec.frontUnloadingOnly then
				local valid, actionEventId = self:addActionEvent(spec.actionEvents, actions.TOGGLE_TIPSIDE, self, UniversalAutoload.actionEventToggleTipside, false, true, false, true, nil, nil, ignoreCollisions, true)
				g_inputBinding:setActionEventTextPriority(actionEventId, midPriority)
				spec.toggleTipsideActionEventId = actionEventId
				if debugKeys then print("  TOGGLE_TIPSIDE: "..tostring(valid)) end
				spec.updateToggleTipside = true
			end
			
			-- if g_localPlayer.isControlled then
			
				-- if not g_currentMission.missionDynamicInfo.isMultiplayer and self.spec_tensionBelts then
					-- local valid, actionEventId = self:addActionEvent(spec.actionEvents, actions.TOGGLE_BELTS, self, UniversalAutoload.actionEventToggleBelts, false, true, false, true, nil, nil, ignoreCollisions, true)
					-- g_inputBinding:setActionEventTextPriority(actionEventId, midPriority)
					-- spec.toggleBeltsActionEventId = actionEventId
					-- if debugKeys then print("  TOGGLE_BELTS: "..tostring(valid)) end
					-- spec.updateToggleBelts = true
				-- end
				
				-- if spec.isCurtainTrailer or spec.isBoxTrailer then
					-- local valid, actionEventId = self:addActionEvent(spec.actionEvents, actions.TOGGLE_DOOR, self, UniversalAutoload.actionEventToggleDoor, false, true, false, true, nil, nil, ignoreCollisions, true)
					-- g_inputBinding:setActionEventTextPriority(actionEventId, midPriority)
					-- spec.toggleDoorActionEventId = actionEventId
					-- if debugKeys then print("  TOGGLE_DOOR: "..tostring(valid)) end
					-- spec.updateToggleDoor = true
				-- end
					
				-- if spec.isCurtainTrailer then
					-- local valid, actionEventId = self:addActionEvent(spec.actionEvents, actions.TOGGLE_CURTAIN, self, UniversalAutoload.actionEventToggleCurtain, false, true, false, true, nil, nil, ignoreCollisions, true)
					-- g_inputBinding:setActionEventTextPriority(actionEventId, midPriority)
					-- spec.toggleCurtainActionEventId = actionEventId
					-- if debugKeys then print("  TOGGLE_CURTAIN: "..tostring(valid)) end
					-- spec.updateToggleCurtain = true
				-- end
				
			-- end
			
			if self.isServer then
				local valid, actionEventId = self:addActionEvent(spec.actionEvents, actions.TOGGLE_SHOW_LOADING, self, UniversalAutoload.actionEventToggleShowLoading, false, true, false, true, nil, nil, ignoreCollisions, true)
				g_inputBinding:setActionEventTextPriority(actionEventId, lowPriority)
				-- spec.ToggleShowLoadingActionEventId = actionEventId
				if debugKeys then print("  TOGGLE_SHOW_LOADING: "..tostring(valid)) end
				
				local valid, actionEventId = self:addActionEvent(spec.actionEvents, actions.TOGGLE_SHOW_DEBUG, self, UniversalAutoload.actionEventToggleShowDebug, false, true, false, true, nil, nil, ignoreCollisions, true)
				g_inputBinding:setActionEventTextPriority(actionEventId, lowPriority)
				-- spec.ToggleShowLoadingActionEventId = actionEventId
				if debugKeys then print("  TOGGLE_SHOW_DEBUG: "..tostring(valid)) end
			end

			if debugKeys then print("*** updateActionEventKeys ***") end
		end
	end
end
--
function UniversalAutoload:updateToggleBeltsActionEvent()
	--if debugKeys then print("updateToggleBeltsActionEvent") end
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and spec.toggleBeltsActionEventId then

		g_inputBinding:setActionEventActive(spec.toggleBeltsActionEventId, true)
		
		local tensionBeltsText
		if self.spec_tensionBelts.areBeltsFasten then
			tensionBeltsText = g_i18n:getText("action_unfastenTensionBelts")
		else
			tensionBeltsText = g_i18n:getText("action_fastenTensionBelts")
		end
		g_inputBinding:setActionEventText(spec.toggleBeltsActionEventId, tensionBeltsText)
		g_inputBinding:setActionEventTextVisibility(spec.toggleBeltsActionEventId, true)

	end
end
--
function UniversalAutoload:updateToggleDoorActionEvent()
	--if debugKeys then print("updateToggleDoorActionEvent") end
	local spec = self.spec_universalAutoload
	local foldable = self.spec_foldable

	if g_localPlayer.isControlled then
		if spec and spec.isAutoloadAvailable and self.spec_foldable and (spec.isCurtainTrailer or spec.isBoxTrailer) then
			local direction = self:getToggledFoldDirection()

			local toggleDoorText = ""
			if direction == foldable.turnOnFoldDirection then
				toggleDoorText = foldable.negDirectionText
			else
				toggleDoorText = foldable.posDirectionText
			end

			g_inputBinding:setActionEventText(spec.toggleDoorActionEventId, toggleDoorText)
			g_inputBinding:setActionEventTextVisibility(spec.toggleDoorActionEventId, true)
		end
	else
		if spec and spec.isAutoloadAvailable and self.spec_foldable and self.isClient then
			Foldable.updateActionEventFold(self)
		end
	end
end
--
function UniversalAutoload:updateToggleCurtainActionEvent()
	--if debugKeys then print("updateToggleCurtainActionEvent") end
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and g_localPlayer.isControlled then
		if self.spec_trailer and spec.isCurtainTrailer then
			local trailer = self.spec_trailer
			local tipSide = trailer.tipSides[trailer.preferedTipSideIndex]
			
			if tipSide then
				local toggleCurtainText = nil
				local tipState = self:getTipState()
				if tipState == Trailer.TIPSTATE_CLOSED or tipState == Trailer.TIPSTATE_CLOSING then
					toggleCurtainText = tipSide.manualTipToggleActionTextPos
				else
					toggleCurtainText = tipSide.manualTipToggleActionTextNeg
				end
				g_inputBinding:setActionEventText(spec.toggleCurtainActionEventId, toggleCurtainText)
				g_inputBinding:setActionEventTextVisibility(spec.toggleCurtainActionEventId, true)
			end
		end
	end
end

--
function UniversalAutoload:updateCycleMaterialActionEvent()
	--if debugKeys then print("updateCycleMaterialActionEvent") end
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and spec.cycleMaterialActionEventId then
		-- Material Type: ALL / <MATERIAL>
		if not spec.isLoading then
			local materialTypeText = g_i18n:getText("universalAutoload_materialType")..": "..UniversalAutoload.getSelectedMaterialText(self)
			g_inputBinding:setActionEventText(spec.cycleMaterialActionEventId, materialTypeText)
			g_inputBinding:setActionEventTextVisibility(spec.cycleMaterialActionEventId, true)
		end

	end
end
--
function UniversalAutoload:updateCycleContainerActionEvent()
	--if debugKeys then print("updateCycleContainerActionEvent") end
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and spec.cycleContainerActionEventId then
		-- Container Type: ALL / <PALLET_TYPE>
		if not spec.isLoading then
			local containerTypeText = g_i18n:getText("universalAutoload_containerType")..": "..UniversalAutoload.getSelectedContainerText(self)
			g_inputBinding:setActionEventText(spec.cycleContainerActionEventId, containerTypeText)
			g_inputBinding:setActionEventTextVisibility(spec.cycleContainerActionEventId, true)
		end
	end
end
--
function UniversalAutoload:updateToggleFilterActionEvent()
	--if debugKeys then print("updateToggleFilterActionEvent") end
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and spec.toggleLoadingFilterActionEventId then
		-- Loading Filter: ANY / FULL ONLY
		local loadingFilterText
		if spec.currentLoadingFilter then
			loadingFilterText = g_i18n:getText("universalAutoload_loadingFilter")..": "..g_i18n:getText("universalAutoload_fullOnly")
		else
			loadingFilterText = g_i18n:getText("universalAutoload_loadingFilter")..": "..g_i18n:getText("universalAutoload_loadAny")
		end
		g_inputBinding:setActionEventText(spec.toggleLoadingFilterActionEventId, loadingFilterText)
		g_inputBinding:setActionEventTextVisibility(spec.toggleLoadingFilterActionEventId, true)
	end
end
--
function UniversalAutoload:updateHorizontalLoadingActionEvent()
	--if debugKeys then print("updateHorizontalLoadingActionEvent") end
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and spec.toggleHorizontalLoadingActionEventId then
		-- Loading Filter: ANY / FULL ONLY
		local horizontalLoadingText
		if spec.useHorizontalLoading then
			horizontalLoadingText = g_i18n:getText("universalAutoload_loadingMethod")..": "..g_i18n:getText("universalAutoload_layer")
		else
			horizontalLoadingText = g_i18n:getText("universalAutoload_loadingMethod")..": "..g_i18n:getText("universalAutoload_stack")
		end
		g_inputBinding:setActionEventText(spec.toggleHorizontalLoadingActionEventId, horizontalLoadingText)
		g_inputBinding:setActionEventTextVisibility(spec.toggleHorizontalLoadingActionEventId, true)
	end
end
--
function UniversalAutoload:updateToggleTipsideActionEvent()
	--if debugKeys then print("updateToggleTipsideActionEvent") end
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and spec.toggleTipsideActionEventId then
		-- Tipside: NONE/BOTH/LEFT/RIGHT/
		if spec.currentTipside == "none" then
			g_inputBinding:setActionEventActive(spec.toggleTipsideActionEventId, false)
		else
			local tipsideText = g_i18n:getText("universalAutoload_tipside")..": "..g_i18n:getText("universalAutoload_"..(spec.currentTipside or "none"))
			g_inputBinding:setActionEventText(spec.toggleTipsideActionEventId, tipsideText)
			g_inputBinding:setActionEventTextVisibility(spec.toggleTipsideActionEventId, true)
		end
	end
end
--
function UniversalAutoload:updateToggleLoadingActionEvent()
	--if debugKeys then print("updateToggleLoadingActionEvent") end
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and spec.toggleBaleCollectionModeEventId then
		-- Activate/Deactivate the AUTO-BALE key binding
		if spec.baleCollectionMode==true or spec.validUnloadCount==0 then
			local baleCollectionModeText
			if spec.baleCollectionMode then
				baleCollectionModeText = g_i18n:getText("universalAutoload_baleMode")..": "..g_i18n:getText("universalAutoload_enabled")
			else
				baleCollectionModeText = g_i18n:getText("universalAutoload_baleMode")..": "..g_i18n:getText("universalAutoload_disabled")
			end
			g_inputBinding:setActionEventText(spec.toggleBaleCollectionModeEventId, baleCollectionModeText)
			g_inputBinding:setActionEventTextVisibility(spec.toggleBaleCollectionModeEventId, true)
			if debugKeys then print("   >> " .. baleCollectionModeText) end
		else
			g_inputBinding:setActionEventActive(spec.toggleBaleCollectionModeEventId, false)
		end
	end
	
	if spec and spec.isAutoloadAvailable and spec.toggleLoadingActionEventId then
		-- Activate/Deactivate the LOAD key binding
		if spec.isLoading and not self.baleCollectionMode==true then
			local stopLoadingText = g_i18n:getText("universalAutoload_stopLoading")
			g_inputBinding:setActionEventText(spec.toggleLoadingActionEventId, stopLoadingText)
			if debugKeys then print("   >> " .. stopLoadingText) end
		else
			if UniversalAutoload.getIsLoadingKeyAllowed(self) == true then
				local startLoadingText = g_i18n:getText("universalAutoload_startLoading")
				if debugLoading then startLoadingText = startLoadingText.." ("..tostring(spec.validLoadCount)..")" end
				g_inputBinding:setActionEventText(spec.toggleLoadingActionEventId, startLoadingText)
				g_inputBinding:setActionEventActive(spec.toggleLoadingActionEventId, true)
				g_inputBinding:setActionEventTextVisibility(spec.toggleLoadingActionEventId, true)
				if debugKeys then print("   >> " .. startLoadingText) end
			else
				g_inputBinding:setActionEventActive(spec.toggleLoadingActionEventId, false)
			end
		end
	end

	if spec and spec.isAutoloadAvailable and spec.unloadAllActionEventId then
		-- Activate/Deactivate the UNLOAD key binding
		if UniversalAutoload.getIsUnloadingKeyAllowed(self) == true then
			local unloadText = g_i18n:getText("universalAutoload_unloadAll")
			if debugLoading then unloadText = unloadText.." ("..tostring(spec.validUnloadCount)..")" end
			g_inputBinding:setActionEventText(spec.unloadAllActionEventId, unloadText)
			g_inputBinding:setActionEventActive(spec.unloadAllActionEventId, true)
			g_inputBinding:setActionEventTextVisibility(spec.unloadAllActionEventId, true)
			if debugKeys then print("   >> " .. unloadText) end
		else
			g_inputBinding:setActionEventActive(spec.unloadAllActionEventId, false)
		end
		
	end
	
end

-- ACTION EVENTS
function UniversalAutoload.actionEventToggleBelts(self, actionName, inputValue, callbackState, isAnalog)
	-- print("actionEventToggleBelts: "..self:getFullName())
	local spec = self.spec_universalAutoload
	if self.spec_tensionBelts.areBeltsFasten then
		self:setAllTensionBeltsActive(false)
	else
		self:setAllTensionBeltsActive(true)
	end
	spec.updateToggleBelts = true
end
--
function UniversalAutoload.actionEventToggleDoor(self, actionName, inputValue, callbackState, isAnalog)
	-- print("actionEventToggleDoor: "..self:getFullName())
	local spec = self.spec_universalAutoload
	local foldable = self.spec_foldable
	if #foldable.foldingParts > 0 then
		local toggleDirection = self:getToggledFoldDirection()
		if toggleDirection == foldable.turnOnFoldDirection then
			self:setFoldState(toggleDirection, true)
		else
			self:setFoldState(toggleDirection, false)
		end
	end
	spec.updateToggleDoor = true
end
--
function UniversalAutoload.actionEventToggleCurtain(self, actionName, inputValue, callbackState, isAnalog)
	-- print("actionEventToggleCurtain: "..self:getFullName())
	local spec = self.spec_universalAutoload
	local tipState = self:getTipState()
	if tipState == Trailer.TIPSTATE_CLOSED or tipState == Trailer.TIPSTATE_CLOSING then
		self:startTipping(nil, false)
		TrailerToggleManualTipEvent.sendEvent(self, true)
	else
		self:stopTipping()
		TrailerToggleManualTipEvent.sendEvent(self, false)
	end
	spec.updateToggleCurtain = true
end
--
function UniversalAutoload.actionEventToggleShowDebug(self, actionName, inputValue, callbackState, isAnalog)
	-- print("actionEventToggleShowDebug: "..self:getFullName())
	local spec = self.spec_universalAutoload
	if self.isServer then
		UniversalAutoload.showDebug = not UniversalAutoload.showDebug
		UniversalAutoload.showLoading = UniversalAutoload.showDebug
	end
end
--
function UniversalAutoload.actionEventToggleShowLoading(self, actionName, inputValue, callbackState, isAnalog)
	-- print("actionEventToggleShowLoading: "..self:getFullName())
	local spec = self.spec_universalAutoload
	if self.isServer then
		UniversalAutoload.showLoading = not UniversalAutoload.showLoading
		if UniversalAutoload.showLoading == false then
			UniversalAutoload.showDebug = false
		end
	end
end
--
function UniversalAutoload.actionEventToggleBaleCollectionMode(self, actionName, inputValue, callbackState, isAnalog)
	-- print("actionEventToggleBaleCollectionMode: "..self:getFullName())
	local spec = self.spec_universalAutoload
	UniversalAutoload.setBaleCollectionMode(self, not spec.baleCollectionMode)
end
--
function UniversalAutoload.actionEventCycleMaterial_FW(self, actionName, inputValue, callbackState, isAnalog)
	-- print("actionEventCycleMaterial_FW: "..self:getFullName())
	UniversalAutoload.cycleMaterialTypeIndex(self, 1)
end
--
function UniversalAutoload.actionEventCycleMaterial_BW(self, actionName, inputValue, callbackState, isAnalog)
	-- print("actionEventCycleMaterial_BW: "..self:getFullName())
	UniversalAutoload.cycleMaterialTypeIndex(self, -1)
end
--
function UniversalAutoload.actionEventSelectAllMaterials(self, actionName, inputValue, callbackState, isAnalog)
	-- print("actionEventSelectAllMaterials: "..self:getFullName())
	UniversalAutoload.setMaterialTypeIndex(self, 1)
end
--
function UniversalAutoload.actionEventCycleContainer_FW(self, actionName, inputValue, callbackState, isAnalog)
	-- print("actionEventCycleContainer_FW: "..self:getFullName())
	UniversalAutoload.cycleContainerTypeIndex(self, 1)
end
--
function UniversalAutoload.actionEventCycleContainer_BW(self, actionName, inputValue, callbackState, isAnalog)
	-- print("actionEventCycleContainer_BW: "..self:getFullName())
	UniversalAutoload.cycleContainerTypeIndex(self, -1)
end
--
function UniversalAutoload.actionEventSelectAllContainers(self, actionName, inputValue, callbackState, isAnalog)
	-- print("actionEventSelectAllContainers: "..self:getFullName())
	UniversalAutoload.setContainerTypeIndex(self, 1)
end
--
function UniversalAutoload.actionEventToggleFilter(self, actionName, inputValue, callbackState, isAnalog)
	-- print("actionEventToggleFilter: "..self:getFullName())
	local spec = self.spec_universalAutoload
	local state = not spec.currentLoadingFilter
	UniversalAutoload.setLoadingFilter(self, state)
end
--
function UniversalAutoload.actionEventToggleHorizontalLoading(self, actionName, inputValue, callbackState, isAnalog)
	--print("actionEventToggleHorizontalLoading: "..self:getFullName())
	local spec = self.spec_universalAutoload
	local state = not spec.useHorizontalLoading
	UniversalAutoload.setHorizontalLoading(self, state)
end
--
function UniversalAutoload.actionEventToggleTipside(self, actionName, inputValue, callbackState, isAnalog)
	-- print("actionEventToggleTipside: "..self:getFullName())
	local spec = self.spec_universalAutoload
	local tipside
	if spec.currentTipside == "left" then
		tipside = "right"
	else
		tipside = "left"
	end
	UniversalAutoload.setCurrentTipside(self, tipside)
end
--
function UniversalAutoload.actionEventToggleLoading(self, actionName, inputValue, callbackState, isAnalog)
	print("CALLBACK actionEventToggleLoading: "..self:getFullName())
	local spec = self.spec_universalAutoload
	if not spec.isLoading then
		UniversalAutoload.startLoading(self)
	else
		UniversalAutoload.stopLoading(self)
	end
end
--
function UniversalAutoload.actionEventUnloadAll(self, actionName, inputValue, callbackState, isAnalog)
	-- print("actionEventUnloadAll: "..self:getFullName())
	UniversalAutoload.startUnloading(self)
end

-- EVENT FUNCTIONS
function UniversalAutoload:cycleMaterialTypeIndex(direction, noEventSend)
	local spec = self.spec_universalAutoload
	
	if self.isServer then
		local materialIndex
		if direction == 1 then
			materialIndex = 999
			for _, object in pairs(spec.availableObjects or {}) do
				local objectMaterialName = UniversalAutoload.getMaterialTypeName(object)
				local objectMaterialIndex = UniversalAutoload.MATERIALS_INDEX[objectMaterialName] or 1
				if objectMaterialIndex > spec.currentMaterialIndex and objectMaterialIndex < materialIndex then
					materialIndex = objectMaterialIndex
				end
			end
			for _, object in pairs(spec.loadedObjects or {}) do
				local objectMaterialName = UniversalAutoload.getMaterialTypeName(object)
				local objectMaterialIndex = UniversalAutoload.MATERIALS_INDEX[objectMaterialName] or 1
				if objectMaterialIndex > spec.currentMaterialIndex and objectMaterialIndex < materialIndex then
					materialIndex = objectMaterialIndex
				end
			end
		else
			materialIndex = 0
			local startingValue = (spec.currentMaterialIndex==1) and #UniversalAutoload.MATERIALS+1 or spec.currentMaterialIndex
			for _, object in pairs(spec.availableObjects or {}) do
				local objectMaterialName = UniversalAutoload.getMaterialTypeName(object)	
				local objectMaterialIndex = UniversalAutoload.MATERIALS_INDEX[objectMaterialName] or 1
				if objectMaterialIndex < startingValue and objectMaterialIndex > materialIndex then
					materialIndex = objectMaterialIndex
				end
			end
			for _, object in pairs(spec.loadedObjects or {}) do
				local objectMaterialName = UniversalAutoload.getMaterialTypeName(object)	
				local objectMaterialIndex = UniversalAutoload.MATERIALS_INDEX[objectMaterialName] or 1
				if objectMaterialIndex < startingValue and objectMaterialIndex > materialIndex then
					materialIndex = objectMaterialIndex
				end
			end
		end
		if materialIndex == nil or materialIndex == 0 or materialIndex == 999 then
			materialIndex = 1
		end
		
		UniversalAutoload.setMaterialTypeIndex(self, materialIndex)
		if materialIndex==1 and spec.totalAvailableCount==0 and spec.totalUnloadCount==0 then
			-- NO_OBJECTS_FOUND
			UniversalAutoload.showWarningMessage(self, 2)
		end
	end
	
	UniversalAutoload.CycleMaterialEvent.sendEvent(self, direction, noEventSend)
end
--
function UniversalAutoload:setMaterialTypeIndex(typeIndex, noEventSend)
	-- print("setMaterialTypeIndex: "..self:getFullName().." "..tostring(typeIndex))
	local spec = self.spec_universalAutoload

	spec.currentMaterialIndex = math.min(math.max(typeIndex, 1), table.getn(UniversalAutoload.MATERIALS))

	UniversalAutoload.SetMaterialTypeEvent.sendEvent(self, typeIndex, noEventSend)
	
	spec.updateCycleMaterial = true
	
	if self.isServer then
		UniversalAutoload.countActivePallets(self)
	end
end
--
function UniversalAutoload:cycleContainerTypeIndex(direction, noEventSend)
	local spec = self.spec_universalAutoload
	if self.isServer then
		local containerIndex
		if direction == 1 then
			containerIndex = 999
			for _, object in pairs(spec.availableObjects or {}) do
				local objectContainerName = UniversalAutoload.getContainerTypeName(object)
				local objectContainerIndex = UniversalAutoload.CONTAINERS_LOOKUP[objectContainerName] or 1
				if objectContainerIndex > spec.currentContainerIndex and objectContainerIndex < containerIndex then
					containerIndex = objectContainerIndex
				end
			end
			for _, object in pairs(spec.loadedObjects or {}) do
				local objectContainerName = UniversalAutoload.getContainerTypeName(object)
				local objectContainerIndex = UniversalAutoload.CONTAINERS_LOOKUP[objectContainerName] or 1
				if objectContainerIndex > spec.currentContainerIndex and objectContainerIndex < containerIndex then
					containerIndex = objectContainerIndex
				end
			end
		else
			containerIndex = 0
			local startingValue = (spec.currentContainerIndex==1) and #UniversalAutoload.CONTAINERS+1 or spec.currentContainerIndex
			for _, object in pairs(spec.availableObjects or {}) do
				local objectContainerName = UniversalAutoload.getContainerTypeName(object)
				local objectContainerIndex = UniversalAutoload.CONTAINERS_LOOKUP[objectContainerName] or 1
				if objectContainerIndex < startingValue and objectContainerIndex > containerIndex then
					containerIndex = objectContainerIndex
				end
			end
			for _, object in pairs(spec.loadedObjects or {}) do
				local objectContainerName = UniversalAutoload.getContainerTypeName(object)
				local objectContainerIndex = UniversalAutoload.CONTAINERS_LOOKUP[objectContainerName] or 1
				if objectContainerIndex < startingValue and objectContainerIndex > containerIndex then
					containerIndex = objectContainerIndex
				end
			end
		end
		if containerIndex == nil or containerIndex == 0 or containerIndex == 999 then
			containerIndex = 1
		end
		
		UniversalAutoload.setContainerTypeIndex(self, containerIndex)
		if containerIndex==1 and spec.totalAvailableCount==0 and spec.totalUnloadCount==0 then
			-- NO_OBJECTS_FOUND
			UniversalAutoload.showWarningMessage(self, 2)
		end
	end
	
	UniversalAutoload.CycleContainerEvent.sendEvent(self, direction, noEventSend)
end
--
function UniversalAutoload:setContainerTypeIndex(typeIndex, noEventSend)
	-- print("setContainerTypeIndex: "..self:getFullName().." "..tostring(typeIndex))
	local spec = self.spec_universalAutoload

	spec.currentContainerIndex = math.min(math.max(typeIndex, 1), table.getn(UniversalAutoload.CONTAINERS))

	UniversalAutoload.SetContainerTypeEvent.sendEvent(self, typeIndex, noEventSend)
	spec.updateCycleContainer = true
	
	if self.isServer then
		UniversalAutoload.countActivePallets(self)
	end
end
--
function UniversalAutoload:setLoadingFilter(state, noEventSend)
	-- print("setLoadingFilter: "..self:getFullName().." "..tostring(state))
	local spec = self.spec_universalAutoload
	
	spec.currentLoadingFilter = state
	
	UniversalAutoload.SetFilterEvent.sendEvent(self, state, noEventSend)
	
	spec.updateToggleFilter = true
	
	if self.isServer then
		UniversalAutoload.countActivePallets(self)
	end
end
--
function UniversalAutoload:setHorizontalLoading(state, noEventSend)
	-- print("setHorizontalLoading: "..self:getFullName().." "..tostring(state))
	local spec = self.spec_universalAutoload

	spec.useHorizontalLoading = state
	
	UniversalAutoload.SetHorizontalLoadingEvent.sendEvent(self, state, noEventSend)
	
	spec.updateHorizontalLoading = true
end
--
function UniversalAutoload:setCurrentTipside(tipside, noEventSend)
	-- print("setTipside: "..self:getFullName().." - "..tostring(tipside))
	local spec = self.spec_universalAutoload
	
	spec.currentTipside = tipside
	
	UniversalAutoload.SetTipsideEvent.sendEvent(self, tipside, noEventSend)
	spec.updateToggleTipside = true
end
--
function UniversalAutoload:setCurrentLoadside(loadside, noEventSend)
	-- print("setLoadside: "..self:getFullName().." - "..tostring(loadside))
	local spec = self.spec_universalAutoload
	
	spec.currentLoadside = loadside
	
	UniversalAutoload.SetLoadsideEvent.sendEvent(self, loadside, noEventSend)
	if self.isServer then
		UniversalAutoload.countActivePallets(self)
		UniversalAutoload.updateActionEventText(self)
	end
end
--

function UniversalAutoload:setBaleCollectionMode(baleCollectionMode, noEventSend)
	-- print("setBaleCollectionMode: "..self:getFullName().." - "..tostring(baleCollectionMode))
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		if debugVehicles then print(self:getFullName() .. ": UAL DISABLED - setBaleCollectionMode") end
		return
	end
		
	if self.isServer and spec.baleCollectionMode ~= baleCollectionMode then
		if baleCollectionMode then
			if spec.availableBaleCount and spec.availableBaleCount > 0 and not spec.trailerIsFull then
				if debugSpecial then print("baleCollectionMode: startLoading") end
				UniversalAutoload.startLoading(self)
			end
		else
			if debugSpecial then print("baleCollectionMode: stopLoading") end
			UniversalAutoload.stopLoading(self)
			spec.baleCollectionModeDeactivated = true
		end
	end
	
	spec.baleCollectionMode = baleCollectionMode

	UniversalAutoload.SetBaleCollectionModeEvent.sendEvent(self, baleCollectionMode, noEventSend)
	spec.updateToggleLoading = true
end
--
function UniversalAutoload:startLoading(force, noEventSend)
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		if debugVehicles then print(self:getFullName() .. ": UAL DISABLED - startLoading") end
		return
	end

	if force then
		spec.activeLoading = true
	end
	
	if (not spec.isLoading or spec.activeLoading) and UniversalAutoload.getIsLoadingVehicleAllowed(self) then
		-- print("Start Loading: "..self:getFullName() )

		spec.isLoading = true
		spec.firstAttemptToLoad = true
		
		if self.isServer then
		
			spec.loadDelayTime = math.huge
			-- if not spec.baleCollectionMode and UniversalAutoload.testLoadAreaIsEmpty(self) then
				-- UniversalAutoload.resetLoadingArea(self)
			-- end
		
			spec.sortedObjectsToLoad = UniversalAutoload.createSortedObjectsToLoad(self, spec.availableObjects)
		end
		
		UniversalAutoload.StartLoadingEvent.sendEvent(self, force, noEventSend)
		spec.updateToggleLoading = true
	end
end
--
function UniversalAutoload:createSortedObjectsToLoad(availableObjects)
	local spec = self.spec_universalAutoload

	sortedObjectsToLoad = {}
	for _, object in pairs(availableObjects or {}) do
	
		local node = UniversalAutoload.getObjectPositionNode(object)
		if UniversalAutoload.isValidForLoading(self, object) and node~=nil then
		
			local containerType = UniversalAutoload.getContainerType(object)
			local x, y, z = localToLocal(node, spec.loadArea[1].startNode, 0, 0, 0)
			object.sort = {}
			object.sort.height = y
			object.sort.distance = math.abs(x) + math.abs(z)
			object.sort.area = (containerType.sizeX * containerType.sizeZ) or 1
			object.sort.material = UniversalAutoload.getMaterialType(object) or 1
			table.insert(sortedObjectsToLoad, object)
		end
	end
	if #sortedObjectsToLoad > 1 then
		if spec.isLogTrailer then
			table.sort(sortedObjectsToLoad, UniversalAutoload.sortLogsForLoading)
		else
			table.sort(sortedObjectsToLoad, UniversalAutoload.sortPalletsForLoading)
		end
	end
	for _, object in pairs(sortedObjectsToLoad or {}) do
		object.sort = nil
	end
	if debugLoading then
		print(self:getFullName() .. " #sortedObjectsToLoad = " .. tostring(#sortedObjectsToLoad))
	end
	return sortedObjectsToLoad
end
--
function UniversalAutoload.sortPalletsForLoading(w1,w2)
	-- SORT BY:  AREA > MATERIAL > HEIGHT > DISTANCE
	if w1.sort.area == w2.sort.area and w1.sort.material == w2.sort.material and w1.sort.height == w2.sort.height and w1.sort.distance < w2.sort.distance then
		return true
	elseif w1.sort.area == w2.sort.area and w1.sort.material == w2.sort.material and w1.sort.height > w2.sort.height then
		return true
	elseif w1.sort.area == w2.sort.area and w1.sort.material < w2.sort.material then
		return true
	elseif w1.sort.area > w2.sort.area then
		return true
	end
end
--
function UniversalAutoload.sortLogsForLoading(w1,w2)
	-- SORT BY:  LENGTH
	if w1.sizeY > w2.sizeY then
		return true
	end
end
--
function UniversalAutoload:stopLoading(force, noEventSend)
	local spec = self.spec_universalAutoload
	
	if force then
		spec.activeLoading = false
	end
	
	if spec.isLoading and not spec.activeLoading then
		-- print("Stop Loading: "..self:getFullName() )
		spec.isLoading = false
		spec.doPostLoadDelay = true
		
		if self.isServer then
			spec.loadDelayTime = 0

			if not self.spec_tensionBelts.areBeltsFasten then
				spec.doSetTensionBelts = true
			end
		end
		
		UniversalAutoload.StopLoadingEvent.sendEvent(self, force, noEventSend)
		spec.updateToggleLoading = true
	end
end
--
function UniversalAutoload:startUnloading(force, noEventSend)
	local spec = self.spec_universalAutoload

	if not spec.isUnloading then
		-- print("Start Unloading: "..self:getFullName() )
		spec.isUnloading = true

		if self.isServer then

			if spec.loadedObjects then
				if force and spec.forceUnloadPosition then
					if debugLoading then print("USING UNLOADING POSITION: " .. spec.forceUnloadPosition) end
					UniversalAutoload.buildObjectsToUnloadTable(self, spec.forceUnloadPosition)
				else
					UniversalAutoload.buildObjectsToUnloadTable(self)
				end
			end

			if spec.objectsToUnload and (spec.unloadingAreaClear or force) then
				self:setAllTensionBeltsActive(false)
				for object, unloadPlace in pairs(spec.objectsToUnload or {}) do
					if not UniversalAutoload.unloadObject(self, object, unloadPlace) then
						if debugLoading then print("THERE WAS A PROBLEM UNLOADING...") end
					end
				end
				spec.objectsToUnload = {}
				spec.currentLoadingPlace = nil
				if spec.totalUnloadCount == 0 then
					--if debugLoading then
						print("FULLY UNLOADED...")
					--end
					UniversalAutoload.resetLoadingArea(self)
				else
					--if debugLoading then
						print("PARTIALLY UNLOADED...")
					--end
					spec.partiallyUnloaded = true
				end
			else
				-- CLEAR_UNLOADING_AREA
				UniversalAutoload.showWarningMessage(self, 1)
			end
		end
		
		spec.isUnloading = false
		spec.doPostLoadDelay = true

		UniversalAutoload.StartUnloadingEvent.sendEvent(self, force, noEventSend)
		
		spec.updateToggleLoading = true
	end
end
--
function UniversalAutoload:showWarningMessage(messageId, noEventSend)
	-- print("Show Warning Message: "..self:getFullName() )
	local spec = self.spec_universalAutoload
	
	if self.isClient and g_dedicatedServer==nil then
		-- print("CLIENT: "..g_i18n:getText(UniversalAutoload.WARNINGS[messageId]))
		if self == UniversalAutoload.lastClosestVehicle or g_localPlayer:getIsInVehicle(self) then
			g_currentMission:showBlinkingWarning(g_i18n:getText(UniversalAutoload.WARNINGS[messageId]), 2000);
		end
	elseif self.isServer then
		-- print("SERVER: "..g_i18n:getText(UniversalAutoload.WARNINGS[messageId]))
		UniversalAutoload.WarningMessageEvent.sendEvent(self, messageId, noEventSend)
	end
end
--
function UniversalAutoload:resetLoadingState(noEventSend)
	-- print("RESET Loading State: "..self:getFullName() )
	local spec = self.spec_universalAutoload
	
	if self.isServer then
		if spec.doSetTensionBelts and not spec.disableAutoStrap and not spec.baleCollectionMode and not UniversalAutoload.disableAutoStrap then
			self:setAllTensionBeltsActive(true)
		end
		spec.postLoadDelayTime = 0
	end
	
	spec.doPostLoadDelay = false
	spec.doSetTensionBelts = false
	
	UniversalAutoload.ResetLoadingEvent.sendEvent(self, noEventSend)
	
	spec.updateToggleLoading = true
end
--
function UniversalAutoload:updateActionEventText(loadCount, unloadCount, noEventSend)
	-- print("updateActionEventText: "..self:getFullName() )
	local spec = self.spec_universalAutoload
	
	if self.isClient then
		if loadCount then
			spec.validLoadCount = loadCount
		end
		if unloadCount then
			spec.validUnloadCount = unloadCount
		end
		-- print("Valid Load Count = " .. tostring(spec.validLoadCount) .. " / " .. tostring(spec.validUnloadCount) )
	end
	
	if self.isServer then
		-- print("updateActionEventText - SEND EVENT")
		UniversalAutoload.UpdateActionEvents.sendEvent(self, spec.validLoadCount, spec.validUnloadCount, noEventSend)
	end
	
	spec.updateToggleLoading = true
end
--
function UniversalAutoload:printHelpText()
	local spec = self.spec_universalAutoload
	local textExists = false
	if #g_currentMission.hud.inputHelp.extraHelpTexts > 0 then
		for _, text in ipairs(g_currentMission.inGameMenu.hud.inputHelp.extraHelpTexts) do
			if text == self:getFullName() then
				textExists = true
			end
		end
	end
	if not textExists then
		g_currentMission:addExtraPrintText(self:getFullName())
	end
end
--
function UniversalAutoload:forceRaiseActive(state, noEventSend)
	-- print("forceRaiseActive: "..self:getFullName() )
	local spec = self.spec_universalAutoload
	
	if spec.updateKeys then
		-- print("UPDATE KEYS: "..self:getFullName())
		spec.updateKeys = false
		spec.updateToggleLoading = true
	end
	
	if self.isServer then
		-- print("SERVER RAISE ACTIVE: "..self:getFullName().." ("..tostring(state)..")")
		self:raiseActive()
		spec.dirtyFlag = spec.dirtyFlag or self:getNextDirtyFlag()
		self:raiseDirtyFlags(spec.dirtyFlag)
		
		UniversalAutoload.determineTipside(self)
		UniversalAutoload.countActivePallets(self)
	end
	
	if state then
		-- print("Activated = "..tostring(state))
		spec.isActivated = state
	end
	
	UniversalAutoload.RaiseActiveEvent.sendEvent(self, state, noEventSend)
end
--
function UniversalAutoload:updatePlayerTriggerState(playerId, inTrigger, noEventSend)
	-- print("updatePlayerTriggerState: "..self:getFullName() )
	local spec = self.spec_universalAutoload
	
	if playerId then
		spec.playerInTrigger[playerId] = inTrigger
	end
	
	UniversalAutoload.PlayerTriggerEvent.sendEvent(self, playerId, inTrigger, noEventSend)
end


-- MAIN "ON LOAD" INITIALISATION FUNCTION
function UniversalAutoload:onLoad(savegame)
	
	self.spec_universalAutoload = self[UniversalAutoload.specName]
	local spec = self.spec_universalAutoload
	
	if self.isServer then

		if self.spec_tensionBelts and self.spec_tensionBelts.hasTensionBelts then
			local nBelts = #self.spec_tensionBelts.sortedBelts
			if debugVehicles then print(self:getFullName() .. ": UAL - tension belts (" .. nBelts .. ")") end
			if nBelts >= 2 then
				spec.hasTensionBelts = true
				spec.isAutoloadAvailable = true
			else
				if debugVehicles then print("Not enough tension belts for UAL (" .. nBelts .. ")") end
			end
		end
		
		if self.spec_fillVolume and #self.spec_fillVolume.volumes > 0 then
			if debugVehicles then print(self:getFullName() .. ": UAL - fill volumes") end
			for i, fillVolume in ipairs(self.spec_fillVolume.volumes) do
				local capacity = self:getFillUnitCapacity(fillVolume.fillUnitIndex)
				if debugVehicles then print("  [" .. i .. "] = " .. capacity) end
			end
			spec.hasFillVolume = true
			-- spec.isAutoloadAvailable = false
		end
		
		
		local configId, configName, description = UniversalAutoloadManager.getValidConfigurationId(self, useConfigName)
		
		if spec.isAutoloadAvailable and configId then
			print("UniversalAutoload - supported vehicle: "..self:getFullName().." #"..configId.." ("..description..")" )
			
			local configFileName = self.configFileName
			local configGroup = UniversalAutoload.VEHICLE_CONFIGURATIONS[configFileName]
			if configGroup then
				if debugVehicles then 
					print("AVAILABLE CONFIGS: (from local settings)")
					for selectedConfigs, config in pairs(configGroup) do
						print("  >> " .. tostring(selectedConfigs))
					end
				end
					
				for selectedConfigs, config in pairs(configGroup) do
					if not spec.loadArea then
						local selectedConfigsList = tostring(selectedConfigs):split(",")
						for _, configListPart in pairs(selectedConfigsList) do
							if tostring(configListPart) == UniversalAutoload.ALL or tostring(configId):find(tostring(configListPart)) then
								print("*** USING CONFIG FROM SETTINGS - "..selectedConfigs.." for #"..configId.." ("..description..") ***")
								-- DebugUtil.printTableRecursively(config, "  --", 0, 1)
								spec.loadedVehicleConfig = {
									configFileName = configFileName,
									selectedConfigs = selectedConfigs,
								}
								
								for id, value in pairs(deepCopy(config)) do
									spec[id] = value
								end
							end
						end
					end
				end
				
				if not spec.loadArea then
					print("*** NO MATCHING LOCAL CONFIG - #"..configId.." ("..description..") ***")
				end
			else
				print("*** NO LOCAL CONFIGS AVAILABLE - #"..configId.." ("..description..") ***")
			end
		else
			print("*** UNSUPPORTED CONFIG - #"..tostring(configId).." ("..tostring(description)..") ***")
		end
		
		if self.propertyState == VehiclePropertyState.SHOP_CONFIG then
			print("CREATE SHOP VEHICLE: " .. self:getFullName())
			if debugVehicles then print("UniversalAutoload - IN SHOP: "..self.configFileName ) end
			spec.isInsideShop = true
			UniversalAutoloadManager.shopVehicle = self
			return
		elseif self.propertyState == VehiclePropertyState.OWNED then
			print("CREATE REAL VEHICLE: " .. self:getFullName())
			if debugVehicles then print("UniversalAutoload - ON LOAD: "..self.configFileName ) end
			spec.isInsideShop = false
			
			local shopSpec = nil
			if UniversalAutoloadManager.shopVehicle then
				print("SHOP VEHICLE STILL EXISTS " .. UniversalAutoloadManager.shopVehicle.rootNode )
				shopSpec = UniversalAutoloadManager.shopVehicle.spec_universalAutoload
			elseif UniversalAutoloadManager.lastShopVehicle then
				print("WORKSHOP VEHICLE STILL EXISTS " .. UniversalAutoloadManager.lastShopVehicle.rootNode )
				shopSpec = UniversalAutoloadManager.lastShopVehicle.spec_universalAutoload
				UniversalAutoloadManager.lastShopVehicle = nil
			end
			
			if shopSpec and UniversalAutoloadManager.shopConfig and spec.selectedConfigs == shopSpec.selectedConfigs then
				
				print("CLONE SETTINGS FROM SHOP VEHICLE")
				local shopVolume = UniversalAutoloadManager.shopConfig.loadingVolume
				
				print("TO DO: import the rest of the parameters here...")
				spec.loadArea = spec.loadArea or {}
				shopSpec.loadArea = shopSpec.loadArea or {}
				for i, boundingBox in (shopVolume.bbs) do
					local s = boundingBox:getSize()
					local o = boundingBox:getOffset()
					shopSpec.loadArea[i] = {
						width = s.x,
						height = s.y,
						length = s.z,
						offset = {o.x, o.y-s.y/2, o.z},
					}
					spec.loadArea[i] = shopSpec.loadArea[i]
				end
				-- DebugUtil.printTableRecursively(spec, "  --", 0, 2)

				if UniversalAutoload.VEHICLES_LOOKUP[self] == nil then
					UniversalAutoload.VEHICLES_LOOKUP[self] = {}
					if debugVehicles then print(self:getFullName() .. ": UAL DETECTED") end
					if self.addDeleteListener then
						self:addDeleteListener(self, "ualOnDeleteVehicle_Callback")
					end
				end
			
			end

		end
		
		if xmlFile then
			xmlFile:delete()
		end

		if spec.loadArea and spec.loadArea[1] and spec.loadArea[1].offset
		and spec.loadArea[1].width and spec.loadArea[1].length and spec.loadArea[1].height then
			if debugVehicles then print("Universal Autoload Enabled: " .. self:getFullName()) end
			spec.isAutoloadAvailable = true
			if self.propertyState ~= VehiclePropertyState.SHOP_CONFIG then
				UniversalAutoload.VEHICLES[self] = self
			end
		else
			if debugVehicles then print("Universal Autoload DISABLED: " .. self:getFullName()) end
			UniversalAutoload.removeEventListeners(self)
			spec.isAutoloadAvailable = false
			return
		end
	end

	if self.isServer and self.propertyState ~= VehiclePropertyState.SHOP_CONFIG then

		--initialise server only arrays
		spec.triggers = {}
		spec.loadedObjects = {}
		spec.availableObjects = {}
		spec.autoLoadingObjects = {}
		spec.objectToLoadingAreaIndex = {}
		
		local x0, y0, z0 = math.huge, math.huge, math.huge
		local x1, y1, z1 = -math.huge, -math.huge, -math.huge
		
		local actualRootNode = self.rootNode
		-- local actualRootNode = (self.spec_tensionBelts and self.spec_tensionBelts.rootNode) or self.rootNode
		-- if spec.offsetRoot then
			-- local otherOffset = self.i3dMappings[spec.offsetRoot]
			-- if otherOffset then
				-- actualRootNode = otherOffset.nodeId or actualRootNode
			-- end
		-- end
		
		for i, loadArea in pairs(spec.loadArea) do
			-- create bounding box for loading area
			local offset = loadArea.offset
			local loadAreaRoot = actualRootNode
			-- if spec.loadArea[i].offsetRoot then
				-- local otherOffset = self.i3dMappings[spec.loadArea[i].offsetRoot]
				-- if otherOffset then
					-- loadAreaRoot = otherOffset.nodeId or actualRootNode
				-- end
			-- end
			loadArea.rootNode = createTransformGroup("LoadAreaCentre")
			link(loadAreaRoot, loadArea.rootNode)
			setTranslation(loadArea.rootNode, offset[1], offset[2], offset[3])

			loadArea.startNode = createTransformGroup("LoadAreaStart")
			link(loadAreaRoot, loadArea.startNode)
			setTranslation(loadArea.startNode, offset[1], offset[2], offset[3]+(loadArea.length/2))

			loadArea.endNode = createTransformGroup("LoadAreaEnd")
			link(loadAreaRoot, loadArea.endNode)
			setTranslation(loadArea.endNode, offset[1], offset[2], offset[3]-(loadArea.length/2))

			-- measure bounding box for all loading areas
			if x0 > offset[1]-(loadArea.width/2) then x0 = offset[1]-(loadArea.width/2) end
			if x1 < offset[1]+(loadArea.width/2) then x1 = offset[1]+(loadArea.width/2) end
			if y0 > offset[2] then y0 = offset[2] end
			if y1 < offset[2]+(loadArea.height) then y1 = offset[2]+(loadArea.height) end
			if z0 > offset[3]-(loadArea.length/2) then z0 = offset[3]-(loadArea.length/2) end
			if z1 < offset[3]+(loadArea.length/2) then z1 = offset[3]+(loadArea.length/2) end
		end
	
		-- create bounding box for all loading areas
		spec.loadVolume = {}
		spec.loadVolume.width = x1-x0
		spec.loadVolume.height = y1-y0
		spec.loadVolume.length = z1-z0
		
		local offsetX, offsetY, offsetZ = (x0+x1)/2, y0, (z0+z1)/2
		
		spec.loadVolume.rootNode = createTransformGroup("loadVolumeCentre")
		link(actualRootNode, spec.loadVolume.rootNode)
		setTranslation(spec.loadVolume.rootNode, offsetX, offsetY, offsetZ)

		spec.loadVolume.startNode = createTransformGroup("loadVolumeStart")
		link(actualRootNode, spec.loadVolume.startNode)
		setTranslation(spec.loadVolume.startNode, offsetX, offsetY, offsetZ+(spec.loadVolume.length/2))
		
		spec.loadVolume.endNode = createTransformGroup("loadVolumeEnd")
		link(actualRootNode, spec.loadVolume.endNode)
		setTranslation(spec.loadVolume.endNode, offsetX, offsetY, offsetZ-(spec.loadVolume.length/2))

		-- load trigger i3d file
		local i3dFilename = UniversalAutoload.path .. "triggers/UniversalAutoloadTriggers.i3d"
		local triggersRootNode, sharedLoadRequestId = g_i3DManager:loadSharedI3DFile(i3dFilename, false, false)

		-- create triggers
		local unloadingTrigger = {}
		unloadingTrigger.node = I3DUtil.getChildByName(triggersRootNode, "unloadingTrigger")
		if unloadingTrigger.node then
			unloadingTrigger.name = "unloadingTrigger"
			link(spec.loadVolume.rootNode, unloadingTrigger.node)
			setRotation(unloadingTrigger.node, 0, 0, 0)
			
			local sideBoundary = 0
			local rearBoundary = 0
			if UniversalAutoload.manualLoadingOnly or spec.enableSideLoading then
				sideBoundary = spec.loadVolume.width/4
			end
			if UniversalAutoload.manualLoadingOnly or spec.enableRearLoading or spec.rearUnloadingOnly then
				rearBoundary = spec.loadVolume.width/4
			end
			setTranslation(unloadingTrigger.node, 0, spec.loadVolume.height/2, rearBoundary/2)
			setScale(unloadingTrigger.node, spec.loadVolume.width-sideBoundary, spec.loadVolume.height, spec.loadVolume.length-rearBoundary)
			
			table.insert(spec.triggers, unloadingTrigger)
			addTrigger(unloadingTrigger.node, "ualUnloadingTrigger_Callback", self)
			-- print("created" .. unloadingTrigger.name)
		end
		
		local playerTrigger = {}
		playerTrigger.node = I3DUtil.getChildByName(triggersRootNode, "playerTrigger")
		if playerTrigger.node then
			playerTrigger.name = "playerTrigger"
			link(spec.loadVolume.rootNode, playerTrigger.node)
			setRotation(playerTrigger.node, 0, 0, 0)
			setTranslation(playerTrigger.node, 0, spec.loadVolume.height/2, 0)
			setScale(playerTrigger.node, 5*spec.loadVolume.width, 2*spec.loadVolume.height, spec.loadVolume.length+2*spec.loadVolume.width)
			
			table.insert(spec.triggers, playerTrigger)
			addTrigger(playerTrigger.node, "ualPlayerTrigger_Callback", self)
			-- print("created" .. playerTrigger.name)
		end

		if not UniversalAutoload.manualLoadingOnly then

			local leftPickupTrigger = {}
			leftPickupTrigger.node = I3DUtil.getChildByName(triggersRootNode, "leftPickupTrigger")
			if leftPickupTrigger.node then
				leftPickupTrigger.name = "leftPickupTrigger"
				link(spec.loadVolume.rootNode, leftPickupTrigger.node)
				
				local width, height, length = 1.66*spec.loadVolume.width, 2*spec.loadVolume.height, spec.loadVolume.length+spec.loadVolume.width/2

				setRotation(leftPickupTrigger.node, 0, 0, 0)
				setTranslation(leftPickupTrigger.node, 1.1*(width+spec.loadVolume.width)/2, 0, 0)
				setScale(leftPickupTrigger.node, width, height, length)

				table.insert(spec.triggers, leftPickupTrigger)
				addTrigger(leftPickupTrigger.node, "ualLoadingTrigger_Callback", self)
				-- print("created" .. leftPickupTrigger.name)
			end
			
			local rightPickupTrigger = {}
			rightPickupTrigger.node = I3DUtil.getChildByName(triggersRootNode, "rightPickupTrigger")
			if rightPickupTrigger.node then
				rightPickupTrigger.name = "rightPickupTrigger"
				link(spec.loadVolume.rootNode, rightPickupTrigger.node)
				
				local width, height, length = 1.66*spec.loadVolume.width, 2*spec.loadVolume.height, spec.loadVolume.length+spec.loadVolume.width/2

				setRotation(rightPickupTrigger.node, 0, 0, 0)
				setTranslation(rightPickupTrigger.node, -1.1*(width+spec.loadVolume.width)/2, 0, 0)
				setScale(rightPickupTrigger.node, width, height, length)

				table.insert(spec.triggers, rightPickupTrigger)
				addTrigger(rightPickupTrigger.node, "ualLoadingTrigger_Callback", self)
				-- print("created" .. rightPickupTrigger.name)
			end
			
			if spec.rearUnloadingOnly then
				local rearPickupTrigger = {}
				rearPickupTrigger.node = I3DUtil.getChildByName(triggersRootNode, "rearPickupTrigger")
				if rearPickupTrigger.node then
					rearPickupTrigger.name = "rearPickupTrigger"
					link(spec.loadVolume.rootNode, rearPickupTrigger.node)
					
					local squareSide = spec.loadVolume.length+spec.loadVolume.width
					local width, height, length = squareSide, 2*spec.loadVolume.height, 0.8*squareSide

					setRotation(rearPickupTrigger.node, 0, 0, 0)
					setTranslation(rearPickupTrigger.node, 0, 0, -1.1*(length+spec.loadVolume.length)/2)
					setScale(rearPickupTrigger.node, width, height, length)

					table.insert(spec.triggers, rearPickupTrigger)
					addTrigger(rearPickupTrigger.node, "ualLoadingTrigger_Callback", self)
					-- print("created" .. rearPickupTrigger.name)
				end
			end
			
			if spec.frontUnloadingOnly then
				local frontPickupTrigger = {}
				frontPickupTrigger.node = I3DUtil.getChildByName(triggersRootNode, "frontPickupTrigger")
				if frontPickupTrigger.node then
					frontPickupTrigger.name = "frontPickupTrigger"
					link(spec.loadVolume.rootNode, frontPickupTrigger.node)
					
					local squareSide = spec.loadVolume.length+spec.loadVolume.width
					local width, height, length = squareSide, 2*spec.loadVolume.height, 0.8*squareSide

					setRotation(frontPickupTrigger.node, 0, 0, 0)
					setTranslation(frontPickupTrigger.node, 0, 0, 1.1*(length+spec.loadVolume.length)/2)
					setScale(frontPickupTrigger.node, width, height, length)

					table.insert(spec.triggers, frontPickupTrigger)
					addTrigger(frontPickupTrigger.node, "ualLoadingTrigger_Callback", self)
					-- print("created" .. frontPickupTrigger.name)
				end
			end
		end
		
		if UniversalAutoload.manualLoadingOnly or spec.enableRearLoading or spec.rearUnloadingOnly then
			local rearAutoTrigger = {}
			rearAutoTrigger.node = I3DUtil.getChildByName(triggersRootNode, "rearAutoTrigger")
			if rearAutoTrigger.node then
				rearAutoTrigger.name = "rearAutoTrigger"
				link(spec.loadVolume.rootNode, rearAutoTrigger.node)
				
				local depth = 0.05
				local recess = spec.loadVolume.width/4
				local boundary = spec.loadVolume.width/4
				local width, height, length = spec.loadVolume.width-boundary, spec.loadVolume.height, depth

				setRotation(rearAutoTrigger.node, 0, 0, 0)
				setTranslation(rearAutoTrigger.node, 0, spec.loadVolume.height/2, recess-(spec.loadVolume.length/2)-depth )
				setScale(rearAutoTrigger.node, width, height, length)

				table.insert(spec.triggers, rearAutoTrigger)
				addTrigger(rearAutoTrigger.node, "ualAutoLoadingTrigger_Callback", self)
				spec.rearTriggerId = rearAutoTrigger.node
				-- print("created" .. rearAutoTrigger.name)
			end
		end
		
		if UniversalAutoload.manualLoadingOnly or spec.enableSideLoading then
			local depth = 0.05
			local recess = spec.loadVolume.width/7
			local boundary = 2*spec.loadVolume.width/3
			local width, height, length = depth, spec.loadVolume.height, spec.loadVolume.length-boundary
				
			local leftAutoTrigger = {}
			leftAutoTrigger.node = I3DUtil.getChildByName(triggersRootNode, "leftAutoTrigger")
			if leftAutoTrigger.node then
				leftAutoTrigger.name = "leftAutoTrigger"
				link(spec.loadVolume.rootNode, leftAutoTrigger.node)

				setRotation(leftAutoTrigger.node, 0, 0, 0)
				setTranslation(leftAutoTrigger.node, 2*depth+(spec.loadVolume.width/2)-recess, spec.loadVolume.height/2, 0)
				setScale(leftAutoTrigger.node, width, height, length)

				table.insert(spec.triggers, leftAutoTrigger)
				addTrigger(leftAutoTrigger.node, "ualAutoLoadingTrigger_Callback", self)
				-- print("created" .. leftAutoTrigger.name)
			end
			local rightAutoTrigger = {}
			rightAutoTrigger.node = I3DUtil.getChildByName(triggersRootNode, "rightAutoTrigger")
			if rightAutoTrigger.node then
				rightAutoTrigger.name = "rightAutoTrigger"
				link(spec.loadVolume.rootNode, rightAutoTrigger.node)
	
				setRotation(rightAutoTrigger.node, 0, 0, 0)
				setTranslation(rightAutoTrigger.node, -(2*depth+(spec.loadVolume.width/2)-recess), spec.loadVolume.height/2, 0)
				setScale(rightAutoTrigger.node, width, height, length)

				table.insert(spec.triggers, rightAutoTrigger)
				addTrigger(rightAutoTrigger.node, "ualAutoLoadingTrigger_Callback", self)
				-- print("created" .. rightAutoTrigger.name)
			end
		end
		
		delete(triggersRootNode)

		--server only
		spec.isLoading = false
		spec.isUnloading = false
		spec.activeLoading = false
		spec.doPostLoadDelay = false
		spec.doSetTensionBelts = false
		spec.totalAvailableCount = 0
		spec.availableBaleCount = 0
		spec.totalUnloadCount = 0
		spec.validLoadCount = 0
		spec.validUnloadCount = 0

	end

	--client+server
	spec.actionEvents = {}
	spec.playerInTrigger = {}
	spec.currentTipside = "left"
	spec.currentLoadside = "both"
	spec.currentMaterialIndex = 1
	spec.currentContainerIndex = 1
	spec.currentLoadingFilter = true
	spec.baleCollectionMode = false
	spec.useHorizontalLoading = spec.horizontalLoading or false
	
	-- print("SPEC")
	-- DebugUtil.printTableRecursively(spec, "--", 0, 1)

end

-- "ON POST LOAD" CALLED AFTER VEHICLE IS LOADED (not when buying)
function UniversalAutoload:onPostLoad(savegame)
	if self.isServer and savegame then
		local spec = self.spec_universalAutoload
		if spec==nil then
			if debugVehicles then print(self:getFullName() .. ": UAL UNDEFINED - onPostLoad") end
			return
		end
		
		if savegame.resetVehicles or savegame.xmlFile.filename=="" then
			--client+server
			print("UAL: ON POST LOAD - RESET")
			spec.currentTipside = "left"
			spec.currentLoadside = "both"
			spec.currentMaterialIndex = 1
			spec.currentContainerIndex = 1
			spec.currentLoadingFilter = true
			spec.baleCollectionMode = false
			spec.useHorizontalLoading = spec.horizontalLoading or false
			--server only
			spec.currentLoadWidth = 0
			spec.currentLoadLength = 0
			spec.currentLoadHeight = 0
			spec.currentActualWidth = 0
			spec.currentActualLength = 0
			spec.currentLayerCount = 0
			spec.currentLayerHeight = 0
			spec.nextLayerHeight = 0
			spec.currentLoadAreaIndex = 1
			spec.resetLoadingLayer = false
			spec.resetLoadingPattern = false
		else
			--client+server
			local key = savegame.key .. UniversalAutoload.postLoadKey
			print("UAL: ON POST LOAD")
			print("using xml key - " .. key)
			spec.currentTipside = savegame.xmlFile:getValue(key.."#tipside", "left")
			spec.currentLoadside = savegame.xmlFile:getValue(key.."#loadside", "both")
			spec.currentMaterialIndex = savegame.xmlFile:getValue(key.."#materialIndex", 1)
			spec.currentContainerIndex = savegame.xmlFile:getValue(key.."#containerIndex", 1)
			spec.currentLoadingFilter = savegame.xmlFile:getValue(key.."#loadingFilter", true)
			spec.baleCollectionMode = savegame.xmlFile:getValue(key.."#baleCollectionMode", false)
			spec.useHorizontalLoading = savegame.xmlFile:getValue(key.."#useHorizontalLoading", spec.horizontalLoading or false)
			--server only
			spec.currentLoadWidth = savegame.xmlFile:getValue(key.."#loadWidth", 0)
			spec.currentLoadLength = savegame.xmlFile:getValue(key.."#loadLength", 0)
			spec.currentLoadHeight = savegame.xmlFile:getValue(key.."#loadHeight", 0)
			spec.currentActualWidth = savegame.xmlFile:getValue(key.."#actualWidth", 0)
			spec.currentActualLength = savegame.xmlFile:getValue(key.."#actualLength", 0)
			spec.currentLayerCount = savegame.xmlFile:getValue(key.."#layerCount", 0)
			spec.currentLayerHeight = savegame.xmlFile:getValue(key.."#layerHeight", 0)
			spec.nextLayerHeight = savegame.xmlFile:getValue(key.."#nextLayerHeight", 0)
			spec.currentLoadAreaIndex = savegame.xmlFile:getValue(key.."#loadAreaIndex", 1)
			spec.resetLoadingLayer = false
			spec.resetLoadingPattern = false
		end
		
		UniversalAutoload.updateWidthAxis(self)
		UniversalAutoload.updateLengthAxis(self)
		UniversalAutoload.updateHeightAxis(self)
	
	end
end

function UniversalAutoload:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	if self.isClient then
		local spec = self.spec_universalAutoload

	end
end

function UniversalAutoload:onUpdateEnd(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	if self.isClient then
		local spec = self.spec_universalAutoload
		
	end
end

-- "SAVE TO XML FILE" CALLED DURING GAME SAVE
function UniversalAutoload:saveToXMLFile(xmlFile, key, usedModNames)

	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		if debugVehicles then print(self:getFullName() .. ": UAL DISABLED - saveToXMLFile") end
		return
	end

	-- print("UniversalAutoload - saveToXMLFile: "..self:getFullName())
	if spec.baleCollectionMode then
		UniversalAutoload.setBaleCollectionMode(self, false)
		for object,_ in pairs(spec.loadedObjects or {}) do
			if object and object.isRoundbale ~= nil then
				UniversalAutoload.unlinkObject(object)
				UniversalAutoload.addToPhysics(self, object)
			end
		end
	end
	if spec.resetLoadingLayer ~= false then
		UniversalAutoload.resetLoadingLayer(self)
	end
	if spec.resetLoadingPattern ~= false then
		UniversalAutoload.resetLoadingPattern(self)
	end
	
	--UniversalAutoload.savegameStateKey = ".currentState"
	--UniversalAutoload.savegameConfigKey = ".configuration"

	local saveKey = key .. UniversalAutoload.savegameStateKey
	--client+server
	xmlFile:setValue(saveKey.."#tipside", spec.currentTipside or "left")
	xmlFile:setValue(saveKey.."#loadside", spec.currentLoadside or "both")
	xmlFile:setValue(saveKey.."#materialIndex", spec.currentMaterialIndex or 1)
	xmlFile:setValue(saveKey.."#containerIndex", spec.currentContainerIndex or 1)
	xmlFile:setValue(saveKey.."#loadingFilter", spec.currentLoadingFilter or true)
	xmlFile:setValue(saveKey.."#baleCollectionMode", spec.baleCollectionMode or false)
	xmlFile:setValue(saveKey.."#useHorizontalLoading", spec.useHorizontalLoading or false)
	--server only
	xmlFile:setValue(saveKey.."#loadWidth", spec.currentLoadWidth or 0)
	xmlFile:setValue(saveKey.."#loadHeight", spec.currentLoadHeight or 0)
	xmlFile:setValue(saveKey.."#loadLength", spec.currentLoadLength or 0)
	xmlFile:setValue(saveKey.."#actualWidth", spec.currentActualWidth or 0)
	xmlFile:setValue(saveKey.."#actualLength", spec.currentActualLength or 0)
	xmlFile:setValue(saveKey.."#layerCount", spec.currentLayerCount or 0)
	xmlFile:setValue(saveKey.."#layerHeight", spec.currentLayerHeight or 0)
	xmlFile:setValue(saveKey.."#nextLayerHeight", spec.nextLayerHeight or 0)
	xmlFile:setValue(saveKey.."#loadAreaIndex", spec.currentLoadAreaIndex or 1)
	
end

-- "ON DELETE" CLEANUP TRIGGER NODES
function UniversalAutoload:onPreDelete()
	-- print("UniversalAutoload - onPreDelete")
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		-- if debugVehicles then print(self:getFullName() .. ": UAL DISABLED - onPreDelete") end
		return
	end
	
	if UniversalAutoload.VEHICLES[self] then
		-- print("PRE DELETE: " .. self:getFullName() )
		UniversalAutoload.VEHICLES[self] = nil
	end
	if self.isServer then
		if spec.triggers then
			for _, trigger in pairs(spec.triggers or {}) do
				removeTrigger(trigger.node)
			end
		end
	end
end
--
function UniversalAutoload:onDelete()
	local shopVehicle = UniversalAutoloadManager.shopVehicle
	if shopVehicle and self == shopVehicle then
		print("DELETE SHOP VEHICLE: " .. shopVehicle:getFullName())
		UniversalAutoloadManager.lastShopVehicle = shopVehicle
		UniversalAutoloadManager.shopVehicle = nil
	end
	
	-- print("UniversalAutoload - onDelete")
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		-- if debugVehicles then print(self:getFullName() .. ": UAL DISABLED - onDelete") end
		return
	end
	
	if UniversalAutoload.VEHICLES[self] then
		-- print("DELETE: " .. self:getFullName() )
		UniversalAutoload.VEHICLES[self] = nil
	end
	if self.isServer then
		if spec.triggers then
			for _, trigger in pairs(spec.triggers or {}) do
				removeTrigger(trigger.node)
			end
		end
	end
end


-- SET FOLDING STATE FLAG ON FOLDING STATE CHANGE
function UniversalAutoload:onFoldStateChanged(direction, moveToMiddle)
	-- print("UniversalAutoload - onFoldStateChanged")
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		if debugVehicles then print(self:getFullName() .. ": UAL DISABLED - onFoldStateChanged") end
		return
	end
	
	if self.isServer then
		-- print("onFoldStateChanged: "..self:getFullName())
		spec.foldAnimationStarted = true
		UniversalAutoload.updateActionEventText(self)
	end
end
--
function UniversalAutoload:onMovingToolChanged(tool, transSpeed, dt)
	-- print("UniversalAutoload - onMovingToolChanged")
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		if debugVehicles then print(self:getFullName() .. ": UAL DISABLED - onMovingToolChanged") end
		return
	end
	
	if self.isServer and tool.axis then
		-- print("onMovingToolChanged: "..self:getFullName().." - "..tool.axis)
		UniversalAutoload.updateWidthAxis(self)
		UniversalAutoload.updateLengthAxis(self)
		UniversalAutoload.updateHeightAxis(self)
	end
end
--
function UniversalAutoload:updateWidthAxis()
	local spec = self.spec_universalAutoload
	
	for i, loadArea in pairs(spec.loadArea or {}) do
		if loadArea.widthAxis and self.spec_cylindered then

			for i, tool in pairs(self.spec_cylindered.movingTools or {}) do
				if tool.axis and loadArea.widthAxis == tool.axis then
			
					local x, y, z = getTranslation(tool.node)
					-- print(self:getFullName() .." - UPDATE WIDTH AXIS: x="..x..",  y="..y..",  z="..z)
					if loadArea.originalWidth == nil then
						loadArea.originalWidth = loadArea.width
						spec.loadVolume.originalWidth = spec.loadVolume.width
					end
					local direction = loadArea.reverseWidthAxis and -1 or 1
					local extensionWidth = math.abs(x) * direction
					loadArea.width = loadArea.originalWidth + extensionWidth
					spec.loadVolume.width = spec.loadVolume.originalWidth + extensionWidth
				end
			end
		end
	end
end
--
function UniversalAutoload:updateHeightAxis()
	local spec = self.spec_universalAutoload

	for i, loadArea in pairs(spec.loadArea or {}) do
		if loadArea.heightAxis and self.spec_cylindered then

			for i, tool in pairs(self.spec_cylindered.movingTools or {}) do
				if tool.axis and loadArea.heightAxis == tool.axis then
			
					local x, y, z = getTranslation(tool.node)
					-- print(self:getFullName() .." - UPDATE HEIGHT AXIS: x="..x..",  y="..y..",  z="..z)
					if loadArea.originalHeight == nil then
						loadArea.originalHeight = loadArea.height
						spec.loadVolume.originalHeight = spec.loadVolume.height
					end
					local direction = loadArea.reverseHeightAxis and -1 or 1
					local extensionHeight = math.abs(y) * direction
					loadArea.height = loadArea.originalHeight + extensionHeight
					spec.loadVolume.height = spec.loadVolume.originalHeight + extensionHeight
					
				end
			end
		end
	end
end
--
function UniversalAutoload:updateLengthAxis()
	local spec = self.spec_universalAutoload
	
	for i, loadArea in pairs(spec.loadArea or {}) do
		if self.spec_cylindered and (loadArea.lengthAxis or loadArea.offsetFrontAxis or loadArea.offsetRearAxis) then

			for i, tool in pairs(self.spec_cylindered.movingTools or {}) do
				if tool.axis and ((loadArea.lengthAxis == tool.axis) or
					(loadArea.offsetFrontAxis == tool.axis) or (loadArea.offsetRearAxis == tool.axis)) then
					
					local x, y, z = getTranslation(tool.node)
					-- print(self:getFullName() .." - UPDATE LENGTH AXIS: x="..x..",  y="..y..",  z="..z)
					
					if loadArea.originalLength == nil then
						loadArea.originalLength = loadArea.length
						local X = loadArea.offset[1]
						local Y = loadArea.offset[2]
						local Z = loadArea.offset[3]
						loadArea.X = X
						loadArea.Y = Y
						loadArea.Z = Z
						
						spec.loadVolume.originalLength = spec.loadVolume.length
						local X0, Y0, Z0 = getTranslation(spec.loadVolume.rootNode)
						spec.loadVolume.X = X0
						spec.loadVolume.Y = Y0
						spec.loadVolume.Z = Z0
					end
					
					local offsetEnd = 0
					local offsetRoot = 0
					local offsetStart = 0
					local extensionLength = 0
					
					loadArea.length = loadArea.originalLength
					spec.loadVolume.length = spec.loadVolume.originalLength
					
					local function mapValue(value, inMin, inMax, outMin, outMax)
						return (value - inMin) / (inMax - inMin) * (outMax - outMin) + outMin
					end

					if loadArea.lengthAxis == tool.axis then
						-- print(self:getFullName() .." EXTEND LENGTH AXIS")
						local direction = loadArea.reverseLengthAxis and -1 or 1
						extensionLength = math.abs(z) * direction
						loadArea.length = loadArea.length + extensionLength
						spec.loadVolume.length = spec.loadVolume.length + extensionLength
						offsetEnd = offsetEnd - extensionLength
						offsetRoot = offsetRoot - (extensionLength/2)
					end

					if loadArea.offsetFrontAxis == tool.axis then
						-- print(self:getFullName() .." OFFSET FRONT AXIS")
						if tool.rotMin and tool.rotMax then
							local rot = tool.curRot[tool.rotationAxis]
							local range = math.abs(tool.rotMax - tool.rotMin)
							extensionLength = mapValue(rot, tool.rotMin, tool.rotMax, 0, range)
						else
							extensionLength = math.abs(z)
						end
						loadArea.length = loadArea.length - extensionLength
						spec.loadVolume.length = spec.loadVolume.length - extensionLength
						offsetRoot = offsetRoot - (extensionLength/2)
						offsetStart = offsetStart - extensionLength
					end
					
					if loadArea.offsetRearAxis == tool.axis then
						-- print(self:getFullName() .." OFFSET REAR AXIS")
						if tool.rotMin and tool.rotMax then
							local rot = tool.curRot[tool.rotationAxis]
							local range = math.abs(tool.rotMax - tool.rotMin)
							extensionLength = mapValue(rot, tool.rotMin, tool.rotMax, 0, range)
						else
							extensionLength = math.abs(z)
						end
						loadArea.length = loadArea.length - extensionLength
						spec.loadVolume.length = spec.loadVolume.length - extensionLength
						offsetRoot = offsetRoot + (extensionLength/2)
						offsetEnd = offsetEnd + extensionLength
					end
					
					setTranslation(loadArea.endNode, loadArea.X, loadArea.Y, loadArea.Z-(loadArea.originalLength/2) + offsetEnd)
					setTranslation(loadArea.rootNode, loadArea.X, loadArea.Y, loadArea.Z + offsetRoot)
					setTranslation(loadArea.startNode, loadArea.X, loadArea.Y, loadArea.Z+(loadArea.originalLength/2) + offsetStart)
					setTranslation(spec.loadVolume.rootNode, spec.loadVolume.X, spec.loadVolume.Y, spec.loadVolume.Z + offsetRoot)
					
					if spec.rearTriggerId then
						local depth = 0.05
						local recess = spec.loadVolume.width/4
						setTranslation(spec.rearTriggerId, 0, spec.loadVolume.height/2, recess-(spec.loadVolume.length/2)-depth)
					end
				end

			end
		end
	end
end
--
function UniversalAutoload:ualGetIsFolding()

	local isFolding = false
	if self.spec_foldable then
		for _, foldingPart in pairs(self.spec_foldable.foldingParts or {}) do
			if self:getIsAnimationPlaying(foldingPart.animationName) then
				isFolding = true
			end
		end
	end

	return isFolding
end
--
function UniversalAutoload:ualGetIsCovered()

	if self.spec_cover and self.spec_cover.hasCovers then
		return self.spec_cover.state == 0
	else
		return false
	end
end
--
function UniversalAutoload:ualGetIsFilled()

	local isFilled = false
	if self.spec_fillVolume then
		for _, fillVolume in ipairs(self.spec_fillVolume.volumes or {}) do
			local capacity = self:getFillUnitFillLevel(fillVolume.fillUnitIndex)
			local fillLevel = self:getFillUnitFillLevel(fillVolume.fillUnitIndex)
			if fillLevel > 0 then
				isFilled = true
			end
		end
	end
	return isFilled
end
-- --
function UniversalAutoload:ualGetPalletCanDischargeToTrailer(object)
	local isSupported = false
	if object.spec_dischargeable and object.spec_dischargeable.currentDischargeNode then
		local currentDischargeNode = object.spec_dischargeable.currentDischargeNode
		local fillType = object:getDischargeFillType(currentDischargeNode)
		
		if self.spec_fillVolume then
			for _, fillVolume in ipairs(self.spec_fillVolume.volumes or {}) do
				if self:getFillUnitAllowsFillType(fillVolume.fillUnitIndex, fillType) then
					isSupported = true
				end
			end		
		end
		--print("fillType: "..tostring(fillType)..": "..g_fillTypeManager:getFillTypeNameByIndex(fillType).." - "..tostring(isSupported))
	end
	return isSupported
end
--
function UniversalAutoload:ualGetIsMoving()
	return self.lastSpeedReal > 0.0005
end


-- NETWORKING FUNCTIONS
function UniversalAutoload:onReadStream(streamId, connection)
	local spec = self.spec_universalAutoload
	
	if streamReadBool(streamId) then
		print("Universal Autoload Enabled: " .. self:getFullName())
		spec.isAutoloadAvailable = true
		spec.currentTipside = streamReadString(streamId)
		spec.currentLoadside = streamReadString(streamId)
		spec.currentMaterialIndex = streamReadInt32(streamId)
		spec.currentContainerIndex = streamReadInt32(streamId)
		spec.currentLoadingFilter = streamReadBool(streamId)
		spec.useHorizontalLoading = streamReadBool(streamId)
		spec.baleCollectionMode = streamReadBool(streamId)
		spec.isLoading = streamReadBool(streamId)
		spec.isUnloading = streamReadBool(streamId)
		spec.activeLoading = streamReadBool(streamId)
		spec.validLoadCount = streamReadInt32(streamId)
		spec.validUnloadCount = streamReadInt32(streamId)
		spec.isBoxTrailer = streamReadBool(streamId)
		spec.isLogTrailer = streamReadBool(streamId)
		spec.isBaleTrailer = streamReadBool(streamId)
		spec.isCurtainTrailer = streamReadBool(streamId)
		spec.rearUnloadingOnly = streamReadBool(streamId)
		spec.frontUnloadingOnly = streamReadBool(streamId)
		
		if self.propertyState ~= VehiclePropertyState.SHOP_CONFIG then
			UniversalAutoload.VEHICLES[self] = self
		end
	else
		print("Universal Autoload Disabled: " .. self:getFullName())
		spec.isAutoloadAvailable = false
		UniversalAutoload.removeEventListeners(self)
	end
end
--
function UniversalAutoload:onWriteStream(streamId, connection)
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable then
		streamWriteBool(streamId, true)
		spec.currentTipside = spec.currentTipside or "left"
		spec.currentLoadside = spec.currentLoadside or "both"
		spec.currentMaterialIndex = spec.currentMaterialIndex or 1
		spec.currentContainerIndex = spec.currentContainerIndex or 1
		spec.currentLoadingFilter = spec.currentLoadingFilter or true
		spec.useHorizontalLoading = spec.useHorizontalLoading or false
		spec.baleCollectionMode = spec.baleCollectionMode or false
		spec.isLoading = spec.isLoading or false
		spec.isUnloading = spec.isUnloading or false
		spec.activeLoading = spec.activeLoading or false
		spec.validLoadCount = spec.validLoadCount or 0
		spec.validUnloadCount = spec.validUnloadCount or 0
		spec.isBoxTrailer = spec.isBoxTrailer or false
		spec.isLogTrailer = spec.isLogTrailer or false
		spec.isBaleTrailer = spec.isBaleTrailer or false
		spec.isCurtainTrailer = spec.isCurtainTrailer or false
		spec.rearUnloadingOnly = spec.rearUnloadingOnly or false
		spec.frontUnloadingOnly = spec.frontUnloadingOnly or false
		
		streamWriteString(streamId, spec.currentTipside)
		streamWriteString(streamId, spec.currentLoadside)
		streamWriteInt32(streamId, spec.currentMaterialIndex)
		streamWriteInt32(streamId, spec.currentContainerIndex)
		streamWriteBool(streamId, spec.currentLoadingFilter)
		streamWriteBool(streamId, spec.useHorizontalLoading)
		streamWriteBool(streamId, spec.baleCollectionMode)
		streamWriteBool(streamId, spec.isLoading)
		streamWriteBool(streamId, spec.isUnloading)
		streamWriteBool(streamId, spec.activeLoading)
		streamWriteInt32(streamId, spec.validLoadCount)
		streamWriteInt32(streamId, spec.validUnloadCount)
		streamWriteBool(streamId, spec.isBoxTrailer)
		streamWriteBool(streamId, spec.isLogTrailer)
		streamWriteBool(streamId, spec.isBaleTrailer)
		streamWriteBool(streamId, spec.isCurtainTrailer)
		streamWriteBool(streamId, spec.rearUnloadingOnly)
		streamWriteBool(streamId, spec.frontUnloadingOnly)
	else
		streamWriteBool(streamId, false)
	end
end

function UniversalAutoload:onDraw()
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		return
	end

	if spec.debugError then
		if not spec.printedDebugError then
			spec.printedDebugError = true
			print("UAL - DEBUG ERROR: " .. self:getFullName())
			print(spec.debugResult)
		end
		return
	end
		
	if self.isServer and self.isClient and self.isActive and not g_gui:getIsGuiVisible() then
		if not spec.isInsideShop then
			local status, result = pcall(UniversalAutoload.drawDebugDisplay, self)
			if not status then
				spec.debugError = true
				spec.debugResult = result
			end
		end
	end
end

-- MAIN AUTOLOAD ONUPDATE LOOP
function UniversalAutoload:doUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	-- print("UniversalAutoload - onUpdate")
	local spec = self.spec_universalAutoload

	if spec.isInsideShop then
		local shopVehicle = UniversalAutoloadManager.shopVehicle
		local lastShopVehicle = UniversalAutoloadManager.lastShopVehicle
		
		if lastShopVehicle and self == UniversalAutoloadManager.lastShopVehicle then
			print(self.rootNode .. " IS THE LAST SHOP VEHICLE")
		
		elseif shopVehicle and self == UniversalAutoloadManager.shopVehicle then
			-- CONFIGURE LOADING AREA WHEN INSIDE SHOP
			if spec.resetToDefault then
				print("RESET TO DEFAULT")
				spec.resetToDefault = nil
				spec.loadingVolume = nil
				spec.selectedConfigs = nil
			end
			
			if spec.selectedConfigs then
				UniversalAutoloadManager.importLoadingVolume(self)
			else
				UniversalAutoloadManager.createLoadingVolumeInsideShop(self)
			end
			if spec.loadingVolume then
				spec.loadingVolume:draw(true)
				if spec.loadingVolume.state == LoadingVolume.STATE.SHOP_CONFIG then
					UniversalAutoloadManager.editLoadingVolumeInsideShop(self)
				end
			end
			return
		end
	end

	spec.countedPallets = false
	local playerActive = (spec.playerInTrigger and (spec.playerInTrigger[g_localPlayer.userId] == true)) or false
	if self.isClient and isActiveForInputIgnoreSelection or playerActive then
		spec.menuDelayTime = spec.menuDelayTime or 0
		if spec.menuDelayTime > UniversalAutoload.DELAY_TIME/2 then
			spec.menuDelayTime = 0

			if spec.updateToggleLoading then
				if debugKeys or debugVehicles then
					if not spec.counter then spec.counter = 0 end
					spec.counter = spec.counter + 1
					print( self:getFullName() .. " - RefreshActionEvents " .. spec.counter)
				end

				if debugKeys then print("*** clearActionEvents ***") end
				UniversalAutoload.clearActionEvents(self)
				UniversalAutoload.updateActionEventKeys(self)
				
				if debugKeys then print("  UPDATE Toggle Loading") end
				spec.updateToggleLoading=false
				UniversalAutoload.updateToggleLoadingActionEvent(self)
			end
			if spec.updateCycleMaterial then
				if debugKeys then print("  UPDATE Cycle Material") end
				spec.updateCycleMaterial = false
				UniversalAutoload.updateCycleMaterialActionEvent(self)
			end
			if spec.updateCycleContainer then
				if debugKeys then print("  UPDATE Cycle Container") end
				spec.updateCycleContainer = false
				UniversalAutoload.updateCycleContainerActionEvent(self)
			end
			if spec.updateToggleDoor then
				if debugKeys then print("  UPDATE Toggle Door") end
				spec.updateToggleDoor=false
				UniversalAutoload.updateToggleDoorActionEvent(self)
			end
			if spec.updateToggleCurtain then
				if debugKeys then print("  UPDATE Toggle Curtain") end
				spec.updateToggleCurtain=false
				UniversalAutoload.updateToggleCurtainActionEvent(self)
			end
			if spec.updateToggleTipside then
				if debugKeys then print("  UPDATE Toggle Tipside") end
				spec.updateToggleTipside=false
				UniversalAutoload.updateToggleTipsideActionEvent(self)
			end
			if spec.updateToggleBelts then
				if debugKeys then print("  UPDATE Toggle Belts") end
				spec.updateToggleBelts=false
				UniversalAutoload.updateToggleBeltsActionEvent(self)
			end
			if spec.updateToggleFilter then
				if debugKeys then print("  UPDATE Toggle Filter") end
				spec.updateToggleFilter=false
				UniversalAutoload.updateToggleFilterActionEvent(self)
			end
			if spec.updateHorizontalLoading then
				if debugKeys then print("  UPDATE Horizontal Loading") end
				spec.updateHorizontalLoading=false
				UniversalAutoload.updateHorizontalLoadingActionEvent(self)
			end
		else
			spec.menuDelayTime = spec.menuDelayTime + dt
		end
	end
	
	if self.isServer then
	
		-- DETECT WHEN FOLDING STOPS IF IT WAS STARTED
		if spec.foldAnimationStarted then
			if not self:ualGetIsFolding() then
				-- print("*** FOLDING COMPLETE ***")
				spec.foldAnimationStarted = false
				UniversalAutoload.updateActionEventText(self)
			end
		end
		
		-- DETECT WHEN COVER STATE CHANGES
		if self.spec_cover and self.spec_cover.hasCovers then
			if spec.lastCoverState ~= self.spec_cover.state then
				-- print("*** COVERS CHANGED STATE ***")
				spec.lastCoverState = self.spec_cover.state
				UniversalAutoload.updateActionEventText(self)
			end
		end


		-- ALWAYS LOAD THE AUTO LOADING PALLETS
		if spec.autoLoadingObjects then
			for _, object in pairs(spec.autoLoadingObjects) do
				-- print("LOADING PALLET FROM AUTO TRIGGER")
				if not UniversalAutoload.getPalletIsSelectedMaterial(self, object) then
					UniversalAutoload.setMaterialTypeIndex(self, 1)
				end
				if not UniversalAutoload.getPalletIsSelectedContainer(self, object) then
					UniversalAutoload.setContainerTypeIndex(self, 1)
				end
				self:setAllTensionBeltsActive(false)
				-- *** Don't set belts as they can grab the pallet forks ***
				-- spec.doSetTensionBelts = true -- spec.doPostLoadDelay = true
				if not UniversalAutoload.loadObject(self, object) then
					--UNABLE_TO_LOAD_OBJECT
					UniversalAutoload.showWarningMessage(self, 3)
				end
				spec.autoLoadingObjects[object] = nil
			end
		end
		
		-- CREATE AND LOAD BALES (IF REQUESTED)
		if spec.spawnBales then
			spec.spawnBalesDelayTime = spec.spawnBalesDelayTime or 0
			if spec.spawnBalesDelayTime > UniversalAutoload.DELAY_TIME then
				spec.spawnBalesDelayTime = 0
				bale = spec.baleToSpawn
				local baleObject = UniversalAutoload.createBale(self, bale.xmlFile, bale.fillTypeIndex, bale.wrapState)
				if baleObject and not UniversalAutoload.loadObject(self, baleObject) then
					baleObject:delete()
				end
				if baleObject == nil or spec.currentLoadingPlace == nil then
					spec.spawnBales = false
					spec.doPostLoadDelay = true
					spec.doSetTensionBelts = true
					print("..adding bales complete!")
				end
			else
				spec.loadSpeedFactor = spec.loadSpeedFactor or 1
				spec.spawnBalesDelayTime = spec.spawnBalesDelayTime + (spec.loadSpeedFactor*dt)
			end
		end
		
		-- CREATE AND LOAD LOGS (IF REQUESTED)
		if spec.spawnLogs then
			spec.spawnLogsDelayTime = spec.spawnLogsDelayTime or 0
			if spec.spawnLogsDelayTime > UniversalAutoload.DELAY_TIME then

				if spec.spawnedLogId == nil then
					if not UniversalAutoload.spawningLog then
						log = spec.logToSpawn
						spec.spawnedLogId = UniversalAutoload.createLog(self, log.treeType, log.length)
						UniversalAutoload.createdLogId = nil
						UniversalAutoload.createdTreeId = spec.spawnedLogId
						if spec.spawnedLogId == nil then
							spec.spawnLogsDelayTime = 0
						end
					end
				else
					if not g_treePlantManager.loadTreeTrunkData and UniversalAutoload.createdLogId then

						local logId = UniversalAutoload.createdLogId
						if entityExists(logId) then
							local logObject = UniversalAutoload.getSplitShapeObject(logId)
							if logObject then
								if not UniversalAutoload.loadObject(self, logObject) then
									delete(logId)
									spec.currentLoadingPlace = nil
								end
								if spec.currentLoadingPlace == nil then
									spec.spawnLogs = false
									spec.doPostLoadDelay = true
									spec.doSetTensionBelts = true
									print("..adding logs complete!")
								end
								spec.spawnLogsDelayTime = 0
								spec.spawnedLogId = nil
								UniversalAutoload.spawningLog = false
							end
						end

						if spec.spawnedLogId then
							spec.spawnLogs = false
							spec.spawnedLogId = nil
							UniversalAutoload.spawningLog = false
							UniversalAutoload.createdLogId = nil
							UniversalAutoload.createdTreeId = nil
							print("..error spawning log - aborting!")
						end
					end
				end

			else
				spec.loadSpeedFactor = spec.loadSpeedFactor or 1
				spec.spawnLogsDelayTime = spec.spawnLogsDelayTime + (spec.loadSpeedFactor*dt)
			end
		end
		
		-- CREATE AND LOAD PALLETS (IF REQUESTED)
		if spec.spawnPallets and not spec.spawningPallet then
			spec.spawnPalletsDelayTime = spec.spawnPalletsDelayTime or 0
			if spec.spawnPalletsDelayTime > UniversalAutoload.DELAY_TIME then
				spec.spawnPalletsDelayTime = 0

				local i = math.random(1, #spec.palletsToSpawn)
				pallet = spec.palletsToSpawn[i]
				if spec.lastSpawnedPallet then
					if math.random(1, 100) > 50 then
						pallet = spec.lastSpawnedPallet
					end
				end
				UniversalAutoload.createPallet(self, pallet)
				spec.lastSpawnedPallet = pallet
			else
				spec.loadSpeedFactor = spec.loadSpeedFactor or 1
				spec.spawnPalletsDelayTime = spec.spawnPalletsDelayTime + (spec.loadSpeedFactor*dt)
			end
		end
		
		-- CYCLE THROUGH A FULL TESTING PATTERN
		if UniversalAutoloadManager.runFullTest == true and g_localPlayer:getIsInVehicle(self) then
		
			spec.testStage = spec.testStage or 1
			spec.testDelayTime = spec.testDelayTime or 0
			
			if spec.spawnPallets~=true and spec.spawnLogs~=true and spec.spawnBales~=true then

				if spec.testDelayTime > 1250 or spec.testStage == 1 then
					spec.testDelayTime = 0
					
					print("TEST STAGE: " .. spec.testStage )
					if spec.testStage == 1 then
						UniversalAutoloadManager.originalMode = spec.useHorizontalLoading
						spec.useHorizontalLoading = false
						spec.testStage = spec.testStage + 1
						UniversalAutoloadManager:consoleAddPallets("EGG")
					elseif spec.testStage == 2 then
						spec.testStage = spec.testStage + 1
						UniversalAutoloadManager:consoleAddPallets("WOOL")
					elseif spec.testStage == 3 then
						spec.testStage = spec.testStage + 1
						UniversalAutoloadManager:consoleAddPallets("LIQUIDFERTILIZER")
					elseif spec.testStage == 4 then
						spec.testStage = spec.testStage + 1
						UniversalAutoloadManager:consoleAddPallets("LIME")
					elseif spec.testStage == 5 then
						spec.testStage = spec.testStage + 1
						UniversalAutoloadManager:consoleAddPallets()
					elseif spec.testStage == 6 then
						spec.testStage = spec.testStage + 1
						UniversalAutoloadManager:consoleAddPallets()
					elseif spec.testStage == 7 then
						spec.testStage = spec.testStage + 1
						UniversalAutoloadManager:consoleAddRoundBales_125()
					elseif spec.testStage == 8 then
						spec.testStage = spec.testStage + 1
						UniversalAutoloadManager:consoleAddRoundBales_150()
					elseif spec.testStage == 9 then
						spec.testStage = spec.testStage + 1
						UniversalAutoloadManager:consoleAddRoundBales_180()
					elseif spec.testStage == 10 then
						spec.useHorizontalLoading = true
						spec.testStage = spec.testStage + 1
						UniversalAutoloadManager:consoleAddRoundBales_125()
					elseif spec.testStage == 11 then
						spec.testStage = spec.testStage + 1
						UniversalAutoloadManager:consoleAddRoundBales_150()
					elseif spec.testStage == 12 then
						spec.testStage = spec.testStage + 1
						UniversalAutoloadManager:consoleAddRoundBales_180()
					elseif spec.testStage == 13 then
						spec.testStage = spec.testStage + 1
						UniversalAutoloadManager:consoleAddSquareBales_180()
					elseif spec.testStage == 14 then
						spec.testStage = spec.testStage + 1
						UniversalAutoloadManager:consoleAddSquareBales_220()
					elseif spec.testStage == 15 then
						spec.testStage = spec.testStage + 1
						UniversalAutoloadManager:consoleAddSquareBales_240()
					elseif spec.testStage == 16 then
						spec.testStage = nil
						UniversalAutoloadManager.runFullTest = false
						UniversalAutoloadManager:consoleClearLoadedObjects()
						spec.useHorizontalLoading = UniversalAutoloadManager.originalMode
						print("FULL TEST COMPLETE!" )
					end
				else
					spec.testDelayTime = spec.testDelayTime + dt
				end
				
			end
			
		end

		-- -- CHECK IF ANY PLAYERS ARE ACTIVE ON FOOT
		-- local playerTriggerActive = false
		-- if not isActiveForInputIgnoreSelection then
			-- for k, v in pairs (spec.playerInTrigger) do
				-- playerTriggerActive = true
			-- end
		-- end

		local isActiveForLoading = spec.isLoading or spec.isUnloading or spec.doPostLoadDelay
		if isActiveForInputIgnoreSelection or isActiveForLoading or playerTriggerActive or spec.baleCollectionModeDeactivated or spec.aiLoadingActive or spec.baleCollectionMode then
		
			if spec.baleCollectionMode and not isActiveForLoading or spec.aiLoadingActive then
				if spec.availableBaleCount > 0 and not spec.trailerIsFull then
					UniversalAutoload.startLoading(self)
				end
			end
			
			-- RETURN BALES TO PHYSICS WHEN NOT MOVING
			if spec.baleCollectionModeDeactivated and not self:ualGetIsMoving() then
				-- print("ADDING BALES BACK TO PHYSICS")
				spec.baleCollectionModeDeactivated = false
				for object,_ in pairs(spec.loadedObjects) do
					if object and object.isRoundbale ~= nil then
						UniversalAutoload.unlinkObject(object)
						UniversalAutoload.addToPhysics(self, object)
					end
				end
				if not UniversalAutoload.disableAutoStrap then
					self:setAllTensionBeltsActive(false)
					spec.doSetTensionBelts = true
					spec.doPostLoadDelay = true
				end
				UniversalAutoload.updateActionEventText(self)
			end

			-- LOAD ALL ANIMATION SEQUENCE
			if spec.isLoading then
				spec.loadDelayTime = spec.loadDelayTime or 0
				if spec.loadDelayTime > UniversalAutoload.DELAY_TIME then
					local lastObject = nil
					local loadedObject = false
					for index, object in ipairs(spec.sortedObjectsToLoad or {}) do
						if not UniversalAutoload.disableAutoStrap then
							local vehicle = UniversalAutoload.isStrappedOnOtherVehicle(self, object)
							if vehicle then
								vehicle:setAllTensionBeltsActive(false)
							end
						end
						lastObject = object
						if UniversalAutoload.loadObject(self, object, true) then
							loadedObject = true
							if spec.firstAttemptToLoad then
								spec.firstAttemptToLoad = false
								self:setAllTensionBeltsActive(false)
							end
							spec.loadDelayTime = 0
						end
						table.remove(spec.sortedObjectsToLoad, index)
						break
					end
					if not loadedObject then
						if #spec.sortedObjectsToLoad > 0 and lastObject then
							local i = #spec.sortedObjectsToLoad
							for _ = 1, #spec.sortedObjectsToLoad do
								local nextObject = spec.sortedObjectsToLoad[i]
								local lastObjectType = UniversalAutoload.getContainerType(lastObject)
								local nextObjectType = UniversalAutoload.getContainerType(nextObject)
								local shorterLog = nextObject~=nil and lastObject.isSplitShape and nextObject.isSplitShape and nextObject.sizeY <= lastObject.sizeY
								
								if lastObjectType == nextObjectType and not shorterLog then
									if debugLoading then print("DELETE SAME OBJECT TYPE: "..lastObjectType.name) end
									table.remove(spec.sortedObjectsToLoad, i)
								else
									i = i - 1
								end
							end
						end
						if #spec.sortedObjectsToLoad > 0 then
							-- if spec.trailerIsFull or (UniversalAutoload.testLoadAreaIsEmpty(self) and not spec.baleCollectionMode) then
								-- if debugLoading then print("RESET PATTERN to fill in any gaps") end
								-- spec.partiallyUnloaded = true
								-- spec.resetLoadingPattern = true
							-- end
						else
							if spec.activeLoading then
								if not spec.trailerIsFull and not self:ualGetIsMoving() then
									--print("ATTEMPT RELOAD")
									UniversalAutoload.startLoading(self)
								end
							else
							
								if spec.firstAttemptToLoad and not spec.baleCollectionMode and not self:ualGetIsMoving() then
									--UNABLE_TO_LOAD_OBJECT
									UniversalAutoload.showWarningMessage(self, 3)
									-- spec.partiallyUnloaded = true
									-- spec.resetLoadingPattern = true
								end
								if debugLoading then print("STOP LOADING") end
								UniversalAutoload.stopLoading(self)
							
							end
						end
					end
				else
					spec.loadSpeedFactor = spec.loadSpeedFactor or 1
					spec.loadDelayTime = spec.loadDelayTime + (spec.loadSpeedFactor*dt)
				end
			end
			
			-- DELAY AFTER LOAD/UNLOAD FOR MP POSITION SYNC
			if spec.doPostLoadDelay then
				spec.postLoadDelayTime = spec.postLoadDelayTime or 0
				local logDelay = spec.isLogTrailer and 1000 or 0
				local mpDelay = g_currentMission.missionDynamicInfo.isMultiplayer and 2000 or 0
				if spec.postLoadDelayTime > UniversalAutoload.DELAY_TIME + mpDelay + logDelay then
					UniversalAutoload.resetLoadingState(self)
				else
					spec.postLoadDelayTime = spec.postLoadDelayTime + dt
				end
			end
			
			UniversalAutoload.determineTipside(self)
			UniversalAutoload.countActivePallets(self)

		end
	end
end

function UniversalAutoload:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self.spec_universalAutoload
	
	if spec==nil or not spec.isAutoloadAvailable then
		return
	end

	if spec.stopError then
		if not spec.printedError then
			spec.printedError = true
			print("UAL - FATAL ERROR: " .. self:getFullName())
			print(spec.result)
		end
		return
	end
	
	local status, result = pcall(UniversalAutoload.doUpdate, self, dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)

	if not status then
		spec.stopError = true
		spec.result = result
	end
end

function UniversalAutoload:ualOnDeleteVehicle_Callback()
	UniversalAutoload.VEHICLES_LOOKUP[self] = nil
	if debugVehicles then print(self:getFullName() .. ": UAL DELETED") end
end


--
function UniversalAutoload:onActivate(isControlling)
	-- print("onActivate: "..self:getFullName())
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		if debugVehicles then print(self:getFullName() .. ": UAL DISABLED - onActivate") end
		return
	end
	
	if self.isServer then
		if debugVehicles then print("*** ACTIVE - "..self:getFullName().." ***") end
		UniversalAutoload.forceRaiseActive(self, true)
	end
	UniversalAutoload.lastClosestVehicle = nil
end
--
function UniversalAutoload:onDeactivate()
	-- print("onDeactivate: "..self:getFullName())
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		if debugVehicles then print(self:getFullName() .. ": UAL DISABLED - onDeactivate") end
		return
	end
	
	if self.isServer then
		if debugVehicles then print("*** NOT ACTIVE - "..self:getFullName().." ***") end
		UniversalAutoload.forceRaiseActive(self, false)
	end
	UniversalAutoload:clearActionEvents(self)
end
--
function UniversalAutoload:determineTipside()
	-- currently only used for the KRONE Profi Liner Curtain Trailer
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		if debugVehicles then print(self:getFullName() .. ": UAL DISABLED - determineTipside") end
		return
	end

	--<trailer tipSideIndex="1" doorState="false" tipAnimationTime="1.000000" tipState="2"/>
	if spec.isCurtainTrailer and self.spec_trailer then
		if self.spec_trailer.tipState == 2 then
			local tipSide = self.spec_trailer.tipSides[self.spec_trailer.currentTipSideIndex]
			
			if spec.currentTipside ~= "left" and string.find(tipSide.animation.name, "Left") then
				-- print("SET SIDE = LEFT")
				UniversalAutoload.setCurrentTipside(self, "left")
				UniversalAutoload.setCurrentLoadside(self, "left")	
			end
			if spec.currentTipside ~= "right" and string.find(tipSide.animation.name, "Right") then
				-- print("SET SIDE = RIGHT")
				UniversalAutoload.setCurrentTipside(self, "right")
				UniversalAutoload.setCurrentLoadside(self, "right")	
			end
		else
			if spec.currentTipside ~= "none" then
				-- print("SET SIDE = NONE")
				UniversalAutoload.setCurrentTipside(self, "none")
				UniversalAutoload.setCurrentLoadside(self, "none")
			end
		end
	end
	
	if spec.rearUnloadingOnly and spec.currentTipside ~= "rear" then
		UniversalAutoload.setCurrentTipside(self, "rear")
		UniversalAutoload.setCurrentLoadside(self, "rear")	
	end
	if spec.frontUnloadingOnly and spec.currentTipside ~= "front" then
		UniversalAutoload.setCurrentTipside(self, "front")
		UniversalAutoload.setCurrentLoadside(self, "front")	
	end
end
--
function UniversalAutoload:isValidForLoading(object)
	local spec = self.spec_universalAutoload
	local maxLength = spec.loadArea[spec.currentLoadAreaIndex or 1].length
	local minLength = spec.minLogLength or 0
	if minLength > maxLength or not spec.isLogTrailer then
		minLength = 0
	end
	
	if object == nil then
		if debugPallets then g_currentMission:addExtraPrintText("object == nil") end
		return false
	end
	
	if UniversalAutoload.disableAutoStrap and UniversalAutoload.isStrappedOnOtherVehicle(self, object) then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Strapped On Other Vehicle")
		end
		return false
	end
	if object.isSplitShape and UniversalAutoload.isLoadedOnTrain(self, object) then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Loaded On Train")
		end
		return false
	end
	if spec.baleCollectionMode and UniversalAutoload.isValidForManualLoading(object) then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Bale Collection Mode - manual loading")
		end
		return false
	end

	if object.isSplitShape and object.sizeY > maxLength then
		if debugPallets then
			g_currentMission:addExtraPrintText("Log - too long")
		end
		return false
	end
	if object.isSplitShape and object.sizeY < minLength then
		if debugPallets then
			g_currentMission:addExtraPrintText("Log - too short")
		end
		return false
	end
	if spec.isLogTrailer and not object.isSplitShape then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Log Trailer - not a log")
		end
		return false
	end
	if spec.baleCollectionMode and object.isRoundbale == nil then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Bale Collection Mode - not a bale")
		end
		return false
	end
	if object.isRoundbale ~= nil and object.mountObject then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Object Mounted")
		end
		return false
	end
	if object.spec_umbilicalReelOverload and object.spec_umbilicalReelOverload.isOverloading then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Umbilical Reel - overloading")
		end
		return false
	end
	if UniversalAutoload.ualGetPalletCanDischargeToTrailer(self, object) then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Pallet Can Discharge To Trailer")
		end
		return false
	end
	
	if not UniversalAutoload.getPalletIsSelectedMaterial(self, object) then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Pallet NOT Selected Material")
		end
		return false
	end
	if not UniversalAutoload.getPalletIsSelectedContainer(self, object) then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Pallet NOT Selected Container")
		end
		return false
	end
	
	local isBeingManuallyLoaded = spec.autoLoadingObjects[object] ~= nil
	local isValidLoadSide = spec.loadedObjects[object] == nil and UniversalAutoload.getPalletIsSelectedLoadside(self, object)
	if not (isBeingManuallyLoaded or isValidLoadSide) then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "NOT Valid Load Side")
		end
		return false
	end
	
	local isValidLoadFilter = not spec.currentLoadingFilter or (spec.currentLoadingFilter and UniversalAutoload.getPalletIsFull(object))
	if not (UniversalAutoload.manualLoadingOnly or isValidLoadFilter) then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "NOT Valid Load Filter")
		end
		return false
	end
	
	--if debugPallets then g_currentMission:addExtraPrintText(object.i3dFilename, "Valid For Loading") end
	return true
end
--
function UniversalAutoload:isValidForUnloading(object)
	local spec = self.spec_universalAutoload

	return UniversalAutoload.getPalletIsSelectedMaterial(self, object) and UniversalAutoload.getPalletIsSelectedContainer(self, object) and spec.autoLoadingObjects[object] == nil
end
--
function UniversalAutoload.isValidForManualLoading(object)
	if UniversalAutoload.disableManualLoading then
		return false
	end
	if object.isSplitShape then
		return false
	end
	if object.dynamicMountObject then
		return true
	end
	local pickedUpObject = UniversalAutoload.getObjectRootNode(object)
	-- if pickedUpObject and Player.PICKED_UP_OBJECTS[pickedUpObject] == true then
		-- return true
	-- end
	-- HandToolHands.getIsHoldingItem() ??
end
--
function UniversalAutoload:countActivePallets()
	-- print("COUNT ACTIVE PALLETS")
	local spec = self.spec_universalAutoload
	local isActiveForLoading = spec.isLoading or spec.isUnloading or spec.doPostLoadDelay
	
	if spec.countedPallets then
		return
	end
	spec.countedPallets = true
	
	local totalAvailableCount = 0
	local validLoadCount = 0
	if spec.availableObjects then
		for _, object in pairs(spec.availableObjects) do
			if object then
				totalAvailableCount = totalAvailableCount + 1
				if UniversalAutoload.isValidForLoading(self, object) then
					validLoadCount = validLoadCount + 1
				end
				if isActiveForLoading then
					UniversalAutoload.raiseObjectDirtyFlags(object)
				end
			end
		end
	end
	
	local totalUnloadCount = 0
	local validUnloadCount = 0
	if spec.loadedObjects then
		for object,_ in pairs(spec.loadedObjects) do
			if object then
				totalUnloadCount = totalUnloadCount + 1
				if UniversalAutoload.isValidForUnloading(self, object) then
					validUnloadCount = validUnloadCount + 1
				end
				if isActiveForLoading or spec.baleCollectionMode then
					UniversalAutoload.raiseObjectDirtyFlags(object)
				end
			end
		end
	end
	if debugLoading then
		g_currentMission:addExtraPrintText(self:getName() .. " Unload = " .. validUnloadCount .. " / " .. totalUnloadCount)
	end

	if (spec.validLoadCount ~= validLoadCount) or (spec.validUnloadCount ~= validUnloadCount) then
		local refreshMenuText = false
		if spec.validLoadCount ~= validLoadCount then
			if debugKeys then print("validLoadCount: "..spec.validLoadCount.."/"..validLoadCount) end
			if spec.validLoadCount==0 or validLoadCount==0 then
				refreshMenuText = true
			end
			spec.validLoadCount = validLoadCount
		end
		if spec.validUnloadCount ~= validUnloadCount then
			if debugKeys then print("validUnloadCount: "..spec.validUnloadCount.."/"..validUnloadCount) end
			if spec.validUnloadCount==0 or validUnloadCount==0 then
				refreshMenuText = true
			end
			spec.validUnloadCount = validUnloadCount
		end
		if refreshMenuText then
			UniversalAutoload.updateActionEventText(self)
		end
	end

	if debugLoading then
		if spec.totalAvailableCount ~= totalAvailableCount then
			print("TOTAL AVAILABLE COUNT ERROR: "..tostring(spec.totalAvailableCount).." vs "..tostring(totalAvailableCount))
			spec.totalAvailableCount = totalAvailableCount
		end
		if spec.totalUnloadCount ~= totalUnloadCount then
			print("TOTAL UNLOAD COUNT ERROR: "..tostring(spec.totalUnloadCount).." vs "..tostring(totalUnloadCount))
			spec.totalUnloadCount = totalUnloadCount
		end
	end
end
--
function UniversalAutoload:createBoundingBox()
	local spec = self.spec_universalAutoload

	if next(spec.loadedObjects) then
		spec.boundingBox = {}
		
		local x0, y0, z0 = math.huge, math.huge, math.huge
		local x1, y1, z1 = -math.huge, -math.huge, -math.huge
		for _, object in pairs(spec.loadedObjects) do
			-- print("  loaded object: " .. tostring(object.id).." ("..tostring(object.currentSavegameId or "BALE")..")")
			
			local node = UniversalAutoload.getObjectPositionNode(object)
			if node then
			
				local containerType = UniversalAutoload.getContainerType(object)
				local w, h, l = containerType.sizeX, containerType.sizeY, containerType.sizeZ
				local xx,xy,xz = localDirectionToLocal(node, spec.loadVolume.rootNode, w,0,0)
				local yx,yy,yz = localDirectionToLocal(node, spec.loadVolume.rootNode, 0,h,0)
				local zx,zy,zz = localDirectionToLocal(node, spec.loadVolume.rootNode, 0,0,l)
				
				local W, H, L = math.abs(xx+yx+zx), math.abs(xy+yy+zy), math.abs(xz+yz+zz)
				if containerType.flipYZ then
					L, H = math.abs(xy+yy+zy), math.abs(xz+yz+zz)
				end
				
				local X, Y, Z = localToLocal(node, spec.loadVolume.rootNode, 0, 0, 0)
				if containerType.isBale then Y = Y-(H/2) end
				
				-- include object in bounding box
				if x0 > X-(W/2) then x0 = X-(W/2) end
				if x1 < X+(W/2) then x1 = X+(W/2) end
				if y0 > Y then y0 = Y end
				if y1 < Y+(H) then y1 = Y+(H) end
				if z0 > Z-(L/2) then z0 = Z-(L/2) end
				if z1 < Z+(L/2) then z1 = Z+(L/2) end
				
			end
		end
		
		-- create bounding box for all objects
		local width = x1-x0
		local height = y1-y0
		local length = z1-z0
		
		local offsetX, offsetY, offsetZ = (x0+x1)/2, y0, (z0+z1)/2
		
		if debugLoading then
			print(string.format("(W,H,L) = (%f, %f, %f)", width, height, length))
			print(string.format("(X,Y,Z) = (%f, %f, %f)", offsetX, offsetY, offsetZ))
			print(string.format("(X0,Y0,Z0) = (%f, %f, %f)", localToWorld(spec.loadVolume.rootNode, 0, 0, 0)))
		end

		spec.boundingBox.rootNode = createTransformGroup("loadVolumeCentre")
		link(spec.loadVolume.rootNode, spec.boundingBox.rootNode)
		setTranslation(spec.boundingBox.rootNode, offsetX, offsetY, offsetZ)
		
		spec.boundingBox.width = x1-x0
		spec.boundingBox.height = y1-y0
		spec.boundingBox.length = z1-z0
	else
		spec.boundingBox = nil
	end
end

-- LOADING AND UNLOADING FUNCTIONS
function UniversalAutoload:loadObject(object, chargeForLoading)
	-- print("UniversalAutoload - loadObject")
	if object and UniversalAutoload.getIsLoadingVehicleAllowed(self) and UniversalAutoload.isValidForLoading(self, object) then

		local spec = self.spec_universalAutoload
		local containerType = UniversalAutoload.getContainerType(object)

		local loadPlace = UniversalAutoload.getLoadPlace(self, containerType, object)
		if loadPlace then
		
			--ALTERNATE LOG ORIENTATION FOR EACH LAYER
			local rotateLogs = object.isSplitShape and (math.random(0,1) > 0.5);
			if UniversalAutoload.moveObjectNodes(self, object, loadPlace, true, rotateLogs) then
				UniversalAutoload.clearPalletFromAllVehicles(self, object)
				UniversalAutoload.addLoadedObject(self, object)
				
				if chargeForLoading == true then
					if object.isSplitShape then
						if UniversalAutoload.pricePerLog > 0 then
							g_currentMission:addMoney(-UniversalAutoload.pricePerLog, self:getOwnerFarmId(), MoneyType.AI, true, true)
						end
					elseif object.isRoundbale ~= nil then
						if UniversalAutoload.pricePerBale > 0 then
							g_currentMission:addMoney(-UniversalAutoload.pricePerBale, self:getOwnerFarmId(), MoneyType.AI, true, true)
						end
					elseif UniversalAutoload.pricePerPallet > 0 then
						g_currentMission:addMoney(-UniversalAutoload.pricePerPallet, self:getOwnerFarmId(), MoneyType.AI, true, true)
					end
				end
			
				if debugLoading then
					print(string.format("LOADED TYPE: %s [%.3f, %.3f, %.3f]",
					containerType.name, containerType.sizeX, containerType.sizeY, containerType.sizeZ))
				end
				return true
			end
		end

	end

	return false
end
--
function UniversalAutoload:unloadObject(object, unloadPlace)
	-- print("UniversalAutoload - unloadObject")
	if object and UniversalAutoload.isValidForUnloading(self, object) then
	
		if UniversalAutoload.moveObjectNodes(self, object, unloadPlace, false, false) then
			UniversalAutoload.clearPalletFromAllVehicles(self, object)
			return true
		end
	end
end
--
function UniversalAutoload.buildObjectsToUnloadTable(vehicle, forceUnloadPosition)
	local spec = vehicle.spec_universalAutoload
	
	spec.objectsToUnload = spec.objectsToUnload or {}
	for k, v in pairs(spec.objectsToUnload) do
		delete(v.node)
		spec.objectsToUnload[k] = nil
	end

	spec.unloadingAreaClear = true
	
	
	local _, HEIGHT, _ = getTranslation(spec.loadVolume.rootNode)
	for _, object in pairs(spec.loadedObjects) do
		if UniversalAutoload.isValidForUnloading(vehicle, object) then
		
			local node = UniversalAutoload.getObjectPositionNode(object)
			if node then
				x, y, z = localToLocal(node, spec.loadVolume.rootNode, 0, 0, 0)
				rx, ry, rz = localRotationToLocal(node, spec.loadVolume.rootNode, 0, 0, 0)
				
				local unloadPlace = {}
				local containerType = UniversalAutoload.getContainerType(object)
				unloadPlace.sizeX = containerType.sizeX
				unloadPlace.sizeY = containerType.sizeY
				unloadPlace.sizeZ = containerType.sizeZ
				if containerType.flipYZ then
					unloadPlace.sizeY = containerType.sizeZ
					unloadPlace.sizeZ = containerType.sizeY
					unloadPlace.wasFlippedYZ = true
				end
				
				local offsetX = 0
				local offsetY = 0
				local offsetZ = 0
				
				if forceUnloadPosition then
					if forceUnloadPosition == "rear" or forceUnloadPosition == "behind" then
						offsetZ = -spec.loadVolume.length - spec.loadVolume.width/2
					elseif forceUnloadPosition == "left" then
						offsetX = 1.5*spec.loadVolume.width
					elseif forceUnloadPosition == "right" then
						offsetX = -1.5*spec.loadVolume.width
					end
				else
					if spec.frontUnloadingOnly then
						offsetZ = spec.loadVolume.length + spec.loadVolume.width/2
					elseif spec.rearUnloadingOnly then
						offsetZ = -spec.loadVolume.length - spec.loadVolume.width/2
					else
						if spec.isLogTrailer then
							offsetX = 2*spec.loadVolume.width
						else
							offsetX = 1.5*spec.loadVolume.width
						end
						if spec.currentTipside == "right" then offsetX = -offsetX end
					end
				end
				
				offsetX = offsetX - containerType.offset.x
				offsetY = offsetY - containerType.offset.y
				offsetZ = offsetZ - containerType.offset.z

				unloadPlace.node = createTransformGroup("unloadPlace")
				link(spec.loadVolume.rootNode, unloadPlace.node)
				setTranslation(unloadPlace.node, x+offsetX, y+offsetY, z+offsetZ)
				setRotation(unloadPlace.node, rx, ry, rz)

				local X, Y, Z = getWorldTranslation(unloadPlace.node)
				local heightAboveGround = DensityMapHeightUtil.getCollisionHeightAtWorldPos(X, Y, Z) + 0.1
				unloadPlace.heightAbovePlace = math.max(0, y)
				unloadPlace.heightAboveGround = math.max(-(HEIGHT+y), heightAboveGround-Y)
				spec.objectsToUnload[object] = unloadPlace
			end
		end
	end
	
	for object, unloadPlace in pairs(spec.objectsToUnload) do
		local thisAreaClear = false
		local x, y, z = getTranslation(unloadPlace.node)
		
		if #spec.loadArea > 1 then
			local i = spec.objectToLoadingAreaIndex[object] or 1
			local _, offsetY, _ = localToLocal(spec.loadArea[i].rootNode, spec.loadVolume.rootNode, 0, 0, 0)
			y = y - offsetY
		end
		
		local height = unloadPlace.heightAboveGround
		local offset = unloadPlace.heightAbovePlace
		setTranslation(unloadPlace.node, x, y+offset+height, z)
		thisAreaClear = true
		
		-- for height = unloadPlace.heightAboveGround, 0, 0.1 do
			-- setTranslation(unloadPlace.node, x, y+height, z)
			-- if UniversalAutoload.testUnloadLocationIsEmpty(vehicle, unloadPlace) then
				-- local offset = unloadPlace.heightAbovePlace
				-- setTranslation(unloadPlace.node, x, y+offset+height, z)
				-- thisAreaClear = true
				-- break
			-- end
		-- end
		-- if (not thisAreaClear and not object.isSplitShape and not object.isRoundbale) or unloadPlace.heightAboveGround > 0 then
			-- spec.unloadingAreaClear = false
		-- end
	end
end
--
function UniversalAutoload.clearPalletFromAllVehicles(self, object)
	for _, vehicle in pairs(UniversalAutoload.VEHICLES) do
		if vehicle then
			local loadedObjectRemoved = UniversalAutoload.removeLoadedObject(vehicle, object)
			local availableObjectRemoved = UniversalAutoload.removeAvailableObject(vehicle, object)
			local autoLoadingObjectRemoved = UniversalAutoload.removeAutoLoadingObject(vehicle, object)
			if loadedObjectRemoved or availableObjectRemoved then
				if self ~= vehicle then
					local SPEC = vehicle.spec_universalAutoload
					if SPEC.totalUnloadCount == 0 then
						if debugLoading then
							print(" Clear Pallet from " .. vehicle:getFullName())
						end
						UniversalAutoload.resetLoadingArea(vehicle)
						vehicle:setAllTensionBeltsActive(false)
					elseif loadedObjectRemoved then
						if vehicle.spec_tensionBelts.areBeltsFasten then
							vehicle:setAllTensionBeltsActive(false)
							vehicle:setAllTensionBeltsActive(true)
						end
					end
				end
				UniversalAutoload.forceRaiseActive(vehicle)
			end
		end
	end
end	
--
function UniversalAutoload.isStrappedOnOtherVehicle(self, object)
	for _, vehicle in pairs(UniversalAutoload.VEHICLES) do
		if vehicle and self ~= vehicle then
			if vehicle.spec_universalAutoload.loadedObjects[object] then
				if vehicle.spec_tensionBelts.areBeltsFasten then
					return vehicle
				end
			end
		end
	end
end
--
function UniversalAutoload.isLoadedOnTrain(self, object)
	for _, vehicle in pairs(UniversalAutoload.VEHICLES) do
		if vehicle and self ~= vehicle then
			local rootVehicle = vehicle:getRootVehicle()
			if rootVehicle and rootVehicle:getFullName():find("Locomotive") then
				if vehicle.spec_universalAutoload.loadedObjects[object] then
					return true
				end
			end
		end
	end
end
--
function UniversalAutoload.unmountDynamicMount(object)
	if object.dynamicMountObject then
		local vehicle = object.dynamicMountObject
		-- print("Remove Dynamic Mount from: "..vehicle:getFullName())
		vehicle:removeDynamicMountedObject(object, true)
		object:unmountDynamic()
		if object.additionalDynamicMountJointNode then
			delete(object.additionalDynamicMountJointNode)
			object.additionalDynamicMountJointNode = nil
		end
	end
end

function UniversalAutoload:createLoadingPlace(containerType)
	local spec = self.spec_universalAutoload
	
	spec.currentLoadingPlace = nil
	
	spec.currentLoadWidth = spec.currentLoadWidth or 0
	spec.currentLoadLength = spec.currentLoadLength or 0
	
	spec.currentActualWidth = spec.currentActualWidth or 0
	spec.currentActualLength = spec.currentActualLength or 0
	
	local i = spec.currentLoadAreaIndex or 1
	
	--DEFINE CONTAINER SIZES
	local sizeX = containerType.sizeX
	local sizeY = containerType.sizeY
	local sizeZ = containerType.sizeZ
	local containerSizeX = containerType.sizeX
	local containerSizeY = containerType.sizeY
	local containerSizeZ = containerType.sizeZ
	local containerFlipYZ = containerType.flipYZ
	local isRoundbale = containerType.isRoundbale
	
	--TEST FOR ROUNDBALE PACKING
	if isRoundbale == true then
		if spec.useHorizontalLoading then
		-- LONGWAYS ROUNDBALE STACKING
			containerSizeY = containerType.sizeZ
			containerSizeZ = containerType.sizeY
			--containerFlipYZ = false
		end
	end
	
	--CALCUATE POSSIBLE ARRAY SIZES
	local width = spec.loadArea[i].width
	local length = spec.loadArea[i].length
	
	--ALTERNATE LOG PACKING FOR EACH LAYER
	if spec.isLogTrailer then
		local N = math.floor(width / containerSizeZ)
		if N > 1 and spec.currentLayerCount % 2 ~= 0 then
			width = (N-1) * containerSizeZ
		end
	end
	
	--CALCULATE PACKING DIMENSIONS
	local N1 = math.floor(width / containerSizeX)
	local M1 = math.floor(length / containerSizeZ)
	local N2 = math.floor(width / containerSizeZ)
	local M2 = math.floor(length / containerSizeX)
	
	--CHOOSE BEST PACKING ORIENTATION
	local N, M, rotation
	local shouldRotate = ((N2*M2) > (N1*M1)) or (((N2*M2)==(N1*M1)) and (N1>N2) and (N2*M2)>0)
	local doRotate = (containerType.alwaysRotate or shouldRotate) and not containerType.neverRotate
	
	--ALWAYS ROTATE ROUNDBALES WITH HORIZONTAL LOADING
	if isRoundbale == true and spec.useHorizontalLoading then
		doRotate = true
	end

	if debugLoading then
		print("-------------------------------")
		print("width: " .. tostring(width) )
		print("length: " .. tostring(length) )
		print(" N1: "..N1.. " ,  M1: "..M1)
		print(" N2: "..N2.. " ,  M2: "..M2)
		print("neverRotate: " .. tostring(containerType.neverRotate) )
		print("alwaysRotate: " .. tostring(containerType.alwaysRotate) )
		print("shouldRotate: " .. tostring(shouldRotate) )
		print("doRotate: " .. tostring(doRotate) )
	end
	
	local N, M = N1, M1
	local rotation = 0
	
	-- APPLY ROTATION
	if doRotate then
		N, M = N2, M2
		rotation = math.pi/2
		sizeX = containerType.sizeZ
		sizeY = containerType.sizeY
		sizeZ = containerType.sizeX
	end
	
	--TEST FOR ROUNDBALE PACKING
	local r = 0.70710678
	local R = ((3/4)+(r/4))
	local roundbaleOffset = 0
	local useRoundbalePacking = nil
	if isRoundbale then
		if spec.useHorizontalLoading then
		-- HORIZONAL ROUNDBALE PACKING
			rotation = math.pi/2
			useRoundbalePacking = false
		else
		-- UPRIGHT ROUNDBALE STACKING
			NR = math.floor(width / (R*containerType.sizeX))
			MR = math.floor(length / (R*containerType.sizeX))
			if NR > N and width >= (2*R)*containerType.sizeX then
				useRoundbalePacking = true
				N, M = NR, MR
				sizeX = R*containerType.sizeX
			end
		end
	end
	
	--UPDATE NEW PACKING DIMENSIONS
	local addedLoadWidth = sizeX
	local addedLoadLength = sizeZ
	if useRoundbalePacking == false then
		addedLoadWidth = sizeY
	end
	spec.currentLoadHeight = 0	
	if spec.currentLoadWidth == 0 or spec.currentLoadWidth + addedLoadWidth > spec.loadArea[i].width then
		spec.currentLoadWidth = addedLoadWidth
		spec.currentActualWidth = (N * addedLoadWidth)
		spec.currentActualLength = spec.currentLoadLength
		spec.currentLoadLength = spec.currentLoadLength + addedLoadLength
		if spec.isLogTrailer and spec.currentActualLength ~= 0 then
			spec.currentLoadLength = spec.currentLoadLength + UniversalAutoload.LOG_SPACE
		end
	else
		spec.currentLoadWidth = spec.currentLoadWidth + addedLoadWidth
	end

	if spec.currentLoadLength == 0 then
		print("LOAD LENGTH WAS ZERO")
		spec.currentLoadLength = sizeZ
	end
	
	if useRoundbalePacking == false then
		
		local baleEnds = true
		local layerOffset = spec.currentLayerCount * containerSizeX/2
		
		-- FIRST BALE ON A LAYER
		if spec.currentLoadLength == containerSizeX then
			-- if baleEnds and spec.currentLayerCount == 0 then
				-- spec.currentLoadLength = spec.currentLoadLength + containerSizeX
			-- end
			spec.currentLoadLength = spec.currentLoadLength + layerOffset
		end
		
		-- LAST BALE ON A LAYER
		if spec.currentLoadLength > spec.loadArea[i].length - layerOffset then
			spec.currentLoadLength = spec.currentLoadLength + layerOffset + containerSizeX
		end
		
		-- LAST BALE ON FIRST LAYER
		-- if baleEnds and spec.currentLayerCount == 0 and spec.currentLoadLength > spec.loadArea[i].length - containerSizeX then
			-- spec.currentLoadLength = spec.currentLoadLength + containerSizeX
		-- end
		

	elseif useRoundbalePacking == true then
		if (spec.currentLoadWidth/sizeX) % 2 == 0 then
			roundbaleOffset = containerSizeZ/2
		end
	end
	
	if debugLoading then
		print("LoadingAreaIndex: " .. tostring(spec.currentLoadAreaIndex) )
		print("currentLoadWidth: " .. tostring(spec.currentLoadWidth) )
		print("currentLoadLength: " .. tostring(spec.currentLoadLength) )
		print("currentActualWidth: " .. tostring(spec.currentActualWidth) )
		print("currentActualLength: " .. tostring(spec.currentActualLength) )
		print("currentLoadHeight: " .. tostring(spec.currentLoadHeight) )
		print("currentLayerCount: " .. tostring(spec.currentLayerCount) )
		print("currentLayerHeight: " .. tostring(spec.currentLayerHeight) )
		print("nextLayerHeight: " .. tostring(spec.nextLayerHeight) )
		print("-------------------------------")
	end
	
	if spec.currentLoadLength<=spec.loadArea[i].length and spec.currentLoadWidth<=spec.currentActualWidth then
		-- print("CREATE NEW LOADING PLACE")
		loadPlace = {}
		loadPlace.node = createTransformGroup("loadPlace")
		loadPlace.sizeX = containerSizeX
		loadPlace.sizeY = containerSizeY
		loadPlace.sizeZ = containerSizeZ
		loadPlace.flipYZ = containerFlipYZ
		loadPlace.isRoundbale = isRoundbale
		loadPlace.roundbaleOffset = roundbaleOffset
		loadPlace.useRoundbalePacking = useRoundbalePacking
		loadPlace.containerType = containerType
		loadPlace.rotation = rotation
		if useRoundbalePacking == true then
			loadPlace.sizeX = r*containerSizeX
			loadPlace.sizeZ = r*containerSizeZ
		end
		if containerType.isBale then
			loadPlace.baleOffset = containerSizeY/2
		end
		
		--LOAD FROM THE CORRECT SIDE
		local posX = -( spec.currentLoadWidth - (spec.currentActualWidth/2) - (addedLoadWidth/2) )
		local posZ = -( spec.currentLoadLength - (addedLoadLength/2) ) - roundbaleOffset
		if spec.currentLoadside == "left" then posX = -posX end

		--SET POSITION AND ORIENTATION
		loadPlace.offset = {
			x = -containerType.offset.x,
			y = -containerType.offset.y,
			z = -containerType.offset.z,
		}

		local offset = loadPlace.offset
		link(spec.loadArea[i].startNode, loadPlace.node)
		setTranslation(loadPlace.node, posX+offset.x, 0+offset.y, posZ+offset.z)
		setRotation(loadPlace.node, 0, rotation, 0)
		
		--STORE AS CURRENT LOADING PLACE
		spec.currentLoadingPlace = loadPlace
		
		spec.lastLoadAttempt = {
			loadPlace = deepCopy(loadPlace),
			containerType = containerType,
		}
		
		-- print("offsetX: " .. tostring(offset.x))
		-- print("offsetY: " .. tostring(offset.y))
		-- print("offsetZ: " .. tostring(offset.z))
		
		-- DebugUtil.printTableRecursively(loadPlace, "--", 0, 1)
		-- DebugUtil.printTableRecursively(containerType, "--", 0, 1)
		
	end
end
--
function UniversalAutoload:resetLoadingPattern()
	local spec = self.spec_universalAutoload
	if debugLoading then print("["..self.rootNode.."] RESET loading pattern") end
	spec.currentLoadWidth = 0
	spec.currentLoadHeight = 0
	spec.currentLoadLength = 0
	spec.currentActualWidth = 0
	spec.currentActualLength = 0
	spec.currentLoadingPlace = nil
	spec.resetLoadingPattern = false
end
--
function UniversalAutoload:resetLoadingLayer()
	local spec = self.spec_universalAutoload
	if debugLoading then print("["..self.rootNode.."] RESET loading layer") end
	spec.nextLayerHeight = 0
	spec.currentLayerCount = 0
	spec.currentLayerHeight = 0
	spec.resetLoadingLayer = false
end
--
function UniversalAutoload:resetLoadingArea()
	local spec = self.spec_universalAutoload
	if debugLoading then print("["..self.rootNode.."] RESET loading area") end
	UniversalAutoload.resetLoadingLayer(self)
	UniversalAutoload.resetLoadingPattern(self)
	spec.trailerIsFull = false
	spec.partiallyUnloaded = false
	spec.currentLoadAreaIndex = 1
	spec.lastLoadAttempt = nil
end
--
function UniversalAutoload:getLoadPlace(containerType, object)
	local spec = self.spec_universalAutoload
	
	if containerType==nil or (spec.trailerIsFull and not spec.partiallyUnloaded) then
		return
	end
	
	if not self:ualGetIsMoving() or spec.baleCollectionMode then
		if debugLoading then
			print("")
			print("===============================")
		end
		print("["..self.rootNode.."] FIND LOADING PLACE FOR "..containerType.name)
		
		if spec.isLogTrailer then
			spec.resetLoadingPattern = true
		end

		local i = spec.currentLoadAreaIndex or 1
		while i <= #spec.loadArea do
			if spec.resetLoadingPattern ~= false then
				UniversalAutoload.resetLoadingPattern(self)
			end
		
			if UniversalAutoload.getIsLoadingAreaAllowed(self, i) then
			
				spec.nextLayerHeight = spec.nextLayerHeight or 0
				spec.currentLoadHeight = spec.currentLoadHeight or 0
				spec.currentLayerCount = spec.currentLayerCount or 0
				spec.currentLayerHeight = spec.currentLayerHeight or 0

				local containerSizeX = containerType.sizeX
				local containerSizeY = containerType.sizeY
				local containerSizeZ = containerType.sizeZ
				local containerFlipYZ = containerType.flipYZ

				--TEST FOR ROUNDBALE PACKING
				if containerType.isBale and containerType.isRoundbale then
					if spec.useHorizontalLoading then
					-- LONGWAYS ROUNDBALE STACKING
						containerSizeY = containerType.sizeZ * UniversalAutoload.ROTATED_BALE_FACTOR
						containerSizeZ = containerType.sizeY
					end
				end
				
				local mass = UniversalAutoload.getContainerMass(object)
				local volume = containerSizeX * containerSizeY * containerSizeZ
				local density = math.min(mass/volume, 1.5)
				local appliedFrontOffset = false
			
				while spec.currentLoadLength <= spec.loadArea[i].length do

					local maxLoadAreaHeight = spec.loadArea[i].height
					if containerType.isBale and spec.loadArea[i].baleHeight then
						maxLoadAreaHeight = spec.loadArea[i].baleHeight
					end
					
					if (spec.currentLoadHeight > 0 or spec.useHorizontalLoading) and maxLoadAreaHeight > containerSizeY
					and not spec.disableHeightLimit and not spec.isLogTrailer then
						if density > 0.5 then
							maxLoadAreaHeight = maxLoadAreaHeight * (7-(2*density))/6
						end
						if maxLoadAreaHeight > 5*containerSizeY then
							maxLoadAreaHeight = 5*containerSizeY
						end
					end
					
					local loadOverMaxHeight = spec.currentLoadHeight + containerSizeY > maxLoadAreaHeight
					local layerOverMaxHeight = spec.currentLayerHeight + containerSizeY > maxLoadAreaHeight
					local isFirstLayer = (spec.isLogTrailer or spec.useHorizontalLoading) and spec.currentLayerCount == 0
					local ignoreHeightForContainer = isFirstLayer and not (spec.isCurtainTrailer or spec.isBoxTrailer)
					if spec.currentLoadingPlace and spec.currentLoadHeight==0 and loadOverMaxHeight and not ignoreHeightForContainer then
						if debugLoading then print("CONTAINER IS TOO TALL FOR THIS AREA") end
						return
					else
						if spec.currentLoadingPlace and loadOverMaxHeight then
							if ((object.isSplitShape or containerType.isBale) and not spec.zonesOverlap) or
							UniversalAutoload.testLocationIsFull(self, spec.currentLoadingPlace) then
								if debugLoading then print("LOADING PLACE IS FULL - SET TO NIL") end
								spec.currentLoadingPlace = nil
							else
								if debugLoading then print("PALLET IS MISSING FROM PREVIOUS PLACE - TRY AGAIN") end
							end
						end
						if not spec.currentLoadingPlace or spec.useHorizontalLoading or spec.isLogTrailer then
							if not spec.useHorizontalLoading or (spec.useHorizontalLoading and (ignoreHeightForContainer or not layerOverMaxHeight)) then
								if debugLoading then print(string.format("ADDING NEW PLACE FOR: %s [%.3f, %.3f, %.3f]",
								containerType.name, containerSizeX, containerSizeY, containerSizeZ)) end
								if containerType.frontOffset > 0 and spec.currentLoadLength == 0 and spec.totalUnloadCount == 0 then
									spec.currentLoadLength = containerType.frontOffset + 0.005
									appliedFrontOffset = true
								end
								UniversalAutoload.createLoadingPlace(self, containerType)
							else
								if debugLoading then print("REACHED MAX LAYER HEIGHT") end
								spec.currentLoadingPlace = nil
								spec.trailerIsFull = true
								break
							end
						end
					end

					local thisLoadPlace = spec.currentLoadingPlace
					if thisLoadPlace then
						if debugLoading then print("TRY NEW LOAD PLACE..") end
					
						local containerFitsInLoadSpace = spec.isLogTrailer or 
							(thisLoadPlace.useRoundbalePacking and containerType.isRoundbale) or
							(containerSizeX <= thisLoadPlace.sizeX and containerSizeZ <= thisLoadPlace.sizeZ)
						local containerStackBelowLimit = (spec.currentLoadHeight == 0) or
							(spec.currentLoadHeight + containerSizeY <= maxLoadAreaHeight)
						if debugLoading then 
							print("containerFitsInLoadSpace = " .. tostring(containerFitsInLoadSpace))
							print("containerStackBelowLimit = " .. tostring(containerStackBelowLimit))
							print("layerOverMaxHeight = " .. tostring(layerOverMaxHeight))
							print("currentLoadHeight = " .. tostring(spec.currentLoadHeight))
						end
	
						if containerFitsInLoadSpace then
							
							local offset = thisLoadPlace.offset
							local x0,_,z0 = getTranslation(thisLoadPlace.node)
							setTranslation(thisLoadPlace.node, x0, spec.currentLoadHeight+offset.y, z0)
							
							local useThisLoadSpace = false
							spec.loadSpeedFactor = 1
							
							if spec.isLogTrailer then
								
								if debugLoading then print("LOG TRAILER") end
								if not self:ualGetIsMoving() then
									local logLoadHeight = maxLoadAreaHeight + 0.1
									if not spec.zonesOverlap then
										logLoadHeight = math.min(spec.currentLayerHeight, maxLoadAreaHeight) + 0.1
									end
									setTranslation(thisLoadPlace.node, x0, logLoadHeight+offset.y, z0)
									if UniversalAutoload.testLocationIsEmpty(self, thisLoadPlace, object) then
										spec.currentLoadHeight = spec.currentLayerHeight
										local massFactor = math.clamp((1/mass)/2, 0.2, 1)
										local heightFactor = maxLoadAreaHeight/(maxLoadAreaHeight+spec.currentLoadHeight)
										spec.loadSpeedFactor = math.clamp(heightFactor*massFactor, 0.1, 0.5)
										-- print("loadSpeedFactor: " .. spec.loadSpeedFactor)
										useThisLoadSpace = true
									end
								end

							elseif spec.baleCollectionMode then
								
								if debugLoading then print("BALE COLLECTION MODE") end
								if (containerType.isBale and not spec.zonesOverlap and not spec.partiallyUnloaded) then
									if spec.useHorizontalLoading then
										spec.currentLoadHeight = spec.currentLayerHeight
										setTranslation(thisLoadPlace.node, x0, spec.currentLayerHeight+offset.y, z0)
										if debugLoading then print("useHorizontalLoading: " .. spec.currentLayerHeight) end
									end
									spec.loadSpeedFactor = 2
									useThisLoadSpace = true
								else
									if debugLoading then print("NOT A BALE") end
									return
								end
								
							else
								
								if not self:ualGetIsMoving() then
									if spec.useHorizontalLoading then
										if debugLoading then print("HORIZONTAL LOADING...") end
										if not layerOverMaxHeight or (isFirstLayer and ignoreHeightForContainer) then
											if debugLoading and isFirstLayer and ignoreHeightForContainer then
												print("IGNORE HEIGHT FOR CONTAINER")
											end
											spec.currentLoadHeight = spec.currentLayerHeight
											setTranslation(thisLoadPlace.node, x0, spec.currentLayerHeight+offset.y, z0)
											if debugLoading then print("useHorizontalLoading: " .. spec.currentLayerHeight) end
											useThisLoadSpace = true
										end
									else
										if debugLoading then print("STACK LOADING...") end
										if containerStackBelowLimit then
											-- local placeEmpty = UniversalAutoload.testLocationIsEmpty(self, thisLoadPlace, object)
											-- local placeBelowFull = UniversalAutoload.testLocationIsFull(self, thisLoadPlace, -containerSizeY)
											-- print("placeEmpty: " .. tostring(placeEmpty))
											-- print("placeBelowFull: " .. tostring(placeBelowFull))
											useThisLoadSpace = true
										end
									end
								end
							end
							
							if useThisLoadSpace then
								-- UniversalAutoload.testLocation(self)
								if containerType.neverStack then
									if debugLoading then print("NEVER STACK") end
									spec.currentLoadingPlace = nil
								end
								
								local newLoadHeight = containerSizeY
								if thisLoadPlace.useRoundbalePacking == false then
									newLoadHeight = newLoadHeight * UniversalAutoload.ROTATED_BALE_FACTOR
								end
								
								spec.currentLoadHeight = spec.currentLoadHeight + newLoadHeight
								spec.nextLayerHeight = math.max(spec.currentLoadHeight, spec.nextLayerHeight)
								
								if debugLoading then print("USING LOAD PLACE - height: " .. tostring(spec.currentLoadHeight)) end
								return thisLoadPlace
							end
						end
					end

					if debugLoading then print("DID NOT FIT HERE...") end
					spec.currentLoadingPlace = nil
					if appliedFrontOffset then
						spec.currentLoadLength = 0
					end
				end
			end
			i = i + 1
			spec.resetLoadingPattern = true
			if #spec.loadArea > 1 and i <= #spec.loadArea then
				if debugLoading then print("TRY NEXT LOADING AREA ("..tostring(i)..")...") end
				spec.currentLoadAreaIndex = i
			end
		end
		spec.currentLoadAreaIndex = 1
		if (spec.isLogTrailer and spec.currentLayerCount < UniversalAutoload.MAX_LAYER_COUNT)
		or (spec.useHorizontalLoading and spec.currentLayerCount < UniversalAutoload.MAX_LAYER_COUNT)
		and not ((spec.baleCollectionMode and spec.nextLayerHeight == 0) or spec.trailerIsFull == true) then
			spec.currentLayerCount = spec.currentLayerCount + 1
			spec.currentLoadingPlace = nil
			if not spec.isLogTrailer or (spec.isLogTrailer and spec.nextLayerHeight > 0) then
				spec.currentLayerHeight = spec.nextLayerHeight
				spec.nextLayerHeight = 0
			end
			if debugLoading then
				print("START NEW LAYER")
				print("currentLayerCount: " .. spec.currentLayerCount)
				print("currentLayerHeight: " .. spec.currentLayerHeight)
			end
			return UniversalAutoload.getLoadPlace(self, containerType, object)
		else
			spec.trailerIsFull = true
			if spec.baleCollectionMode == true then
				if debugSpecial then print("baleCollectionMode: trailerIsFull") end
				UniversalAutoload.setBaleCollectionMode(self, false)
			end
			if debugLoading then print("FULL - NO MORE ROOM") end
		end
		if debugLoading then print("===============================") end
	else
		if not spec.activeLoading then
			if debugLoading then print("CAN'T LOAD WHEN MOVING...") end
			--NO_LOADING_UNLESS_STATIONARY
			UniversalAutoload.showWarningMessage(self, 4)
		end
	end
end

-- OBJECT PICKUP LOGIC FUNCTIONS
function UniversalAutoload:getIsValidObject(object)
	local spec = self.spec_universalAutoload
	
	if object.isSplitShape then
		if not entityExists(object.nodeId) then
			print("SplitShape - DOES NOT EXIST..")
			UniversalAutoload.removeSplitShapeObject(self, object)
			return false
		else
			return false --DISABLE LOGS FOR NOW.. true
		end
	end
	
	if object.i3dFilename then
		-- object.typeName
		-- object.isRoundbale ~= nil
		
		if g_currentMission.accessHandler:canFarmAccess(self:getActiveFarm(), object) then
			return UniversalAutoload.getContainerType(object) ~= nil
		end
	end
	
	if debugPallets then print("Invalid Object - " .. object.i3dFilename, tostring(object.typeName)) end
	return false
end

function UniversalAutoload:getIsLoadingKeyAllowed()
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		if debugVehicles then print(self:getFullName() .. ": UAL DISABLED - getIsLoadingKeyAllowed") end
		return
	end

	if spec.doPostLoadDelay or spec.validLoadCount == 0 or spec.currentLoadside == "none" then
		return false
	end
	if spec.baleCollectionMode then
		return false
	end
	return UniversalAutoload.getIsLoadingVehicleAllowed(self)
end
--
function UniversalAutoload:getIsUnloadingKeyAllowed()
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		if debugVehicles then print(self:getFullName() .. ": UAL DISABLED - getIsUnloadingKeyAllowed") end
		return
	end

	if spec.doPostLoadDelay or spec.isLoading or spec.isUnloading
	or spec.validUnloadCount == 0 or spec.currentTipside == "none" then
		return false
	end
	if spec.isBoxTrailer and spec.noLoadingIfFolded and (self:ualGetIsFolding() or not self:getIsUnfolded()) then
		return false
	end
	if spec.isBoxTrailer and spec.noLoadingIfUnfolded and (self:ualGetIsFolding() or self:getIsUnfolded()) then
		return false
	end
	if spec.noLoadingIfCovered and self:ualGetIsCovered() then
		return false
	end
	if spec.noLoadingIfUncovered and not self:ualGetIsCovered() then
		return false
	end
	if spec.baleCollectionMode then
		return false
	end
	return true
end
--
function UniversalAutoload:getIsLoadingVehicleAllowed(triggerId)
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		if debugVehicles then print(self:getFullName() .. ": UAL DISABLED - getIsLoadingVehicleAllowed") end
		return false
	end
	
	if self:ualGetIsFilled() then
		-- print("ualGetIsFilled")
		return false
	end
	if spec.noLoadingIfFolded and (self:ualGetIsFolding() or not self:getIsUnfolded()) then
		-- print("noLoadingIfFolded")
		return false
	end
	if spec.noLoadingIfUnfolded and (self:ualGetIsFolding() or self:getIsUnfolded()) then
		-- print("noLoadingIfUnfolded")
		return false
	end
	if spec.noLoadingIfCovered and self:ualGetIsCovered() then
		-- print("noLoadingIfCovered")
		return false
	end
	if spec.noLoadingIfUncovered and not self:ualGetIsCovered() then
		-- print("noLoadingIfUncovered")
		return false
	end
	
	-- check that curtain trailers have an open curtain
	if spec.isCurtainTrailer and triggerId then
		-- print("CURTAIN TRAILER")
		local tipState = self:getTipState()
		local doorOpen = self:getIsUnfolded()
		local rearTrigger = triggerId == spec.rearTriggerId
		local curtainsOpen = not (tipState == Trailer.TIPSTATE_CLOSED or tipState == Trailer.TIPSTATE_CLOSING)

		if spec.enableRearLoading and rearTrigger then
			if not doorOpen then
				-- print("NO LOADING IF DOOR CLOSED")
				return false
			end
		end
		
		if spec.enableSideLoading and not rearTrigger then
			if not curtainsOpen then
				-- print("NO LOADING IF CURTAIN CLOSED")
				return false
			end
		end
	end

	local node = UniversalAutoload.getObjectPositionNode( self )
	if node == nil then
		-- print("node == nil")
		return false
	end
	
	if node then
		-- check that the vehicle has not fallen on its side
		local _, y1, _ = getWorldTranslation(node)
		local _, y2, _ = localToWorld(node, 0, 1, 0)
		if y2 - y1 < 0.5 then
			-- print("NO LOADING IF FALLEN OVER")
			return false
		end
	end
	
	return true
end
--
function UniversalAutoload:getIsLoadingAreaAllowed(i)
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		if debugVehicles then print(self:getFullName() .. ": UAL DISABLED - getIsLoadingAreaAllowed") end
		return false
	end
	
	if spec.loadArea[i].noLoadingIfFolded and (self:ualGetIsFolding() or not self:getIsUnfolded()) then
		return false
	end
	if spec.loadArea[i].noLoadingIfUnfolded and (self:ualGetIsFolding() or self:getIsUnfolded()) then
		return false
	end
	if spec.loadArea[i].noLoadingIfCovered and self:ualGetIsCovered() then
		return false
	end
	if spec.loadArea[i].noLoadingIfUncovered and not self:ualGetIsCovered() then
		return false
	end
	return true
end
--
function UniversalAutoload:getIsUnloadingAreaAllowed(i)
	local spec = self.spec_universalAutoload
	
	return true
end
--
function UniversalAutoload:testLocationIsFull(loadPlace, offset)
	local spec = self.spec_universalAutoload
	local r = 0.05
	local sizeX, sizeY, sizeZ = (loadPlace.sizeX/2)-r, (loadPlace.sizeY/2)-r, (loadPlace.sizeZ/2)-r
	local x, y, z = localToWorld(loadPlace.node, 0, offset or 0, 0)
	local rx, ry, rz = getWorldRotation(loadPlace.node)
	local dx, dy, dz = localDirectionToWorld(loadPlace.node, 0, sizeY, 0)
		
	spec.foundObject = false
	spec.currentObject = self
	
	local collisionMask = UniversalAutoload.MASK.object
	local hitCount = overlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ, "ualTestLocationOverlap_Callback", self, collisionMask, true, false, true)
	
	-- if debugLoading then 
		-- print(self:getFullName())
		-- print(" HIT COUNT: " .. tostring(hitCount))
		-- DebugUtil.drawOverlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ)
	-- end
	
	return spec.foundObject
end
--
function UniversalAutoload:testLocationIsEmpty(loadPlace, object, offset)
	local spec = self.spec_universalAutoload
	local r = 0.05
	local sizeX, sizeY, sizeZ = (loadPlace.sizeX/2)-r, (loadPlace.sizeY/2)-r, (loadPlace.sizeZ/2)-r
	local x, y, z = localToWorld(loadPlace.node, 0, offset or 0, 0)
	local rx, ry, rz = getWorldRotation(loadPlace.node)
	local dx, dy, dz = localDirectionToWorld(loadPlace.node, 0, sizeY, 0)
	
	spec.foundObject = false
	spec.currentObject = object

	local collisionMask = UniversalAutoload.MASK.everything
	local hitCount = overlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ, "ualTestLocationOverlap_Callback", self, collisionMask, true, false, true)

	-- if debugLoading then 
		-- print(self:getFullName())
		-- print(" HIT COUNT: " .. tostring(hitCount))
		-- DebugUtil.drawOverlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ)
	-- end
	
	if UniversalAutoload.showDebug then
		if spec.testLocation == nil then
			spec.testLocation = {}
		end
		spec.testLocation.node = loadPlace.node
		spec.testLocation.sizeX = 2*sizeX
		spec.testLocation.sizeY = 2*sizeY
		spec.testLocation.sizeZ = 2*sizeZ
	end

	return not spec.foundObject
end
--
function UniversalAutoload:ualTestLocationOverlap_Callback(hitObjectId, x, y, z, distance)
	
	if hitObjectId ~= 0 and hitObjectId ~= self.rootNode and getHasClassId(hitObjectId, ClassIds.SHAPE) then
		local spec = self.spec_universalAutoload
		local object = UniversalAutoload.getNodeObject(hitObjectId)

		if object and object ~= self and object ~= spec.currentObject then
			print(object.i3dFilename)
			spec.foundObject = true
		end
	end
end
--
function UniversalAutoload:testLoadAreaIsEmpty()
	local spec = self.spec_universalAutoload
	local i = spec.currentLoadAreaIndex or 1
	
	local sizeX, sizeY, sizeZ = spec.loadArea[i].width/2, spec.loadArea[i].height/2, spec.loadArea[i].length/2
	local x, y, z = localToWorld(spec.loadArea[i].rootNode, 0, 0, 0)
	local rx, ry, rz = getWorldRotation(spec.loadArea[i].rootNode)
	local dx, dy, dz = localDirectionToWorld(spec.loadArea[i].rootNode, 0, sizeY, 0)
	
	spec.foundObject = false
	spec.currentObject = nil

	local collisionMask = UniversalAutoload.MASK.everything
	local hitCount = overlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ, "ualTestLocationOverlap_Callback", self, collisionMask, true, false, true)

	if debugLoading then 
		print(self:getFullName())
		print(" LOADED: " .. tostring(next(spec.loadedObjects) == nil))
		print(" IS EMPTY: " .. tostring(not spec.foundObject))
		print(" HIT COUNT: " .. tostring(hitCount))
		DebugUtil.drawOverlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ)
	end
	
	return not spec.foundObject
end
--
function UniversalAutoload:testUnloadLocationIsEmpty(unloadPlace)

	local spec = self.spec_universalAutoload
	local sizeX, sizeY, sizeZ = unloadPlace.sizeX/2, unloadPlace.sizeY/2, unloadPlace.sizeZ/2
	local x, y, z = localToWorld(unloadPlace.node, 0, 0, 0)
	local rx, ry, rz = getWorldRotation(unloadPlace.node)
	local dx, dy, dz
	if unloadPlace.wasFlippedYZ then
		dx, dy, dz = localDirectionToWorld(unloadPlace.node, 0, 0, -sizeY)
	else
		dx, dy, dz = localDirectionToWorld(unloadPlace.node, 0, sizeY, 0)
	end
	
	spec.hasOverlap = false

	local collisionMask = UniversalAutoload.MASK.everything
	local hitCount = overlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ, "ualTestUnloadLocation_Callback", self, collisionMask, true, true, true)	

	-- if debugLoading then 
		-- print(self:getFullName())
		-- print(" HIT COUNT: " .. tostring(hitCount))
		-- DebugUtil.drawOverlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ)
	-- end

	return not spec.hasOverlap
end
--
function UniversalAutoload:ualTestUnloadLocation_Callback(hitObjectId, x, y, z, distance)
	if hitObjectId ~= 0 and hitObjectId ~= self.rootNode then
		local spec = self.spec_universalAutoload
		local object = UniversalAutoload.getNodeObject(hitObjectId)
		if object and not spec.loadedObjects[object] then
			if object.spec_objectStorage and object.spec_objectStorage.objectTriggerNode 
			and hitObjectId == object.spec_objectStorage.objectTriggerNode then
				return true
			else
				DebugUtil.drawDebugNode(hitObjectId, getName(hitObjectId))
				spec.hasOverlap = true
				return false
			end
		end
	end
	return true
end
--
function UniversalAutoload:testLocation(loadPlace)
	local spec = self.spec_universalAutoload
	local i = spec.currentLoadAreaIndex or 1
	local r = 0.025
	
	local sizeX, sizeY, sizeZ
	local x, y, z
	local rx, ry, rz
	local dx, dy, dz
	if loadPlace == nil then
		sizeX, sizeY, sizeZ = spec.loadArea[i].width/2, spec.loadArea[i].height/2, spec.loadArea[i].length/2
		x, y, z = localToWorld(spec.loadArea[i].rootNode, 0, 0, 0)
		rx, ry, rz = getWorldRotation(spec.loadArea[i].rootNode)
		dx, dy, dz = localDirectionToWorld(spec.loadArea[i].rootNode, 0, sizeY, 0)
	else
		sizeX, sizeY, sizeZ = (loadPlace.sizeX/2)-r, (loadPlace.sizeY/2)-r, (loadPlace.sizeZ/2)-r
		x, y, z = localToWorld(loadPlace.node, 0, 0, 0)
		rx, ry, rz = getWorldRotation(loadPlace.node)
		dx, dy, dz = localDirectionToWorld(loadPlace.node, 0, sizeY, 0)
	end

	local FLAGS = {}
	for name, value in pairs(CollisionFlag) do
		if type(value) == 'number' then
			local flag = {}
			flag.name = name
			flag.value = value
			table.insert(FLAGS, flag)
		end
	end
	table.sort(FLAGS, function (a, b) return a.value < b.value end)
	
	print("TEST ALL COLLISIONS")
	spec.foundAnyObject = false
	for i, flag in ipairs(FLAGS) do
		spec.foundObject = false
		
		local collisionMask = flag.value
		local hitCount = overlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ, "ualTestLocation_Callback", self, collisionMask, true, false, true)
		
		print("  " .. flag.name .. " = " .. tostring(spec.foundObject):upper() .. " (" .. hitCount .. ")")
		
		if spec.foundObject then
			spec.foundAnyObject = true
		end
	end	

	if UniversalAutoload.showDebug then
		if spec.testLocation == nil then
			spec.testLocation = {}
		end
		spec.testLocation.node = loadPlace and loadPlace.node or spec.loadArea[i].rootNode
		spec.testLocation.sizeX = 2*sizeX
		spec.testLocation.sizeY = 2*sizeY
		spec.testLocation.sizeZ = 2*sizeZ
	end

	return spec.foundAnyObject
end
--
function UniversalAutoload:ualTestLocation_Callback(hitObjectId, x, y, z, distance)

	if hitObjectId ~= 0 and getHasClassId(hitObjectId, ClassIds.SHAPE) then
		local spec = self.spec_universalAutoload
		local object = UniversalAutoload.getNodeObject(hitObjectId)

		if object and object ~= self and UniversalAutoload.getIsValidObject(self, object) then
			if debugSpecial then
				if object.isSplitShape then
					print("  FOUND SPLIT SHAPE")
				else
					print("  FOUND: " .. object.i3dFilename)
				end
			end
			spec.foundObject = true
		end
	end
end
--

-- -- OBJECT MOVEMENT FUNCTIONS
function UniversalAutoload.getNodeObject( objectId )

	return g_currentMission:getNodeObject(objectId) or UniversalAutoload.getSplitShapeObject(objectId)
end
--
function UniversalAutoload.getSplitShapeObject( objectId )

	if not entityExists(objectId) then
		-- print("entity NOT exists")
		UniversalAutoload.SPLITSHAPES_LOOKUP[objectId] = nil
		return
	end
	
	--print("RigidBodyType: " .. tostring(getRigidBodyType(objectId)))
	if objectId ~= 0 and getRigidBodyType(objectId) == RigidBodyType.DYNAMIC then
	
		local splitType = g_splitShapeManager:getSplitTypeByIndex(getSplitType(objectId))
		if splitType then

			if UniversalAutoload.SPLITSHAPES_LOOKUP[objectId] == nil then
			
				local sizeX, sizeY, sizeZ, numConvexes, numAttachments = getSplitShapeStats(objectId)
				local xx,xy,xz = localDirectionToWorld(objectId, 1, 0, 0)
				local yx,yy,yz = localDirectionToWorld(objectId, 0, 1, 0)
				local zx,zy,zz = localDirectionToWorld(objectId, 0, 0, 1)
				
				if getChild(objectId, 'positionNode') == 0 then
					local x, y, z = getWorldTranslation(objectId)
					local xBelow, xAbove = getSplitShapePlaneExtents(objectId, x,y,z, xx,xy,xz)
					local yBelow, yAbove = getSplitShapePlaneExtents(objectId, x,y,z, yx,yy,yz)
					local zBelow, zAbove = getSplitShapePlaneExtents(objectId, x,y,z, zx,zy,zz)
					
					local positionNode = createTransformGroup("positionNode")
					link(objectId, positionNode)
					--setTranslation(positionNode, (xAbove-xBelow)/2, (yAbove-yBelow)/2, (zAbove-zBelow)/2)
					setTranslation(positionNode, (xAbove-xBelow)/2, -yBelow, (zAbove-zBelow)/2)
				end
				
				logObject = {}
				logObject.nodeId = objectId
				logObject.positionNodeId = getChild(objectId, 'positionNode')

				local x, y, z  = getWorldTranslation(logObject.positionNodeId)
				local xBelow, xAbove = getSplitShapePlaneExtents(objectId, x,y,z, xx,xy,xz)
				local yBelow, yAbove = getSplitShapePlaneExtents(objectId, x,y,z, yx,yy,yz)
				local zBelow, zAbove = getSplitShapePlaneExtents(objectId, x,y,z, zx,zy,zz)
				
				logObject.isSplitShape = true
				logObject.sizeX = xBelow + xAbove
				logObject.sizeY = yBelow + yAbove
				logObject.sizeZ = zBelow + zAbove
				logObject.fillType = FillType.WOOD
				
				UniversalAutoload.SPLITSHAPES_LOOKUP[objectId] = logObject
				
				local rx, ry, rz = getWorldRotation(logObject.nodeId)
				print(string.format("nodeId R  = %f, %f, %f", rx, ry, rz))
				local prx, pry, prz = getWorldRotation(logObject.positionNodeId)
				print(string.format("position R = %f, %f, %f", prx, pry, prz))
			end
			
			return UniversalAutoload.SPLITSHAPES_LOOKUP[objectId]

		end
	end
end
--
--
function UniversalAutoload.getObjectPositionNode( object )
	local node = UniversalAutoload.getObjectRootNode(object)
	if node == nil then
		if debugPallets then print("Object Root Node IS NIL - " .. object.i3dFilename) end
		return nil
	end
	if object.isSplitShape and object.positionNodeId then
		return object.positionNodeId
	else
		return node
	end
end
--
function UniversalAutoload.getObjectRootNode( object )
	local node = nil

	if object.components then
		node = object.components[1].node
	else
		node = object.nodeId
	end
	
	if node == nil or node == 0 or not entityExists(node) then
		return nil
	else
		return node
	end
end
--
function UniversalAutoload.unlinkObject( object )
	local node = UniversalAutoload.getObjectRootNode(object)
	if node then
		local x, y, z = localToWorld(node, 0, 0, 0)
		local rx, ry, rz = getWorldRotation(node, 0, 0, 0)
		link(getRootNode(), node)
		setWorldTranslation(node, x, y, z)
		setWorldRotation(node, rx, ry, rz)
	end
end
--
function UniversalAutoload.moveObjectNode( node, p )
	if node then
		if p.x then
			setWorldTranslation(node, p.x, p.y, p.z)
		end
		if p.rx then
			setWorldRotation(node, p.rx, p.ry, p.rz)
		end
	end
end
--
function UniversalAutoload.getPositionNodes( object )
	local nodes = {}
	if object.isSplitShape and object.positionNodeId then
		table.insert(nodes, object.positionNodeId)
	else
		nodes = UniversalAutoload.getRootNodes( object )
	end
	return nodes
end
--
function UniversalAutoload.getRootNodes( object )
	local nodes = {}
	
	if object.components then
		for i = 1, #object.components do
			table.insert(nodes, object.components[i].node)
		end
	else
		table.insert(nodes, object.nodeId)
	end
	return nodes
end
--
function UniversalAutoload.getTransformation( position, nodes )
	local n = {}
	for i = 1, #nodes do
		n[i] = {}
		n[i].x, n[i].y, n[i].z = localToWorld(position.node, 0, position.baleOffset or 0, 0)
		n[i].rx, n[i].ry, n[i].rz = getWorldRotation(position.node)
		if position.flipYZ then
			n[i].rx = n[i].rx + math.pi/2
		end
		if i > 1 then
			local dx, dy, dz = localToLocal(nodes[i], nodes[1], 0, 0, 0)
			n[i].x = n[i].x + dx
			n[i].y = n[i].y + dy
			n[i].z = n[i].z + dz
		end
		n[i].x = n[i].x
		n[i].y = n[i].y
		n[i].z = n[i].z
	end
	return n
end
--
function UniversalAutoload.removeFromPhysics(object)

	if object.isRoundbale ~= nil or object.isSplitShape then
		local node = UniversalAutoload.getObjectRootNode(object)
		if node then
			removeFromPhysics(node)
		end
	elseif object.isAddedToPhysics then
		object:removeFromPhysics()
	end
end
--
function UniversalAutoload:addToPhysics(object)

	if disablePhysicsAfterLoading then
		print("addToPhysics is DISABLED")
		return
	end
	
	if object.isRoundbale ~= nil or object.isSplitShape then
		local node = UniversalAutoload.getObjectRootNode(object)
		if node then
			addToPhysics(node)
		end
	else
		object:addToPhysics()
	end
	
	local nodes = UniversalAutoload.getRootNodes(object)
	local rootNode = self:getParentComponent(self.rootNode)
	local vx, vy, vz = getLinearVelocity(rootNode)
	for i = 1, #nodes do
		setLinearVelocity(nodes[i], vx or 0, vy or 0, vz or 0)
	end
	if object.raiseActive ~= nil then
		object:raiseActive()
		object.networkTimeInterpolator:reset()
		UniversalAutoload.raiseObjectDirtyFlags(object)
	end
end
--
function UniversalAutoload:addBaleModeBale(node)
	local rootNode = self.spec_universalAutoload.loadVolume.rootNode
	local x, y, z = localToLocal(node, rootNode, 0, 0, 0)
	local rx, ry, rz = localRotationToLocal(node, rootNode, 0, 0, 0)
	
	link(rootNode, node)
	setTranslation(node, x, y, z)
	setRotation(node, rx, ry, rz)
end
--
function UniversalAutoload:moveObjectNodes( object, position, isLoading, rotateLogs )

	local spec = self.spec_universalAutoload
	local rootNodes = UniversalAutoload.getRootNodes(object)
	local node = rootNodes[1]
	if node and node ~= 0 and entityExists(node) then
	
		UniversalAutoload.unmountDynamicMount(object)
		UniversalAutoload.removeFromPhysics(object)

		local n = UniversalAutoload.getTransformation( position, rootNodes )

		-- SPLITSHAPE ROTATION
		if object.isSplitShape then
		
			-- IF OBJECT IS NOT ALREADY LOADED
			if isLoading then
			
				-- if rotateLogs then print("ROTATE") else print("NORMAL") end
				print(string.format("R0  %f, %f, %f", n[1].rx, n[1].ry, n[1].rz))
			
				-- local s = rotateLogs and 1 or -1
				local xx,xy,xz = localDirectionToWorld(position.node, 0, 0, 0) --length
				local yx,yy,yz = localDirectionToWorld(position.node, 0, 1, 0) --height
				local zx,zy,zz = localDirectionToWorld(position.node, 0, 0, 0) --width
				-- print(string.format("X %f, %f, %f",xx,xy,xz))
				-- print(string.format("Y %f, %f, %f",yx,yy,yz))
				-- print(string.format("Z %f, %f, %f",zx,zy,zz))
			
				--local rx, ry, rz = localRotationToWorld(position.node, 0, 0, s*math.pi/2)
				if n[1].ry > -math.pi/4 and n[1].ry < math.pi/4 then
					n[1].ry = n[1].ry + math.pi/2
				end
		
				n[1].rx = n[1].rx + math.pi/2
				n[1].ry = n[1].ry + math.pi
				n[1].rz = n[1].rz
				print(string.format("R1  %f, %f, %f", n[1].rx, n[1].ry, n[1].rz))
				

				local X = object.sizeY/2
				local Y = object.sizeX/2
				local Z = object.sizeZ/2
				print(string.format("D %f, %f, %f", X, Y, Z))
				
				n[1].x = n[1].x + xx*X + yx*Y + zx*Z
				n[1].y = n[1].y + xy*X + yy*Y + zy*Z
				n[1].z = n[1].z + xz*X + yz*Y + zz*Z
			end

		end
		
		-- ROUND BALE ROTATION
		if object.isRoundbale and spec.useHorizontalLoading then
			local rotation = isLoading and math.pi/4 or 0
			local rx,ry,rz = localRotationToWorld(position.node, 0, 0, rotation)
			n[1].rx = rx
			n[1].ry = ry
			n[1].rz = rz
		end
		
		for i = 1, #rootNodes do
			UniversalAutoload.moveObjectNode(rootNodes[i], n[i])
		end
		
		-- SPLITSHAPE TRANSLATION
		if object.isSplitShape then

			local x0, y0, z0 = getWorldTranslation(node)
			local x1, y1, z1 = getWorldTranslation(object.positionNodeId)
			
			local offset = {}
			offset['x'] = x0 - (x1-x0)
			offset['y'] = y0 - (y1-y0)
			offset['z'] = z0 - (z1-z0)

			print(string.format("offset (%f, %f, %f)", offset.x, offset.y, offset.z))
			UniversalAutoload.moveObjectNode(node, offset)

		end

		if spec.baleCollectionMode==true and object.isRoundbale~=nil then
			UniversalAutoload.addBaleModeBale(self, node)
		else
			UniversalAutoload.addToPhysics(self, object)
		end
		
		return true
	end
end

-- TRIGGER CALLBACK FUNCTIONS
function UniversalAutoload:ualPlayerTrigger_Callback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	if self and otherActorId ~= 0 and otherActorId ~= self.rootNode then
		for _, player in pairs(g_currentMission.players) do
			if otherActorId == player.rootNode then
				
				if g_currentMission.accessHandler:canFarmAccess(player.farmId, self) then
				
					local spec = self.spec_universalAutoload
					local playerId = player.userId
					
					if onEnter then
						UniversalAutoload.updatePlayerTriggerState(self, playerId, true)
						UniversalAutoload.forceRaiseActive(self, true)
					else
						UniversalAutoload.updatePlayerTriggerState(self, playerId, false)
						UniversalAutoload.forceRaiseActive(self, true)
					end

				end
	
			end
		end
	end
end

function UniversalAutoload:ualLoadingTrigger_Callback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	if self and otherActorId ~= 0 and otherActorId ~= self.rootNode then
		local spec = self.spec_universalAutoload
		local object = UniversalAutoload.getNodeObject(otherActorId)
		if object then
			if UniversalAutoload.getIsValidObject(self, object) then
				if onEnter then
					UniversalAutoload.addAvailableObject(self, object)
				elseif onLeave then
					UniversalAutoload.removeAvailableObject(self, object)
				end
			end
		end
	end
end
--
function UniversalAutoload:ualUnloadingTrigger_Callback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	if self and otherActorId ~= 0 and otherActorId ~= self.rootNode then
		local spec = self.spec_universalAutoload
		local object = UniversalAutoload.getNodeObject(otherActorId)
		if object then
			if UniversalAutoload.getIsValidObject(self, object) then
				if onEnter then
					-- if debugLoading then print(" UnloadingTrigger ENTER: " .. tostring(object.id)) end
					UniversalAutoload.addLoadedObject(self, object)
				elseif onLeave then
					-- if debugLoading then print(" UnloadingTrigger LEAVE: " .. tostring(object.id)) end
					UniversalAutoload.removeLoadedObject(self, object)
				end
			end
		end
	end
end
--
function UniversalAutoload:ualAutoLoadingTrigger_Callback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	if self and otherActorId ~= 0 and otherActorId ~= self.rootNode then
		local spec = self.spec_universalAutoload
		local object = UniversalAutoload.getNodeObject(otherActorId)
		if object then
			if UniversalAutoload.getIsValidObject(self, object) then
				if onEnter then
					if debugLoading then print(" AutoLoadingTrigger ENTER: " .. tostring(object.id)) end
					UniversalAutoload.addAutoLoadingObject(self, object)
				elseif onLeave then
					if debugLoading then print(" AutoLoadingTrigger LEAVE: " .. tostring(object.id)) end
					UniversalAutoload.removeAutoLoadingObject(self, object)
				end
			end
		end
	end
end

function UniversalAutoload:addLoadedObject(object)
	local spec = self.spec_universalAutoload
	
	if spec.loadedObjects[object] == nil and (not UniversalAutoload.isValidForManualLoading(object)
	or (object.isSplitShape and spec.autoLoadingObjects[object] == nil)) then
		spec.loadedObjects[object] = object
		spec.objectToLoadingAreaIndex[object] = spec.currentLoadAreaIndex or 1
		spec.totalUnloadCount = spec.totalUnloadCount + 1
		if object.addDeleteListener then
			object:addDeleteListener(self, "ualOnDeleteLoadedObject_Callback")
		end
		if debugLoading then
			print("["..self.rootNode.."] ADD Loaded Object: " .. tostring(object.id))
		end
		return true
	end
end
--
function UniversalAutoload:removeLoadedObject(object)
	local spec = self.spec_universalAutoload
	if spec.loadedObjects[object] then
		spec.loadedObjects[object] = nil
		spec.objectToLoadingAreaIndex[object] = nil
		spec.totalUnloadCount = spec.totalUnloadCount - 1
		if object.removeDeleteListener then
			object:removeDeleteListener(self, "ualOnDeleteLoadedObject_Callback")
		end
		if next(spec.loadedObjects) == nil then
			if debugLoading then print("FULLY UNLOADED..") end
			UniversalAutoload.resetLoadingArea(self)
		else
			if debugLoading then print("PARTIALLY UNLOADED..") end
			spec.partiallyUnloaded = true
		end
		if debugLoading then
			print("["..self.rootNode.."] REMOVE Loaded Object: " .. tostring(object.id))
		end
		return true
	end
end

function UniversalAutoload:ualOnDeleteLoadedObject_Callback(object)
	UniversalAutoload.removeLoadedObject(self, object)
end
--
function UniversalAutoload:addAvailableObject(object)
	local spec = self.spec_universalAutoload
	
	if spec.availableObjects[object] == nil and spec.loadedObjects[object] == nil then
		spec.availableObjects[object] = object
		spec.totalAvailableCount = spec.totalAvailableCount + 1
		if object.isRoundbale ~= nil then
			spec.availableBaleCount = spec.availableBaleCount + 1
		end
		if object.addDeleteListener then
			object:addDeleteListener(self, "ualOnDeleteAvailableObject_Callback")
		end
		
		if spec.isLoading and UniversalAutoload.isValidForLoading(self, object) then
			table.insert(spec.sortedObjectsToLoad, object)
		end
		
		return true
	end
end
--
function UniversalAutoload:removeAvailableObject(object)
	local spec = self.spec_universalAutoload
	local isActiveForLoading = spec.isLoading or spec.isUnloading or spec.doPostLoadDelay
	
	if spec.availableObjects[object] then
		spec.availableObjects[object] = nil
		spec.totalAvailableCount = spec.totalAvailableCount - 1
		if object.isRoundbale ~= nil then
			spec.availableBaleCount = spec.availableBaleCount - 1
		end
		if object.removeDeleteListener then
			object:removeDeleteListener(self, "ualOnDeleteAvailableObject_Callback")
		end
		
		if spec.totalAvailableCount == 0 and not isActiveForLoading then
			-- print("["..self.rootNode.."] RESETTING MATERIAL AND CONTAINER SELECTIONS")
			if spec.currentMaterialIndex ~= 1 then
				UniversalAutoload.setMaterialTypeIndex(self, 1)
			end
			if spec.currentContainerIndex ~= 1 then
				UniversalAutoload.setContainerTypeIndex(self, 1)
			end
		end
		return true
	end
end
--
function UniversalAutoload:removeFromSortedObjectsToLoad(object)
	local spec = self.spec_universalAutoload
	
	if spec.sortedObjectsToLoad then
		for index, sortedobject in ipairs(spec.sortedObjectsToLoad or {}) do
			if object == sortedobject then
				table.remove(spec.sortedObjectsToLoad, index)
				return true
			end
		end
	end
end
--
function UniversalAutoload:ualOnDeleteAvailableObject_Callback(object)
	UniversalAutoload.removeAvailableObject(self, object)
	UniversalAutoload.removeFromSortedObjectsToLoad(self, object)
end
--
function UniversalAutoload:addAutoLoadingObject(object)
	local spec = self.spec_universalAutoload

	if UniversalAutoload.isValidForManualLoading(object) or (object.isSplitShape and self.isLogTrailer) then
		if spec.autoLoadingObjects[object] == nil and spec.loadedObjects[object] == nil then
			spec.autoLoadingObjects[object] = object
			if object.addDeleteListener then
				object:addDeleteListener(self, "ualOnDeleteAutoLoadingObject_Callback")
			end
			local pickedUpObject = UniversalAutoload.getObjectRootNode(object)
			-- HandToolHands.getIsHoldingItem() ??
			-- if pickedUpObject and Player.PICKED_UP_OBJECTS[pickedUpObject] == true then
				-- for _, player in pairs(g_currentMission.players) do
					-- if player.isCarryingObject and player.pickedUpObject == pickedUpObject then
						-- player:pickUpObject(false)
						-- if debugSpecial then print("*** DROP OBJECT ***") end
					-- end
				-- end
			-- end
			return true
		end
	end
end
--
function UniversalAutoload:removeAutoLoadingObject(object)
	local spec = self.spec_universalAutoload
	
	if spec.autoLoadingObjects[object] then
		spec.autoLoadingObjects[object] = nil
		if object.removeDeleteListener then
			object:removeDeleteListener(self, "ualOnDeleteAutoLoadingObject_Callback")
		end
		return true
	end
end
--
function UniversalAutoload:ualOnDeleteAutoLoadingObject_Callback(object)
	UniversalAutoload.removeAutoLoadingObject(self, object)
end
--
function UniversalAutoload:removeSplitShapeObject(object)
	UniversalAutoload.removeLoadedObject(self, object)
	UniversalAutoload.removeAvailableObject(self, object)
	UniversalAutoload.removeFromSortedObjectsToLoad(self, object)
	UniversalAutoload.removeAutoLoadingObject(self, object)
	UniversalAutoload.SPLITSHAPES_LOOKUP[object.nodeId] = nil
end
--
function UniversalAutoload:createPallet(xmlFilename)
	local spec = self.spec_universalAutoload
	spec.spawningPallet = xmlFilename

	local x, y, z = getWorldTranslation(spec.loadVolume.rootNode)
	local location = { x=x, y=y+10, z=z }

	local function asyncCallbackFunction(vehicle, pallet, palletLoadState, arguments)
		if palletLoadState == VehicleLoadingState.OK then
			local SPEC = vehicle.spec_universalAutoload
			local fillTypeIndex = pallet:getFillUnitFirstSupportedFillType(1)
			pallet:addFillUnitFillLevel(1, 1, math.huge, fillTypeIndex, ToolType.UNDEFINED, nil)

			if UniversalAutoload.loadObject(vehicle, pallet) then
				SPEC.spawnPalletsDelayTime = 0
			else
				SPEC.spawnPalletsDelayTime = UniversalAutoload.DELAY_TIME
				g_currentMission:removeVehicle(pallet, true)
				
				if SPEC.palletsToSpawn and #SPEC.palletsToSpawn>1 then
					for i, name in pairs(SPEC.palletsToSpawn) do
						if SPEC.spawningPallet == name then
							if debugConsole then print("removing: " .. SPEC.spawningPallet) end
							table.remove(SPEC.palletsToSpawn, i)
							SPEC.trailerIsFull = false
							break
						end
					end
				end
				if SPEC.palletsToSpawn and #SPEC.palletsToSpawn==1 then
					SPEC.palletsToSpawn = nil
				end
			end
			
			SPEC.spawningPallet = nil
			if SPEC.trailerIsFull == true or not SPEC.palletsToSpawn then
				SPEC.spawnPallets = false
				SPEC.doPostLoadDelay = true
				SPEC.doSetTensionBelts = true
				SPEC.lastSpawnedPallet = nil
				SPEC.palletsToSpawn = {}
				print(vehicle:getFullName() .. " ..adding pallets complete!")
			end
			return
		end
	end

	local farmId = g_currentMission:getFarmId()
	farmId = farmId ~= FarmManager.SPECTATOR_FARM_ID and farmId or 1
	VehicleLoadingData.loadVehicle(xmlFilename, location, true, 0, VehiclePropertyState.OWNED, farmId, nil, nil, asyncCallbackFunction, self)
end
--
function UniversalAutoload:createPallets(pallets)
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable then
		if spec.isLogTrailer then
			print("Log trailer - cannot load bales")
			return false
		end
		if debugConsole then print("ADD PALLETS: " .. self:getFullName()) end
		UniversalAutoload.setMaterialTypeIndex(self, 1)
		UniversalAutoload.setBaleCollectionMode(self, false)
		if palletsOnly then
			UniversalAutoload.setContainerTypeIndex(self, 2)
		else
			UniversalAutoload.setContainerTypeIndex(self, 1)
		end
		UniversalAutoload.clearLoadedObjects(self)
		self:setAllTensionBeltsActive(false)
		spec.spawnPallets = true
		spec.palletsToSpawn = {}

		for _, pallet in pairs(pallets) do
			table.insert(spec.palletsToSpawn, pallet)
		end
		return true
	end
end
--
function UniversalAutoload:createLog(treeType, length)
	local spec = self.spec_universalAutoload
	
	if UniversalAutoload.spawningLog then
		return nil
	end
	
	UniversalAutoload.spawningLog = true

	local x, y, z = getWorldTranslation(spec.loadVolume.rootNode)
	dirX, dirY, dirZ = localDirectionToWorld(spec.loadVolume.rootNode, 0, 0, 1)
	y = y + 50
	
	if treeType == 'SPRUCE' then
		if math.random(1, 100) > 50 then treeType = 'SPRUCE1' else treeType = 'SPRUCE2' end
	end
	if treeType == 'WILLOW' then
		if math.random(1, 100) > 50 then treeType = 'WILLOW1' else treeType = 'WILLOW2' end
	end

	local treeTypeDesc = g_treePlantManager:getTreeTypeDescFromName(treeType)
	local growthState = #treeTypeDesc.treeFilenames
	local treeId, splitShapeFileId = g_treePlantManager:loadTreeNode(treeTypeDesc, x, y, z, 0, 0, 0, growthState)

	if treeId ~= 0 then
		if getFileIdHasSplitShapes(splitShapeFileId) then
			local tree = {
				node = treeId,
				growthState = growthState,
				z = z,
				y = y,
				x = x,
				rz = 0,
				ry = 0,
				rx = 0,
				treeType = treeTypeDesc.index,
				splitShapeFileId = splitShapeFileId,
				hasSplitShapes = true
			}

			table.insert(g_treePlantManager.treesData.splitTrees, tree)

			g_treePlantManager.loadTreeTrunkData = {
				offset = 0.5,
				framesLeft = 2,
				shape = treeId + 2,
				x = x,
				y = y,
				z = z,
				length = length,
				dirX = dirX,
				dirY = dirY,
				dirZ = dirZ,
				delimb = true
			}
		else
			delete(treeId)
		end
	end
	
	return treeId
end
--
function UniversalAutoload:createLogs(treeType, length)
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable then
		if debugConsole then print("ADD LOGS: " .. self:getFullName()) end
		UniversalAutoload.setMaterialTypeIndex(self, 1)
		UniversalAutoload.setBaleCollectionMode(self, false)
		UniversalAutoload.setContainerTypeIndex(self, 1)
		UniversalAutoload.clearLoadedObjects(self)		
		self:setAllTensionBeltsActive(false)
		spec.spawnLogs = true
		spec.logToSpawn = {}
		spec.logToSpawn.treeType = treeType
		spec.logToSpawn.length = length
		return true
	end
end
--
function UniversalAutoload:createBale(xmlFilename, fillTypeIndex, wrapState)
	local spec = self.spec_universalAutoload

	local x, y, z = getWorldTranslation(spec.loadVolume.rootNode)
	y = y + 10

	local farmId = g_currentMission:getFarmId()
	farmId = farmId ~= FarmManager.SPECTATOR_FARM_ID and farmId or 1
	local baleObject = Bale.new(g_currentMission:getIsServer(), g_currentMission:getIsClient())
	
	if baleObject:loadFromConfigXML(xmlFilename, x, y, z, 0, 0, 0) then
		baleObject:setFillType(fillTypeIndex, true)
		baleObject:setWrappingState(wrapState)
		baleObject:setOwnerFarmId(farmId, true)
		baleObject:register()
	end
	
	return baleObject
end
--
function UniversalAutoload:createBales(bale)
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable then
		if spec.isLogTrailer then
			print("Log trailer - cannot load bales")
			return false
		end
		if debugConsole then print("ADD BALES: " .. self:getFullName()) end
		UniversalAutoload.clearLoadedObjects(self)
		UniversalAutoload.setMaterialTypeIndex(self, 1)
		UniversalAutoload.setContainerTypeIndex(self, 1)
		self:setAllTensionBeltsActive(false)
		spec.spawnBales = true
		spec.baleToSpawn = bale
		return true
	end
end
--
function UniversalAutoload:clearLoadedObjects()
	local spec = self.spec_universalAutoload
	local palletCount, balesCount, logCount = 0, 0, 0
	
	if spec and spec.isAutoloadAvailable and spec.loadedObjects then
		if debugLoading or debugConsole then print("CLEAR OBJECTS: " .. self:getFullName()) end
		self:setAllTensionBeltsActive(false)
		for _, object in pairs(spec.loadedObjects or {}) do
			if object.isSplitShape then
				UniversalAutoload.removeSplitShapeObject(self, object)
				g_currentMission:removeKnownSplitShape(object.nodeId)
				if entityExists(object.nodeId) then
					delete(object.nodeId)
				end
				logCount = logCount + 1
			elseif object.isRoundbale == nil then
				g_currentMission:removeVehicle(object, true)
				palletCount = palletCount + 1
			else
				object:delete()
				balesCount = balesCount + 1
			end
		end
		spec.loadedObjects = {}
		spec.totalUnloadCount = 0
		UniversalAutoload.resetLoadingArea(self)
	end
	return palletCount, balesCount, logCount
end
--

-- PALLET IDENTIFICATION AND SELECTION FUNCTIONS
function UniversalAutoload.getObjectNameFromI3d(i3d_path)

	if i3d_path == nil then
		return
	end
	
	local i3d_name = i3d_path:match("[^/]*.i3d$")
	return i3d_name:sub(0, #i3d_name - 4)
end
--
function UniversalAutoload.getObjectNameFromXml(xml_path)

	if xml_path == nil then
		return
	end
	
	local xml_name = xml_path:match("[^/]*.xml$")
	return xml_name:sub(0, #xml_name - 4)
end
--
function UniversalAutoload.getEnvironmentNameFromPath(i3d_path)

	if i3d_path == nil then
		return
	end
	
	local customEnvironment = nil
	if i3d_path:find(g_modsDirectory) then
		local temp = i3d_path:gsub(g_modsDirectory, "")
		customEnvironment, _ = temp:match( "^(.-)/(.+)$" )
	else
		for i = 1, #g_dlcsDirectories do
			local dlcsDirectory = g_dlcsDirectories[i].path
			if dlcsDirectory:find(":") and i3d_path:find(dlcsDirectory) then
				local temp = i3d_path:gsub(dlcsDirectory, "")
				customEnvironment, _ = "pdlc_"..temp:match( "^(.-)/(.+)$" )
			end
		end
	end
	return customEnvironment
end
--
function UniversalAutoload.getContainerTypeName(object)
	local containerType = UniversalAutoload.getContainerType(object)
	return containerType.type
end
--
function UniversalAutoload.getContainerType(object)

	if object == nil then
		print("getContainerType requires an object")
		return nil
	end

	if object.isSplitShape then 
		
		if object.ualConfiguration == nil then
			print("*** UNIVERSAL AUTOLOAD - FOUND NEW SPLITSHAPE ***")	
			DebugUtil.printTableRecursively(object, "--", 0, 1)
			
			print("POS:", localToWorld(object.nodeId, 0, 0, 0))
			print("ROT:", getWorldRotation(object.nodeId, 0, 0, 0))
			
			local boundingBox = BoundingBox.new(object)
			--print("SPLITSHAPE boundingBox:")
			local size = boundingBox:getSize()
			local offset = boundingBox:getOffset()
			local rootNode = boundingBox:getRootNode()
			--DebugUtil.printTableRecursively(size or {}, "  ", 0, 1)
			--DebugUtil.printTableRecursively(offset or {}, "  ", 0, 1)
			--DebugUtil.printTableRecursively(object or {}, "  ", 0, 1)

			local splitShape = {}
			for k, v in pairs(object) do
				splitShape[k] = v
			end
			
			splitShape.type = "LOGS"
			splitShape.name = "splitShape"
			splitShape.containerIndex = UniversalAutoload.CONTAINERS_LOOKUP["LOGS"] or 1
			-- splitShape.sizeX = size.x
			-- splitShape.sizeY = size.y
			-- splitShape.sizeZ = size.z
			-- splitShape.offset = offset
			splitShape.offset = {x=0, y=0, z=0}
			splitShape.isBale = false
			splitShape.isRoundbale = false
			splitShape.flipYZ = false
			splitShape.neverStack = false
			splitShape.neverRotate = false
			splitShape.alwaysRotate = false
			splitShape.frontOffset = 0
			splitShape.width = math.min(splitShape.sizeX, splitShape.sizeZ)
			splitShape.length = math.max(splitShape.sizeX, splitShape.sizeZ)

			object.ualConfiguration = splitShape
		end
		
		return object.ualConfiguration
	end

	local name = object.i3dFilename or object.configFileName or object.xmlFilename
	if name == nil then
		print("UAL getContainerType - could not identify object")
		return nil
	end

	local objectType = UniversalAutoload.LOADING_TYPES[name]
	if objectType == nil and not UniversalAutoload.INVALID_OBJECTS[name] then
		
		local isBale = object.isRoundbale ~= nil
		local isRoundbale = object.isRoundbale == true
		local isPallet = object.specializationsByName
					 and object.specializationsByName.pallet
					 and object.specializationsByName.fillUnit
					 and object.specializationsByName.tensionBeltObject
		
		print("*** UNIVERSAL AUTOLOAD - FOUND NEW OBJECT TYPE: ".. name.." ***")
		if isPallet or isBale then
			if isPallet then
				print("Pallet")
				-- DebugUtil.printTableRecursively(object.size or {}, "  ", 0, 1)
				print("  width: " .. object.size.width)
				print("  height: " .. object.size.height)
				print("  length: " .. object.size.length)
			elseif isBale then
				if isRoundbale then
					print("Round Bale")
					print("  width: " .. object.width)
					print("  height: " .. object.diameter)
					print("  length: " .. object.diameter)
				else
					print("Square Bale")
					print("  width: " .. object.width)
					print("  height: " .. object.height)
					print("  length: " .. object.length)
				end
			end
			
			local boundingBox = BoundingBox.new(object)
			local size = boundingBox:getSize()
			local offset = boundingBox:getOffset()
			local rootNode = boundingBox:getRootNode()
			print("rootNode: " .. rootNode)
			print("  size X: " .. size.x)
			print("  size Y: " .. size.y)
			print("  size Z: " .. size.z)
			print("  offset X: " .. offset.x)
			print("  offset Y: " .. offset.y)
			print("  offset Z: " .. offset.z)
			-- DebugUtil.printTableRecursively(object or {}, "  ", 0, 1)
			
			local storeItem = object.loadCallbackFunctionTarget and object.loadCallbackFunctionTarget.storeItem
			local category = (storeItem and storeItem.categoryName) or "unknown"
			-- DebugUtil.printTableRecursively(storeItem or {}, "  ", 0, 1)
	
			local nameUpper = tostring(name):upper()
			local containerType = UniversalAutoload.ALL
			
			if isBale or category == "BALES" then containerType = "BALE"
			elseif category == "IBC" then containerType = "LIQUID_TANK"
			elseif category == "BIGBAGS" then containerType = "BIGBAG"
			elseif category == "PALLETS" then containerType = "EURO_PALLET"
			elseif category == "BIGBAGPALLETS" then containerType = "BIGBAG_PALLET"
			elseif string.find(nameUpper, "IBC") then containerType = "LIQUID_TANK"
			elseif string.find(nameUpper, "LIQUIDTANK") then containerType = "LIQUID_TANK" 
			elseif string.find(nameUpper, "BIGBAG") then containerType = "BIGBAG"
			elseif string.find(nameUpper, "PALLET") then containerType = "EURO_PALLET"
			end

			local containerIndex = UniversalAutoload.CONTAINERS_LOOKUP[containerType] or 1

			newType = {}
			newType.name = name
			newType.type = containerType
			newType.containerIndex = containerIndex
			newType.sizeX = size.x + UniversalAutoload.SPACING
			newType.sizeY = size.y + UniversalAutoload.SPACING
			newType.sizeZ = size.z + UniversalAutoload.SPACING
			newType.offset = offset
			newType.isBale = isBale
			newType.isRoundbale = isRoundbale
			newType.flipYZ = false
			newType.neverStack = (containerType == "BIGBAG") or false
			newType.neverRotate = false
			newType.alwaysRotate = false
			newType.frontOffset = 0
			
			if isRoundbale == true then
				print("Round Bale flipYZ")
				newType.flipYZ = true
				newType.sizeY = size.z + UniversalAutoload.SPACING
				newType.sizeZ = size.y + UniversalAutoload.SPACING
			end
			
			if isPallet then
				newType.offset.y = -((size.y/2) - offset.y)
			end
			
			newType.width = math.min(newType.sizeX, newType.sizeZ)
			newType.length = math.max(newType.sizeX, newType.sizeZ)
				
			print(string.format("  >> %s [%.3f, %.3f, %.3f] - %s", newType.name,
				newType.sizeX, newType.sizeY, newType.sizeZ, containerType ))
			
			UniversalAutoload.LOADING_TYPES[name] = newType
			objectType = UniversalAutoload.LOADING_TYPES[name]
			
		else
			
			print(" OBJECT NOT VALID")
			UniversalAutoload.INVALID_OBJECTS[name] = true
		end
		-- DebugUtil.printTableRecursively(object or {}, "--", 0, 1)
	end
	
	return objectType
end
--
function UniversalAutoload.getContainerDimensions(object)
	local containerType = UniversalAutoload.getContainerType(object)
	UniversalAutoload.getContainerTypeDimensions(containerType)
end
--
function UniversalAutoload.getContainerTypeDimensions(containerType)
	if containerType then
		local w, h, l = containerType.sizeX, containerType.sizeY, containerType.sizeZ

		if containerType.flipXY then
			w, h = containerType.sizeY, containerType.sizeX
		end
		if containerType.flipYZ then
			l, h = containerType.sizeY, containerType.sizeZ
		end
		return w, h, l
	end
end
--
function UniversalAutoload.getContainerMass(object)
	local mass = 1
	if object then
		if object.getTotalMass == nil then
			if object.getMass then
				-- print("GET BALE MASS")
				mass = object:getMass()
			else
				-- print("GET SPLITSHAPE MASS")
				if entityExists(object.nodeId) then
					mass = getMass(object.nodeId)
				end
			end
		else
			-- print("GET OBJECT MASS")
			mass = object:getTotalMass()
		end
	end
	return mass
end
--
function UniversalAutoload.getMaterialType(object)
	if object then
		if object.fillType then
			return object.fillType
		elseif object.spec_fillUnit and next(object.spec_fillUnit.fillUnits) then
			return object.spec_fillUnit.fillUnits[1].fillType
		-- elseif object.spec_umbilicalReelOverload then
			-- return g_fillTypeManager:getFillTypeIndexByName("UMBILICAL_HOSE")
		end
	end
end
--
function UniversalAutoload.getMaterialTypeName(object)
	local fillUnitIndex = UniversalAutoload.getMaterialType(object)
	local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillUnitIndex)
	if fillTypeName == nil or fillTypeName == "UNKNOWN" then
		fillTypeName = UniversalAutoload.ALL
	end
	return fillTypeName
end
--
function UniversalAutoload:getSelectedContainerType()
	local spec = self.spec_universalAutoload
	return UniversalAutoload.CONTAINERS[spec.currentContainerIndex]
end
--
function UniversalAutoload:getSelectedContainerText()
	local selectedContainerType = UniversalAutoload.getSelectedContainerType(self)
	
	return g_i18n:getText("universalAutoload_"..selectedContainerType)
end
--
function UniversalAutoload:getSelectedMaterialType()
	local spec = self.spec_universalAutoload
	return UniversalAutoload.MATERIALS[spec.currentMaterialIndex] or 1
end
--
function UniversalAutoload:getSelectedMaterialText()
	local materialType = UniversalAutoload.getSelectedMaterialType(self)
	local materialIndex = UniversalAutoload.MATERIALS_INDEX[materialType]
	local fillType = UniversalAutoload.MATERIALS_FILLTYPE[materialIndex]
	return fillType.title
end
--
function UniversalAutoload:getPalletIsSelectedLoadside(object)
	local spec = self.spec_universalAutoload
	
	if spec.currentLoadside == "both" then
		return true
	end
	
	if spec.rearUnloadingOnly and spec.currentLoadside == "rear" then
		return true
	end
	
	if spec.frontUnloadingOnly and spec.currentLoadside == "front" then
		return true
	end
	
	if spec.availableObjects[object] == nil then
		return true
	end

	local node = UniversalAutoload.getObjectPositionNode(object)
	if node == nil then
		return false
	end
	
	if g_currentMission.nodeToObject[self.rootNode]==nil then
		return false
	end
	
	local x, y, z = localToLocal(node, spec.loadVolume.rootNode, 0, 0, 0)
	if ( x > 0 and spec.currentLoadside == "left") or 
	   ( x < 0 and spec.currentLoadside == "right") then
		return true
	else
		return false
	end
end
--
function UniversalAutoload:getPalletIsSelectedMaterial(object)

	local objectMaterialType = UniversalAutoload.getMaterialTypeName(object)
	local selectedMaterialType = UniversalAutoload.getSelectedMaterialType(self)

	if objectMaterialType~=nil and selectedMaterialType~=nil then
		if selectedMaterialType == UniversalAutoload.ALL then
			return true
		else
			return objectMaterialType == selectedMaterialType
		end
	else
		return false
	end
end
--
function UniversalAutoload:getPalletIsSelectedContainer(object)

	local objectContainerType = UniversalAutoload.getContainerTypeName(object)
	local selectedContainerType = UniversalAutoload.getSelectedContainerType(self)

	if objectContainerType~=nil and selectedContainerType~=nil then
		if selectedContainerType == UniversalAutoload.ALL then
			return true
		else
			return objectContainerType == selectedContainerType
		end
	else
		return false
	end
end
--
function UniversalAutoload.getPalletIsFull(object)
	if object.getFillUnits then
		for k, _ in ipairs(object:getFillUnits() or {}) do
			if object:getFillUnitFillLevelPercentage(k) < 1 then
				return false
			end
		end
	end
	return true
end
--
function UniversalAutoload:getMaxSingleLength()
	local spec = self.spec_universalAutoload

	local maxSingleLength = 0
	for i, loadArea in pairs(spec.loadArea) do
		if loadArea.length > maxSingleLength then
			maxSingleLength = math.floor(10*loadArea.length)/10
		end
	end
	return maxSingleLength
end				
--
function UniversalAutoload.raiseObjectDirtyFlags(object)
	if object.raiseDirtyFlags and object.getNextDirtyFlag then
		object.ualDirtyFlag = object.ualDirtyFlag or object:getNextDirtyFlag()
		if object.isRoundbale ~= nil then
			object:raiseDirtyFlags(object.ualDirtyFlag)
			if entityExists(object.nodeId) then
				object.sendPosX, object.sendPosY, object.sendPosZ = getWorldTranslation(object.nodeId)
				object.sendRotX, object.sendRotY, object.sendRotZ = getWorldRotation(object.nodeId)
			end
		else
			object:raiseDirtyFlags(object.ualDirtyFlag)
		end
	end
end

-- DRAW DEBUG PALLET FUNCTIONS
function UniversalAutoload:drawDebugDisplay()
	local spec = self.spec_universalAutoload

	if (UniversalAutoload.showLoading or UniversalAutoload.showDebug or spec.showDebug) and not g_gui:getIsGuiVisible() then
		
		local RED	 = { 1.0, 0.1, 0.1 }
		local GREEN   = { 0.1, 1.0, 0.1 }
		local YELLOW  = { 1.0, 1.0, 0.1 }
		local CYAN	= { 0.1, 1.0, 1.0 }
		local MAGENTA = { 1.0, 0.1, 1.0 }
		local GREY	= { 0.2, 0.2, 0.2 }
		local WHITE   = { 1.0, 1.0, 1.0 }
		
		local isActiveForInput = self:getIsActiveForInput()
		if not (isActiveForInput or self==UniversalAutoload.lastClosestVehicle) then
			RED = GREY
			GREEN = GREY
			YELLOW = GREY
			CYAN = GREY
			MAGENTA = GREY
			WHITE = GREY
		end
		
		if spec.currentLoadingPlace then
			local place = spec.currentLoadingPlace
			UniversalAutoload.DrawDebugPallet( place.node, place.sizeX, place.sizeY, place.sizeZ, true, false, GREY)
		end
		if UniversalAutoload.showDebug and spec.testLocation then
			UniversalAutoload.DrawDebugPallet( spec.testLocation.node, spec.testLocation.sizeX, spec.testLocation.sizeY, spec.testLocation.sizeZ, true, false, WHITE)
		end

		if UniversalAutoload.showDebug or spec.showDebug then
			for _, trigger in pairs(spec.triggers or {}) do
				if trigger.name == "rearAutoTrigger" or trigger.name == "leftAutoTrigger" or trigger.name == "rightAutoTrigger" then
					DebugUtil.drawDebugCube(trigger.node, 1,1,1, unpack(YELLOW))
				elseif trigger.name == "leftPickupTrigger" or trigger.name == "rightPickupTrigger"
					or trigger.name == "rearPickupTrigger" or trigger.name == "frontPickupTrigger"
					or (debugLoading and trigger.name == "unloadingTrigger") then
					DebugUtil.drawDebugCube(trigger.node, 1,1,1, unpack(MAGENTA))
				end
			end
		end
	
		for _, object in pairs(spec.availableObjects or {}) do
			if object then
				local node = UniversalAutoload.getObjectPositionNode(object)
				if node then
					local containerType = UniversalAutoload.getContainerType(object)
					local w, h, l = UniversalAutoload.getContainerTypeDimensions(containerType)
					local offset = 0 if containerType.isBale then offset = h/2 end
					if UniversalAutoload.isValidForLoading(self, object) then
						UniversalAutoload.DrawDebugPallet( node, w, h, l, true, false, GREEN, offset )
					else
						UniversalAutoload.DrawDebugPallet( node, w, h, l, true, false, GREY, offset )
					end
				end
			end
		end
		
		for _, object in pairs(spec.loadedObjects or {}) do
			if object then
				local node = UniversalAutoload.getObjectPositionNode(object)
				if node then
					local containerType = UniversalAutoload.getContainerType(object)
					local w, h, l = UniversalAutoload.getContainerTypeDimensions(containerType)
					local offset = 0 if containerType.isBale then offset = h/2 end
					if UniversalAutoload.isValidForUnloading(self, object) then 
						UniversalAutoload.DrawDebugPallet( node, w, h, l, true, false, GREEN, offset )
					else
						UniversalAutoload.DrawDebugPallet( node, w, h, l, true, false, GREY, offset )
					end
				end
			end
		end
		
		UniversalAutoload.debugRefreshTime = (UniversalAutoload.debugRefreshTime or 0) + g_currentDt
		if spec.objectsToUnload == nil or UniversalAutoload.debugRefreshTime > UniversalAutoload.DELAY_TIME then
			UniversalAutoload.debugRefreshTime = 0
			UniversalAutoload.buildObjectsToUnloadTable(self)
			spec.objectsToUnload = spec.objectsToUnload or {}
		end
		
		for object, unloadPlace in pairs(spec.objectsToUnload or {}) do
			local containerType = UniversalAutoload.getContainerType(object)
			local w, h, l = UniversalAutoload.getContainerTypeDimensions(containerType)
			local offset = 0 if containerType.isBale then offset = h/2 end
			if spec.unloadingAreaClear then
				UniversalAutoload.DrawDebugPallet( unloadPlace.node, w, h, l, true, false, CYAN, offset )
			else
				UniversalAutoload.DrawDebugPallet( unloadPlace.node, w, h, l, true, false, RED, offset )
			end
		end
		
		if UniversalAutoload.showDebug or spec.showDebug then
			local W, H, L = spec.loadVolume.width, spec.loadVolume.height, spec.loadVolume.length
			UniversalAutoload.DrawDebugPallet( spec.loadVolume.rootNode, W, H, L, true, false, MAGENTA )
			
			if spec.boundingBox then
				local W, H, L = spec.boundingBox.width, spec.boundingBox.height, spec.boundingBox.length
				UniversalAutoload.DrawDebugPallet( spec.boundingBox.rootNode, W, H, L, true, false, MAGENTA )
			end
		end
		
		for i, loadArea in pairs(spec.loadArea or {}) do
			local W, H, L = loadArea.width, loadArea.height, loadArea.length
			if not (UniversalAutoload.showDebug or spec.showDebug) then H = 0 end
			
			if UniversalAutoload.getIsLoadingAreaAllowed(self, i) then
				UniversalAutoload.DrawDebugPallet( loadArea.rootNode,  W, H, L, true, false, WHITE )
				UniversalAutoload.DrawDebugPallet( loadArea.startNode, W, 0, 0, true, false, GREEN )
				UniversalAutoload.DrawDebugPallet( loadArea.endNode,   W, 0, 0, true, false, RED )
				
				if (UniversalAutoload.showDebug or spec.showDebug) and loadArea.baleHeight then
					H = loadArea.baleHeight
					UniversalAutoload.DrawDebugPallet( loadArea.rootNode, W, H, L, true, false, YELLOW )
				end
			else
				UniversalAutoload.DrawDebugPallet( loadArea.rootNode,  W, H, L, true, false, GREY )
				if (UniversalAutoload.showDebug or spec.showDebug) and loadArea.baleHeight then
					H = loadArea.baleHeight
					UniversalAutoload.DrawDebugPallet( loadArea.rootNode, W, H, L, true, false, GREY )
				end
			end
		end
		
		if spec.lastLoadAttempt then
			local place = spec.lastLoadAttempt.loadPlace
			local containerType = spec.lastLoadAttempt.containerType
			local w, h, l = UniversalAutoload.getContainerTypeDimensions(containerType)
			UniversalAutoload.DrawDebugPallet( place.node, w, h, l, true, false, GREY, offset )
		end

		for id, object in pairs(UniversalAutoload.SPLITSHAPES_LOOKUP or {}) do
			DebugUtil.drawDebugNode(id, getName(id))
			DebugUtil.drawDebugNode(object.positionNodeId, getName(object.positionNodeId))
		end
		
	end
end
--
function UniversalAutoload.DrawDebugPallet( node, w, h, l, showCube, showAxis, colour, offset )

	if node and node ~= 0 and entityExists(node) then
		-- colour for square
		colour = colour or WHITE
		local r, g, b = unpack(colour)
		local w, h, l = (w or 1), (h or 1), (l or 1)
		local offset = offset or 0

		local xx,xy,xz = localDirectionToWorld(node, w,0,0)
		local yx,yy,yz = localDirectionToWorld(node, 0,h,0)
		local zx,zy,zz = localDirectionToWorld(node, 0,0,l)
		
		local x0,y0,z0 = localToWorld(node, -w/2, -offset, -l/2)
		drawDebugLine(x0,y0,z0,r,g,b,x0+xx,y0+xy,z0+xz,r,g,b)
		drawDebugLine(x0,y0,z0,r,g,b,x0+zx,y0+zy,z0+zz,r,g,b)
		drawDebugLine(x0+xx,y0+xy,z0+xz,r,g,b,x0+xx+zx,y0+xy+zy,z0+xz+zz,r,g,b)
		drawDebugLine(x0+zx,y0+zy,z0+zz,r,g,b,x0+xx+zx,y0+xy+zy,z0+xz+zz,r,g,b)

		if showCube then			
			local x1,y1,z1 = localToWorld(node, -w/2, h-offset, -l/2)
			drawDebugLine(x1,y1,z1,r,g,b,x1+xx,y1+xy,z1+xz,r,g,b)
			drawDebugLine(x1,y1,z1,r,g,b,x1+zx,y1+zy,z1+zz,r,g,b)
			drawDebugLine(x1+xx,y1+xy,z1+xz,r,g,b,x1+xx+zx,y1+xy+zy,z1+xz+zz,r,g,b)
			drawDebugLine(x1+zx,y1+zy,z1+zz,r,g,b,x1+xx+zx,y1+xy+zy,z1+xz+zz,r,g,b)
			
			drawDebugLine(x0,y0,z0,r,g,b,x1,y1,z1,r,g,b)
			drawDebugLine(x0+zx,y0+zy,z0+zz,r,g,b,x1+zx,y1+zy,z1+zz,r,g,b)
			drawDebugLine(x0+xx,y0+xy,z0+xz,r,g,b,x1+xx,y1+xy,z1+xz,r,g,b)
			drawDebugLine(x0+xx+zx,y0+xy+zy,z0+xz+zz,r,g,b,x1+xx+zx,y1+xy+zy,z1+xz+zz,r,g,b)
		end
		
		if showAxis then
			local x,y,z = localToWorld(node, 0, (h/2)-offset, 0)
			Utils.renderTextAtWorldPosition(x-xx/2,y-xy/2,z-xz/2, "-x", getCorrectTextSize(0.012), 0)
			Utils.renderTextAtWorldPosition(x+xx/2,y+xy/2,z+xz/2, "+x", getCorrectTextSize(0.012), 0)
			Utils.renderTextAtWorldPosition(x-yx/2,y-yy/2,z-yz/2, "-y", getCorrectTextSize(0.012), 0)
			Utils.renderTextAtWorldPosition(x+yx/2,y+yy/2,z+yz/2, "+y", getCorrectTextSize(0.012), 0)
			Utils.renderTextAtWorldPosition(x-zx/2,y-zy/2,z-zz/2, "-z", getCorrectTextSize(0.012), 0)
			Utils.renderTextAtWorldPosition(x+zx/2,y+zy/2,z+zz/2, "+z", getCorrectTextSize(0.012), 0)
			drawDebugLine(x-xx/2,y-xy/2,z-xz/2,1,1,1,x+xx/2,y+xy/2,z+xz/2,1,1,1)
			drawDebugLine(x-yx/2,y-yy/2,z-yz/2,1,1,1,x+yx/2,y+yy/2,z+yz/2,1,1,1)
			drawDebugLine(x-zx/2,y-zy/2,z-zz/2,1,1,1,x+zx/2,y+zy/2,z+zz/2,1,1,1)
		end
	
	end

end

-- DETECT SPAWNED LOGS
local oldAddToPhysics = getmetatable(_G).__index.addToPhysics
getmetatable(_G).__index.addToPhysics = function(node, ...)

	oldAddToPhysics(node, ...)
	
	if node ~= 0 and node then
		if getRigidBodyType(node) == RigidBodyType.DYNAMIC and getSplitType(node) ~= 0 then
			if not UniversalAutoload.createdLogId and UniversalAutoload.createdTreeId and node > UniversalAutoload.createdTreeId then
				UniversalAutoload.createdLogId = node
			end
		end
	end
end

-- ADD CUSTOM STRINGS FROM ModDesc.xml TO GLOBAL g_i18n
function UniversalAutoload.AddCustomStrings()
	-- print("  ADD custom strings from ModDesc.xml to g_i18n")
	local i = 0
	local xmlFile = loadXMLFile("modDesc", g_currentModDirectory.."modDesc.xml")
	while true do
		local key = string.format("modDesc.l10n.text(%d)", i)
		
		if not hasXMLProperty(xmlFile, key) then
			break
		end
		
		local name = getXMLString(xmlFile, key.."#name")
		local text = getXMLString(xmlFile, key.."."..g_languageShort)
		
		if name then
			g_i18n:setText(name, text)
			print("  "..tostring(name)..": "..tostring(text))
		end
		
		i = i + 1
	end
end
UniversalAutoload.AddCustomStrings()

-- Courseplay event listeners.
function UniversalAutoload:onAIImplementStart()
	--- TODO: Unfolding or opening cover, if needed!
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable then
		print("["..self.rootNode.."] UAL/CP - ACTIVATE BALE COLLECTION MODE (onAIImplementStart)")
		UniversalAutoload.setBaleCollectionMode(self, true)
		spec.aiLoadingActive = true
	end
end
--
function UniversalAutoload:onAIImplementEnd()
	--- TODO: Folding or closing cover, if needed!
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable and spec.aiLoadingActive then
		print("["..self.rootNode.."] UAL/CP - DEACTIVATE BALE COLLECTION MODE (onAIImplementEnd)")
		UniversalAutoload.setBaleCollectionMode(self, false)
		spec.aiLoadingActive = false
	end
end
--
function UniversalAutoload:onAIFieldWorkerStart()
	--- TODO: Unfolding or opening cover, if needed!
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable then
		print("["..self.rootNode.."] UAL/CP - ACTIVATE BALE COLLECTION MODE (onAIFieldWorkerStart)")
		UniversalAutoload.setBaleCollectionMode(self, true)
		spec.aiLoadingActive = true
	end
end
--
function UniversalAutoload:onAIFieldWorkerEnd()
	--- TODO: Folding or closing cover, if needed!
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable and spec.aiLoadingActive then
		print("["..self.rootNode.."] UAL/CP - DEACTIVATE BALE COLLECTION MODE (onAIFieldWorkerEnd)")
		UniversalAutoload.setBaleCollectionMode(self, false)
		spec.aiLoadingActive = false
	end
end  

-- CoursePlay interface functions.
function UniversalAutoload:ualIsFull()
	local spec = self.spec_universalAutoload
	return (spec and spec.isAutoloadAvailable) and spec.trailerIsFull
end
--
function UniversalAutoload:ualGetLoadedBales()
	local spec = self.spec_universalAutoload
	return (spec and spec.isAutoloadAvailable) and spec.loadedObjects
end
--
function UniversalAutoload:ualHasLoadedBales()
	print("["..self.rootNode.."] UAL/CP - ualHasLoadedBales")
	local spec = self.spec_universalAutoload
	return (spec and spec.isAutoloadAvailable) and spec.totalUnloadCount > 0
end
--
function UniversalAutoload:ualIsObjectLoadable(object)
	local spec = self.spec_universalAutoload
	print("["..self.rootNode.."] UAL/CP - ualIsObjectLoadable")
	--- TODO: Returns true, if the given object is loadable.
	--- For CP, the given object is of the class Bale.
	if spec and spec.isAutoloadAvailable then
		print("["..self.rootNode.."] UAL/CP - IS BALE = ".. tostring(UniversalAutoload.getContainerTypeName(object) == "BALE"))
		print("["..self.rootNode.."] UAL/CP - IS VALID = ".. tostring(UniversalAutoload.isValidForLoading(self, object)))
		return UniversalAutoload.getContainerTypeName(object) == "BALE" and UniversalAutoload.isValidForLoading(self, object)
	end
	return false
end

-- AutoDrive interface functions.
function UniversalAutoload:ualStartLoad()
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable then
		-- print("UAL/AD - START AUTOLOAD")
		UniversalAutoload.startLoading(self, true)
	end
end
function UniversalAutoload:ualStopLoad()
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable then
		-- print("UAL/AD - STOP AUTOLOAD")
		UniversalAutoload.stopLoading(self, true)
	end
end

function UniversalAutoload:ualUnload()
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable then
		-- print("UAL/AD - UNLOAD")
		UniversalAutoload.startUnloading(self, true)
	end
end

function UniversalAutoload:ualSetUnloadPosition(unloadPosition)
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable then
		-- print("UAL/AD - SET UNLOAD POSITION: " .. tostring(unloadPosition))
		spec.forceUnloadPosition = unloadPosition
	end
end


--[[
	TODO:
	Is spec.validUnloadCount the correct value to get the fill level?
	Add a better calculation for getFillUnitCapacity, for the moment it returns always 1 more than spec.validUnloadCount
	
	NOTE:
	I don't think it is possible to do better than this..
	We will never know if there is enough space for a pallet until we try to load it.
]]
function UniversalAutoload:ualGetFillUnitCapacity(fillUnitIndex)
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable then
		return (spec.validUnloadCount and (spec.validUnloadCount + 1)) or 0
	else
		return 0
	end
end

function UniversalAutoload:ualGetFillUnitFillLevel(fillUnitIndex)
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable then
		return (spec.validUnloadCount and spec.validUnloadCount) or 0
	else
		return 0
	end
end

-- return 0 if trailer is fully loaded / no capacity left
function UniversalAutoload:ualGetFillUnitFreeCapacity(fillUnitIndex)
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable then
		if spec.trailerIsFull then
			return 0
		else
			return self:ualGetFillUnitCapacity(fillUnitIndex) - self:ualGetFillUnitFillLevel(fillUnitIndex)
		end
	else
		return 0
	end
end