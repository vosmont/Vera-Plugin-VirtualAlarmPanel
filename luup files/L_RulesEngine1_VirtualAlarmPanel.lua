module("L_RulesEngine1_VirtualAlarmPanel", package.seeall)

-------------------------------------------
-- Plugin variables
-------------------------------------------

_NAME = "RulesEngine_VirtualAlarmPanel"
_DESCRIPTION = "Sauvegarde du statut de la règle dans un VirtualAlarmPanel et gestion d'un acquitement"
_VERSION = "0.01"

-- Services ids
local SID = {
	VirtualAlarmPanel = "urn:upnp-org:serviceId:VirtualAlarmPanel1"
}

local _indexRuleByPanelAlarm = {}
local _indexRuleByPanelAlarmModeAuto = {}

-- Action à l'initialisation d'une règle
RulesEngine.addHook(
	"VirtualAlarmPanel",
	"onRuleStatusInit",
	function (rule)
		local alarmPanel = rule.properties["alarm_panel"]
		if (type(alarmPanel) ~= "table") then
			RulesEngine.log("Rule '" .. rule.name .. "' has no alarmPanel param", "VirtualAlarmPanel.onRuleStatusInit", 3)
			return
		end
		alarmPanel.deviceId = tonumber(alarmPanel.deviceId)
		if ((alarmPanel.deviceId == nil) or (luup.devices[alarmPanel.deviceId] == nil)) then
			RulesEngine.log("Rule '" .. rule.name .. "' - VirtualAlarmPanel device is unkown", "VirtualAlarmPanel.onRuleStatusInit", 2)
			rule.properties["alarm_panel"] = nil
			return
		end

		-- Initialisation de la règle avec le statut du voyant
		RulesEngine.log("Rule '" .. rule.name .. "' - Retrieves status from alarm panel #" .. tostring(alarmPanel.deviceId) .. "' and alarm '" .. tostring(alarmPanel.alarmName) .. "'", "VirtualAlarmPanel.onRuleStatusInit", 2)
		local lul_resultcode, lul_resultstring, lul_job, lul_returnarguments = luup.call_action(
			SID.VirtualAlarmPanel,
			"GetAlarmStatus",
			{ alarmName = alarmPanel.alarmName },
			alarmPanel.deviceId
		)

		if ((lul_resultcode == 0) and (lul_returnarguments.retStatus ~= nil) and (lul_returnarguments.retStatus ~= "")) then
			rule._status = lul_returnarguments.retStatus
			rule.lastStatusUpdateTime = tonumber(lul_returnarguments.retLastUpdate)
		else
			RulesEngine.log("Rule '" .. rule.name .. "' - Can't retrieve status from VirtualAlarmPanel", "VirtualAlarmPanel.onRuleStatusInit", 1)
		end

		-- Enregistrement de l'observation des voyants
		-- Permet de gérer "à la main" le statut de la règle
		--luup.variable_watch("RulesEngine_VirtualAlarmPanel.onPanelAlarmStatusIsActivated", SID.VirtualAlarmPanel, "LastActiveAlarmId", rule.alarmPanel.deviceId)
	end
)

-- Action à l'activation d'une règle
RulesEngine.addHook(
	"VirtualAlarmPanel",
	"onRuleIsActivated",
	function (rule)
		local alarmPanel = rule.properties["alarm_panel"]
		if (type(alarmPanel) ~= "table") then
			return
		end
		-- Activation du voyant lié
		RulesEngine.log("Rule '" .. rule.name .. "' - Panel #" .. tostring(alarmPanel.deviceId) .. " - Activates alarm '" .. tostring(alarmPanel.alarmName) .. "'", "VirtualAlarmPanel.onRuleIsActivated", 1)

		local indexByPanelAlarmName = tostring(alarmPanel.deviceId) .. "-" .. tostring(alarmPanel.alarmName)
		_indexRuleByPanelAlarmModeAuto[indexByPanelAlarmName] = true

		luup.call_action(
			SID.VirtualAlarmPanel,
			"SetAlarmStatus",
			{ alarmName = alarmPanel.alarmName, newStatus = "1" },
			alarmPanel.deviceId
		)
	end
)

-- Action à la désactivation d'une règle
RulesEngine.addHook(
	"VirtualAlarmPanel",
	"onRuleIsDeactivated",
	function (rule)
		local alarmPanel = rule.properties["alarm_panel"]
		if (type(alarmPanel) ~= "table") then
			return
		end
		-- Désactivation du voyant lié
		RulesEngine.log("Rule '" .. rule.name .. "' - Panel #" .. tostring(alarmPanel.deviceId) .. " - Deactivates alarm '" .. tostring(alarmPanel.alarmName) .. "'", "VirtualAlarmPanel.onRuleIsDeactivated", 1)

		local indexByPanelAlarmName = tostring(alarmPanel.deviceId) .. "-" .. tostring(alarmPanel.alarmName)
		_indexRuleByPanelAlarmModeAuto[indexByPanelAlarmName] = true

		luup.call_action(
			SID.VirtualAlarmPanel,
			"SetAlarmStatus",
			{ alarmName = alarmPanel.alarmName, newStatus = "0" },
			alarmPanel.deviceId
		)
	end
)

-- **************************************************
-- Acknoledgment hook
-- **************************************************

-- Acknoledgment
-- If active, rule actions are not made
RulesEngine.addHook(
	"VirtualAlarmPanel",
	"beforeDoingAction",
	function (rule)
		local alarmPanel = rule.properties["alarm_panel"]
		if (type(alarmPanel) ~= "table") then
			return true
		end
		if (alarmPanel.isAcknowledgeable == "FALSE") then
			RulesEngine.log("Rule '" .. rule.name .. "' - Acknoledgement is not allowed", "VirtualAlarmPanel.beforeDoingAction", 3)
			return true
		end
		local lul_resultcode, lul_resultstring, lul_job, lul_returnarguments = luup.call_action(
			SID.VirtualAlarmPanel,
			"GetAlarmAcknowledge",
			{ alarmName = alarmPanel.alarmName },
			alarmPanel.deviceId
		)
		if (lul_resultcode == 0) then
			if (lul_returnarguments.retAcknowledge == "1") then
				RulesEngine.log("Rule '" .. rule.name .. "' - Is acknoledged", "VirtualAlarmPanel.beforeDoingAction", 1)
				return false
			end
		else
			RulesEngine.log("Rule '" .. rule.name .. "' - Can't retrieve acknoledge", "VirtualAlarmPanel.beforeDoingAction", 1)
		end
		return true
	end
)
