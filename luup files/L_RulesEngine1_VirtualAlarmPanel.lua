module("L_RulesEngine1_VirtualAlarmPanel", package.seeall)

-------------------------------------------
-- Plugin variables
-------------------------------------------

_NAME = "RulesEngine_VirtualAlarmPanel"
_DESCRIPTION = "Link a rule with an alarm"
_VERSION = "1.00"

-- In openLuup, the module RulesEngine loaded during the startup sequence is in a dedicated environment.
local RulesEngine = L_RulesEngine1 or RulesEngine
assert((type(RulesEngine) == "table"), "RulesEngine is not loaded")

-- Services ids
local SID = {
	VirtualAlarmPanel = "urn:upnp-org:serviceId:VirtualAlarmPanel1"
}

local indexWatchedPanels = {}
local indexRuleIdByAlarmName = {}
local indexJustAcknowledgedAlarms = {}
local indexJustUnacknowledgedAlarms = {}

RulesEngine.addHook(
	"VirtualAlarmPanel",
	"onRuleStatusInit",
	function (rule)
		local alarmPanel = rule.properties["alarm_panel"]
		if (type(alarmPanel) ~= "table") then
			RulesEngine.log("Rule #" .. rule._id .. "(" .. rule.name .. ") has no alarmPanel param", "VirtualAlarmPanel.onRuleStatusInit", 3)
			return
		end
		alarmPanel.deviceId = tonumber(alarmPanel.deviceId)
		if ((alarmPanel.deviceId == nil) or (luup.devices[alarmPanel.deviceId] == nil)) then
			RulesEngine.addRuleError(rule._id, "VirtualAlarmPanel", "Alarm panel device is unkown")
			rule.properties["alarm_panel"] = nil
			return
		end

		-- Add the rule to the index
		indexRuleIdByAlarmName[tostring(alarmPanel.deviceId) .. "-" .. tostring(alarmPanel.alarmName)] = rule._id

		-- Set intial statuses according to the linked rule
		luup.call_action(
			SID.VirtualAlarmPanel,
			"SetAlarmStatus",
			{ alarmName = alarmPanel.alarmName, newStatus = rule._status },
			alarmPanel.deviceId
		)
		luup.call_action(
			SID.VirtualAlarmPanel,
			"SetAlarmAcknowledge",
			{ alarmName = alarmPanel.alarmName, newAcknowledge = rule._isAcknowledged },
			alarmPanel.deviceId
		)

		-- Starts watching
		if (indexWatchedPanels[tostring(alarmPanel.deviceId)] == nil) then
			luup.variable_watch("RulesEngine_VirtualAlarmPanel.onAlarmIsAcknowledged", SID.VirtualAlarmPanel, "LastAcknowlegedAlarmName", alarmPanel.deviceId)
			luup.variable_watch("RulesEngine_VirtualAlarmPanel.onAlarmIsUnacknowledged", SID.VirtualAlarmPanel, "LastUnacknowlegedAlarmName", alarmPanel.deviceId)
			indexWatchedPanels[tostring(alarmPanel.deviceId)] = true
		end
	end
)

RulesEngine.addHook(
	"VirtualAlarmPanel",
	"onRuleIsActivated",
	function (rule)
		local alarmPanel = rule.properties["alarm_panel"]
		if (type(alarmPanel) ~= "table") then
			return
		end
		RulesEngine.log("Rule #" .. rule._id .. "(" .. rule.name .. ") - Panel #" .. tostring(alarmPanel.deviceId) .. " - Activates alarm '" .. tostring(alarmPanel.alarmName) .. "'", "VirtualAlarmPanel.onRuleIsActivated", 3)
		luup.call_action(
			SID.VirtualAlarmPanel,
			"SetAlarmStatus",
			{ alarmName = alarmPanel.alarmName, newStatus = "1" },
			alarmPanel.deviceId
		)
	end
)

