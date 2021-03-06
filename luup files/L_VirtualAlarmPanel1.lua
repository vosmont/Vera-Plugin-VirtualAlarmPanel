module("L_VirtualAlarmPanel1", package.seeall)

-- Imports
local json = require("dkjson")

-- Devices ids
local DID = {
	VirtualAlarmPanel = "urn:schemas-upnp-org:device:VirtualAlarmPanel:1",
	ALTUI = "urn:schemas-upnp-org:device:altui:1"
}

-- Services ids
local SID = {
	VirtualAlarmPanel = "urn:upnp-org:serviceId:VirtualAlarmPanel1",
	ALTUI = "urn:upnp-org:serviceId:altui1"
}

-------------------------------------------
-- Plugin variables
-------------------------------------------

local PLUGIN_NAME = "VirtualAlarmPanel"
local PLUGIN_VERSION = "1.01"
local DEBUG_MODE = false
local settings = {}

-------------------------------------------
-- Tool functions
-------------------------------------------

-- Get variable value and init if value is nil
local function _getVariableOrInit (lul_device, serviceId, variableName, defaultValue)
	local value = luup.variable_get(serviceId, variableName, lul_device)
	if (value == nil) then
		luup.variable_set(serviceId, variableName, defaultValue, lul_device)
		value = defaultValue
	end
	return value
end

local function _setVariable (lul_device, serviceId, variableName, newValue, forceUpdate)
	local value = luup.variable_get(serviceId, variableName, lul_device)
	if (newValue == value) then
		if (forceUpdate) then
			luup.variable_set(serviceId, variableName, "", lul_device)
			luup.variable_set(serviceId, variableName, newValue, lul_device)
		end
	else
		luup.variable_set(serviceId, variableName, newValue, lul_device)
	end
end

local function log(methodName, text, level)
	luup.log("(" .. PLUGIN_NAME .. "::" .. tostring(methodName) .. ") " .. tostring(text), (level or 50))
end

local function error(methodName, text)
	log(methodName, "ERROR: " .. tostring(text), 1)
end

local function warning(methodName, text)
	log(methodName, "WARNING: " .. tostring(text), 2)
end

local function debug(methodName, text)
	if (DEBUG_MODE) then
		log(methodName, "DEBUG: " .. tostring(text))
	end
end

-------------------------------------------
-- Plugin functions
-------------------------------------------

-- Show message on UI
local function showMessageOnUI (lul_device, message)
	luup.variable_set(SID.VirtualAlarmPanel, "AlarmPanel", tostring(message), lul_device)
end

-- Change debug level log
function _onDebugValueIsUpdated (lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	if (lul_value_new == "1") then
		log("onDebugValueIsUpdated", "Enable debug mode")
		DEBUG_MODE = true
	else
		log("onDebugValueIsUpdated", "Disable debug mode")
		DEBUG_MODE = false
	end
	updatePanel(lul_device)
end

-- Register with ALTUI once it is ready
function _registerWithALTUI ()
	for deviceId, device in pairs(luup.devices) do
		if (device.device_type == DID.ALTUI) then
			if luup.is_ready(deviceId) then
				debug("registerWithALTUI", "Register with ALTUI main device #" .. tostring(deviceId))
				luup.call_action(
					SID.ALTUI,
					"RegisterPlugin",
					{
						newDeviceType = DID.VirtualAlarmPanel,
						newScriptFile = "J_ALTUI_VirtualAlarmPanel1.js",
						newDeviceDrawFunc = "ALTUI_VirtualAlarmPanel.drawDevice",
						newStyleFunc = "",
						newDeviceIconFunc = "",
						newControlPanelFunc = ""
					},
					deviceId
				)
			else
				debug("registerWithALTUI", "ALTUI main device #" .. tostring(deviceId) .. " is not yet ready, retry to register in 10 seconds...")
				luup.call_delay("VirtualAlarmPanel.registerWithALTUI", 10)
			end
			break
		end
	end
end

-- Get alarm or create it if wanted
local function getAlarm (lul_settings, createIfNotExists)
	debug("getAlarm", "lul_settings #" .. json.encode(lul_settings))
	lul_settings = lul_settings or {}
	local alarm, index = nil, 0

	-- Search by id
	if (lul_settings.alarmId ~= nil) then
		for i, alarmParam in ipairs(settings.alarms) do
			if (alarmParam.id == tostring(lul_settings.alarmId)) then
				alarm = alarmParam
				index = i
				break
			end
		end
	end

	-- Search by name (if not found by id)
	if ((alarm == nil) and (lul_settings.alarmName ~= nil)) then
		for i, alarmParam in ipairs(settings.alarms) do
			if (alarmParam.name == lul_settings.alarmName) then
				alarm = alarmParam
				index = i
				break
			end
		end
	end

	-- Alarm not founded
	if ((alarm == nil) and createIfNotExists) then
		alarm = {
			status = "0",
			acknowledge = "0"
		}
		if (lul_settings.alarmId ~= nil) then
			alarm.id = tostring(lul_settings.alarmId)
		else
			-- Search first free id
			for lastId = 1, 20 do
				local isFounded = false
				for i, alarmParam in ipairs(settings.alarms) do
					if (tostring(alarmParam.id) == tostring(lastId)) then
						isFounded = true
						index = i
						break
					end
				end
				if (not isFounded) then
					alarm.id = tostring(lastId)
					break
				end
			end
		end
		alarm.name = lul_settings.alarmName or ("__NEW_ALARM__" .. alarm.id)
		table.insert(settings.alarms, alarm)
	end

	if (alarm == nil) then
		error("getAlarm", "Can not retrieve alarm " .. json.encode(lul_settings))
	end

	return alarm, index
end

-- Update HTML panel show on UI
function updatePanel (lul_device)
	local status = "0"
	local style = ""

	local alarmPanel = ""

	if (DEBUG_MODE) then
		alarmPanel = alarmPanel .. '<div style="color:gray;text-align:left;"><small>Debug enabled</small></div>'
	end

	local activeAlarmPanel = ""
	for _, alarm in pairs(settings.alarms) do
		if (alarm.name ~= "") then
			style = "border: gray 1px solid; padding:1px; margin:1px; display:inline-block;"
			if (alarm.status == "1") then
				style = style .. " font-weight:bold;"
				if (alarm.acknowledge == "1") then
					-- Alarm active but with acknowledge
					if (status ~= "1") then
						-- There's not an active alarm without acknowledge
						status = "2"
					end
					style = style .. " color:orange;"
				else
					-- Alarm active
					status = "1"
					style = style .. " color:red;"
				end
				activeAlarmPanel = activeAlarmPanel .. '<li style="' .. style .. '">' .. tostring(alarm.name) .. '</li>'
			end
		end
	end

	if (activeAlarmPanel ~= "") then
		alarmPanel = alarmPanel .. '<small><ul class="AlarmPanel" style="text-align: justify; text-indent: 0px; display: inline;">' .. activeAlarmPanel .. '</ul></small>'
	else
		alarmPanel = alarmPanel .. '<div style="color:gray;text-align:left;"><small>No active alarm</small></div>'
	end

	luup.variable_set(SID.VirtualAlarmPanel, "AlarmPanel", alarmPanel, lul_device)
	luup.variable_set(SID.VirtualAlarmPanel, "Status", status, lul_device)
end

-------------------------------------------
-- Alarm management functions
-------------------------------------------

-- Set alarm name (and create if not exists)
function addAlarm (lul_device, lul_settings)
	lul_settings = lul_settings or {}
	local alarm = getAlarm(lul_settings, true)
	if (alarm == nil) then
		return false
	end
	debug("addAlarm", "Add alarm #" .. tostring(alarm.id) .. "'" .. tostring(alarm.name) .. "'")
	luup.variable_set(SID.VirtualAlarmPanel, "Alarms", json.encode(settings.alarms), lul_device)
	updatePanel(lul_device)
	return true
end

-- Remove alarm
function removeAlarm (lul_device, lul_settings)
	lul_settings = lul_settings or {}
	local alarm, index = getAlarm(lul_settings)
	if (alarm == nil) then
		return false
	end
	debug("removeAlarm", "Remove alarm #" .. tostring(alarm.id) .. "'" .. tostring(alarm.name) .. "'")
	table.remove(settings.alarms, index)
	luup.variable_set(SID.VirtualAlarmPanel, "Alarms", json.encode(settings.alarms), lul_device)
	updatePanel(lul_device)
	return true
end

-- Set alarm name (and create if not exists)
function setAlarmName (lul_device, lul_settings)
	lul_settings = lul_settings or {}
	local alarm = getAlarm(lul_settings, true)
	debug("setAlarmName", "Alarm #" .. tostring(alarm.id) .. "'" .. tostring(alarm.name) .. "' - Former name:" .. tostring(alarm.name) .. " - New name: " .. tostring(lul_settings.newAlarmName))
	if (alarm.name ~= lul_settings.newAlarmName) then
		alarm.name = lul_settings.newAlarmName
		luup.variable_set(SID.VirtualAlarmPanel, "Alarms", json.encode(settings.alarms), lul_device)
		updatePanel(lul_device)
	end
	return true
end

-- Get alarm name
function getAlarmName (lul_device, lul_settings)
	lul_settings = lul_settings or {}
	local alarm = getAlarm(lul_settings)
	if (alarm == nil) then
		luup.variable_set(SID.VirtualAlarmPanel, "LastResult", "", lul_device)
		return false
	end
	debug("getAlarmName", "Alarm #" .. tostring(alarm.id) .. "'" .. tostring(alarm.name) .. "' - Name:" .. tostring(alarm.name))
	luup.variable_set(SID.VirtualAlarmPanel, "LastResult", tostring(alarm.name), lul_device)
	return { retAlarmName = tostring(alarm.name) }
end

-- Get alarm id
function getAlarmId (lul_device, lul_settings)
	lul_settings = lul_settings or {}
	local alarm = getAlarm(lul_settings)
	if (alarm == nil) then
		luup.variable_set(SID.VirtualAlarmPanel, "LastResult", "", lul_device)
		return false
	end
	debug("getAlarmId", "Alarm #" .. tostring(alarm.id) .. "'" .. tostring(alarm.name) .. "' - Id:" .. tostring(alarm.id))
	luup.variable_set(SID.VirtualAlarmPanel, "LastResult", tostring(alarm.id), lul_device)
	return { retAlarmId = tostring(alarm.id) }
end

-- Set alarm position
function setAlarmPos (lul_device, lul_settings)
	lul_settings = lul_settings or {}
	lul_settings.newAlarmPos = tonumber(lul_settings.newAlarmPos) or 0
	local alarm, formerAlarmPos = getAlarm(lul_settings)
	if (alarm == nil) then
		luup.variable_set(SID.VirtualAlarmPanel, "LastResult", "Alarm not found", lul_device)
		return false
	end
	if ((lul_settings.newAlarmPos == 0) or (lul_settings.newAlarmPos > table.getn(settings.alarms))) then
		luup.variable_set(SID.VirtualAlarmPanel, "LastResult", "Invalid position", lul_device)
		return false
	end
	-- Get former position
	--local formerAlarmPos = 0
	--for i, alarmParam in ipairs(settings.alarms) do
	--	if (alarmParam.id == alarm.id) then
	--		formerAlarmPos = i
	--		break
	--	end
	--end
	debug("setAlarmPos", "Alarm #" .. tostring(alarm.id) .. "'" .. tostring(alarm.name) .. "' - Former pos: " .. tostring(formerAlarmPos) .. " - New pos: " .. tostring(lul_settings.newAlarmPos))
	if (lul_settings.newAlarmPos ~= formerAlarmPos) then
		table.remove(settings.alarms, formerAlarmPos)
		table.insert(settings.alarms, lul_settings.newAlarmPos, alarm)
		luup.variable_set(SID.VirtualAlarmPanel, "Alarms", json.encode(settings.alarms), lul_device)
		updatePanel(lul_device)
	end
	return true
end

-------------------------------------------
-- Alarm status functions
-------------------------------------------

-- Set alarm status
function setAlarmStatus (lul_device, lul_settings)
	local alarm = getAlarm(lul_settings)
	if (alarm == nil) then
		return false
	end
	debug("setAlarmStatus", "Alarm #" .. tostring(alarm.id) .. "'" .. tostring(alarm.name) .. "' - Former status:" .. tostring(alarm.status) .. " - New status: " .. tostring(lul_settings.newStatus))
	if (alarm.status ~= tostring(lul_settings.newStatus)) then
		alarm.status = tostring(lul_settings.newStatus)
		alarm.lastUpdate = os.time()
		if (alarm.status == "1") then
			debug("setAlarmStatus", "Alarm #" .. tostring(alarm.id) .. " is now active")
			luup.variable_set(SID.VirtualAlarmPanel, "LastActiveAlarmName", alarm.name, lul_device)
			luup.variable_set(SID.VirtualAlarmPanel, "LastActiveAlarmId", alarm.id, lul_device)
		else
			debug("setAlarmStatus", "Alarm #" .. tostring(alarm.id) .. " is now inactive")
			luup.variable_set(SID.VirtualAlarmPanel, "LastInactiveAlarmName", alarm.name, lul_device)
			luup.variable_set(SID.VirtualAlarmPanel, "LastInactiveAlarmId", alarm.id, lul_device)
			if (alarm.acknowledge == "1") then
				debug("setAlarmStatus", "Alarm #" .. tostring(alarm.id) .. " is now inactive but was acknowledged - Reset acknowledgement")
				alarm.acknowledge = "0"
			end
		end
		luup.variable_set(SID.VirtualAlarmPanel, "Alarms", json.encode(settings.alarms), lul_device)
		updatePanel(lul_device)
	end
	return true
end

-- Get alarm status
function getAlarmStatus (lul_device, lul_settings)
	local alarm = getAlarm(lul_settings)
	if (alarm == nil) then
		luup.variable_set(SID.VirtualAlarmPanel, "LastResult", "", lul_device)
		luup.variable_set(SID.VirtualAlarmPanel, "LastResult2", "", lul_device)
		return false
	end
	debug("getAlarmStatus", "Alarm #" .. tostring(alarm.id) .. "'" .. tostring(alarm.name) .. "' - Status:" .. tostring(alarm.status))
	luup.variable_set(SID.VirtualAlarmPanel, "LastResult", tostring(alarm.status), lul_device)
	luup.variable_set(SID.VirtualAlarmPanel, "LastResult2", tostring(alarm.lastUpdate), lul_device)
	return {
		retStatus = tostring(alarm.status),
		retLastUpdate = tostring(alarm.lastUpdate)
	}
end

-------------------------------------------
-- Alarm acknowledge functions
-------------------------------------------

-- Set alarm acknowledge
function setAlarmAcknowledge (lul_device, lul_settings)
	lul_settings = lul_settings or {}
	local alarm = getAlarm(lul_settings)
	if (alarm == nil) then
		return false
	end
	debug("setAlarmAcknowledge", "Alarm #" .. tostring(alarm.id) .. "'" .. tostring(alarm.name) .. "' - Former acknowledge:" .. tostring(alarm.acknowledge) .. " - New acknowledge: " .. tostring(lul_settings.newAcknowledge))
	if (alarm.acknowledge ~= tostring(lul_settings.newAcknowledge)) then
		alarm.acknowledge = tostring(lul_settings.newAcknowledge)
		if (alarm.acknowledge == "1") then
			debug("setAlarmAcknowledge", "Alarm #" .. tostring(alarm.id) .. " is now acknowledged")
			_setVariable(lul_device, SID.VirtualAlarmPanel, "LastAcknowlegedAlarmName", alarm.name, true)
			_setVariable(lul_device, SID.VirtualAlarmPanel, "LastAcknowlegedAlarmId", alarm.id, true)
		else
			debug("setAlarmStatus", "Alarm #" .. tostring(alarm.id) .. " is now not acknowledged")
			_setVariable(lul_device, SID.VirtualAlarmPanel, "LastUnacknowlegedAlarmName", alarm.name, true)
			_setVariable(lul_device, SID.VirtualAlarmPanel, "LastUnacknowlegedAlarmId", alarm.id, true)
		end
		luup.variable_set(SID.VirtualAlarmPanel, "Alarms", json.encode(settings.alarms), lul_device)
		updatePanel(lul_device)
	end
	return true
end

-- Get alarm acknowledge
function getAlarmAcknowledge (lul_device, lul_settings)
	local alarm = getAlarm(lul_settings)
	if (alarm == nil) then
		luup.variable_set(SID.VirtualAlarmPanel, "LastResult", "", lul_device)
		return false
	end
	debug("getAlarmAcknowledge", "Alarm #" .. tostring(alarm.id) .. "'" .. tostring(alarm.name) .. "' - Acknowledge:" .. tostring(alarm.acknowledge))
	luup.variable_set(SID.VirtualAlarmPanel, "LastResult", tostring(alarm.acknowledge), lul_device)
	return { retAcknowledge = tostring(alarm.acknowledge) }
end


-------------------------------------------
-- Startup
-------------------------------------------

-- Init plugin instance
function initPluginInstance (lul_device)
	log("initPluginInstance", "Init")

	--showMessageOnUI(lul_device, "Init...")

	settings = {
		deviceId = lul_device,
		alarms = {}
	}

	-- Get plugin params for this device
	_getVariableOrInit(lul_device, SID.VirtualAlarmPanel, "Status", "0")
	_getVariableOrInit(lul_device, SID.VirtualAlarmPanel, "AlarmPanel", "")
	_getVariableOrInit(lul_device, SID.VirtualAlarmPanel, "LastActiveAlarmName", "")
	_getVariableOrInit(lul_device, SID.VirtualAlarmPanel, "LastActiveAlarmId", "")
	_getVariableOrInit(lul_device, SID.VirtualAlarmPanel, "LastInactiveAlarmName", "")
	_getVariableOrInit(lul_device, SID.VirtualAlarmPanel, "LastInactiveAlarmId", "")
	_getVariableOrInit(lul_device, SID.VirtualAlarmPanel, "LastAcknowlegedAlarmName", "")
	_getVariableOrInit(lul_device, SID.VirtualAlarmPanel, "LastAcknowlegedAlarmId", "")
	_getVariableOrInit(lul_device, SID.VirtualAlarmPanel, "LastUnacknowlegedAlarmName", "")
	_getVariableOrInit(lul_device, SID.VirtualAlarmPanel, "LastUnacknowlegedAlarmId", "")
	_getVariableOrInit(lul_device, SID.VirtualAlarmPanel, "LastResult", "")

	-- Alarms
	local jsonAlarms = _getVariableOrInit(lul_device, SID.VirtualAlarmPanel, "Alarms", "[]")
	local decodeSuccess, alarms = pcall(json.decode, jsonAlarms)
	if ((not decodeSuccess) or (type(alarms) ~= "table")) then
		showMessageOnUI(lul_device, "Alarms decode error: " .. tostring(alarms))
		error("initPluginInstance", "Alarms decode error: " .. tostring(alarms))
	else
		settings.alarms = alarms
	end

	--_getVariableOrInit(lul_device, SID.VirtualAlarmPanel, "Options", "")
	DEBUG_MODE = (_getVariableOrInit(lul_device, SID.VirtualAlarmPanel, "Debug", "0") == "1")

	updatePanel(lul_device)

	return true
end

function startup (lul_device)
	log("startup", "Start plugin '" .. PLUGIN_NAME .. "' (v" .. PLUGIN_VERSION .. ")")

	-- Init
	initPluginInstance(lul_device)

	-- Watch setting changes
	--luup.variable_watch("initPluginInstance", SID.VirtualAlarmPanel, "Options", lul_device)
	luup.variable_watch("VirtualAlarmPanel.onDebugValueIsUpdated", SID.VirtualAlarmPanel, "Debug", lul_device)

	-- Register with ALTUI
	luup.call_delay("VirtualAlarmPanel.registerWithALTUI", 10)

	luup.set_failure(0, lul_device)

	return true
end

-- Promote the functions used by Vera's luup.xxx functions to the Global Name Space
_G["VirtualAlarmPanel.onDebugValueIsUpdated"] = _onDebugValueIsUpdated
_G["VirtualAlarmPanel.registerWithALTUI"] = _registerWithALTUI