RulesEngine.addHook(
	"VirtualAlarmPanel",
	"onRuleIsDeactivated",
	function (rule)
		local alarmPanel = rule.properties["alarm_panel"]
		if (type(alarmPanel) ~= "table") then
			return
		end
		RulesEngine.log("Rule #" .. rule._id .. "(" .. rule.name .. ") - Panel #" .. tostring(alarmPanel.deviceId) .. " - Deactivates alarm '" .. tostring(alarmPanel.alarmName) .. "'", "VirtualAlarmPanel.onRuleIsDeactivated", 3)
		luup.call_action(
			SID.VirtualAlarmPanel,
			"SetAlarmStatus",
			{ alarmName = alarmPanel.alarmName, newStatus = "0" },
			alarmPanel.deviceId
		)
	end
)

RulesEngine.addHook(
	"VirtualAlarmPanel",
	"onRuleIsAcknowledged",
	function (rule)
		local alarmPanel = rule.properties["alarm_panel"]
		if (type(alarmPanel) ~= "table") then
			return
		end
		RulesEngine.log("Rule #" .. rule._id .. "(" .. rule.name .. ") - Panel #" .. tostring(alarmPanel.deviceId) .. " - Acknowledges alarm '" .. tostring(alarmPanel.alarmName) .. "'", "VirtualAlarmPanel.onRuleIsAcknowledged", 3)
		indexJustAcknowledgedAlarms[tostring(alarmPanel.deviceId) .. "-" .. tostring(alarmPanel.alarmName)] = true
		luup.call_action(
			SID.VirtualAlarmPanel,
			"SetAlarmAcknowledge",
			{ alarmName = alarmPanel.alarmName, newAcknowledge = "1" },
			alarmPanel.deviceId
		)
	end
)

RulesEngine.addHook(
	"VirtualAlarmPanel",
	"onRuleIsUnacknowledged",
	function (rule)
		local alarmPanel = rule.properties["alarm_panel"]
		if (type(alarmPanel) ~= "table") then
			return
		end
		RulesEngine.log("Rule #" .. rule._id .. "(" .. rule.name .. ") - Panel #" .. tostring(alarmPanel.deviceId) .. " - Unacknowledges alarm '" .. tostring(alarmPanel.alarmName) .. "'", "VirtualAlarmPanel.onRuleIsAcknowledged", 3)
		indexJustUnacknowledgedAlarms[tostring(alarmPanel.deviceId) .. "-" .. tostring(alarmPanel.alarmName)] = true
		luup.call_action(
			SID.VirtualAlarmPanel,
			"SetAlarmAcknowledge",
			{ alarmName = alarmPanel.alarmName, newAcknowledge = "0" },
			alarmPanel.deviceId
		)
	end
)

local function _onAlarmIsAcknowledged (lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	if ((lul_value_new == nil) or (lul_value_new == "")) then
		return
	end
	local indexName = tostring(lul_device) .. "-" .. tostring(lul_value_new)
	if (indexJustAcknowledgedAlarms[indexName]) then
		indexJustAcknowledgedAlarms[indexName] = false
		return
	end
	local ruleId = indexRuleIdByAlarmName[indexName]
	RulesEngine.setRuleAcknowledgement(ruleId, "1")
end
_G["RulesEngine_VirtualAlarmPanel.onAlarmIsAcknowledged"] = _onAlarmIsAcknowledged

local function _onAlarmIsUnacknowledged (lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	if ((lul_value_new == nil) or (lul_value_new == "")) then
		return
	end
	local indexName = tostring(lul_device) .. "-" .. tostring(lul_value_new)
	if (indexJustUnacknowledgedAlarms[indexName]) then
		indexJustUnacknowledgedAlarms[indexName] = false
		return
	end
	local ruleId = indexRuleIdByAlarmName[indexName]
	RulesEngine.setRuleAcknowledgement(ruleId, "0")
end
_G["RulesEngine_VirtualAlarmPanel.onAlarmIsUnacknowledged"] = _onAlarmIsUnacknowledged
