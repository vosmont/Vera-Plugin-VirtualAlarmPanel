//@ sourceURL=J_VirtualAlarmPanel1.js

var VirtualAlarmPanel = (function (api, $) {

	var myModule = {
		uuid: "3caf1f32-dc65-43b1-a77d-9d51e598389b",
	};
	var VIRTUAL_ALARM_PANEL_SID = "urn:upnp-org:serviceId:VirtualAlarmPanel1";
	var _alarms = [];
	var _deviceId = null;

	// Inject plugin specific CSS rules
	$("<style>")
		.prop("type", "text/css")
		.html("\
			@-webkit-keyframes blinker { from { opacity: 1.0; } to { opacity: 0.2; } }\
			@keyframes blinker { from { opacity: 1.0; } to { opacity: 0.2; } }\
			#VirtualAlarmPanel { width: 450px; margin: 10px auto; text-align: center; }\
			#VirtualAlarmPanel_Add {\
				float:left; width: 32px; height: 32px; margin: 5px;\
				background-image: url(\"skins/default/img/other/plus_white.png\");\
			}\
			#VirtualAlarmPanel_Add:hover {\
				background-image: url(\"skins/default/img/other/plus_white_hover.png\");\
			}\
			#VirtualAlarmPanel_Trash {\
				float:right; width: 32px; height: 32px; margin: 5px;\
				overflow: hidden;\
				background-image: url(\"skins/default/img/other/deleteHistory.png\");\
			}\
			#VirtualAlarmPanel_Trash:hover {\
				background-image: url(\"skins/default/img/other/deleteHistoryHover.png\");\
			}\
			#VirtualAlarmPanel_Alarms {\
				clear: both; height: 300px;\
			}\
			#VirtualAlarmPanel .alarm {\
				float:left; width: 215px; height: 50px; margin: 5px;\
				background: #FFFFFF;\
				border: solid 1px gray; border-radius: 10px;\
			}\
			#VirtualAlarmPanel .alarmBadge {\
				float:left; width: 36px; height: 50px;\
				background: no-repeat center center;\
				cursor: move;\
			}\
			#VirtualAlarmPanel .alarm.active .alarmBadge {\
				background-image: url(\"skins/default/img/icons/icon_error_24x24.png\");\
				-webkit-animation: blinker 0.5s infinite alternate;\
				animation: blinker 0.5s infinite alternate;\
			}\
			#VirtualAlarmPanel .alarm.active.acknowledge .alarmBadge {\
				background-image: url(\"skins/default/img/icons/icon_notification_24x24.png\");\
			}\
			#VirtualAlarmPanel .alarmInfos {\
				float:left; width: 141px; height: 100%;\
				background: #eee;\
				display: flex; justify-content: center; flex-direction: column;\
			}\
			#VirtualAlarmPanel .alarm.active .alarmInfos { background: #FF7366; }\
			#VirtualAlarmPanel .alarm.active.acknowledge .alarmInfos { background: #FF8942; }\
			#VirtualAlarmPanel .alarmName { padding: 5px; line-height: 1em; }\
			#VirtualAlarmPanel .alarmLastUpdate { font-size: small; }\
			#VirtualAlarmPanel .alarmButtons {\
				float: right; width: 36px; height: 50px; text-align: right;\
			}\
			#VirtualAlarmPanel .alarm .acknowledgeButton {\
				width: 32px; height: 32px;\
				margin: 8px 0 0 2px;\
				display: none;\
				background-image: url(\"skins/default/img/other/button_unchecked.png\")\
			}\
			#VirtualAlarmPanel .alarm.active .acknowledgeButton {\
				display: block;\
			}\
			#VirtualAlarmPanel .alarm .acknowledgeButton:hover {\
				background-image: url(\"skins/default/img/other/button_unchecked_hover.png\")\
			}\
			#VirtualAlarmPanel .alarm .acknowledgeButton.active {\
				background-image: url(\"skins/default/img/other/button_checked.png\")\
			}\
			#VirtualAlarmPanel .alarm .acknowledgeButton.active:hover {\
				background-image: url(\"skins/default/img/other/button_checked_hover.png\")\
			}\
		")
		.appendTo("head");

	/**
	 * Get alarm list
	 */
	function getAlarmList (deviceId) {
		var alarms = [];
		try {
			alarms = $.parseJSON(api.getDeviceStateVariable(deviceId, VIRTUAL_ALARM_PANEL_SID, "Alarms", {dynamic: true}));
		} catch (err) {
			Utils.logError('Error in VirtualAlarmPanel.getAlarmList(): ' + err);
		}
		return alarms;
	}

	function convertToDate(timestamp) {
		if (typeof(timestamp) == "undefined") {
			return "";
		}
		//console.log(timestamp);
		var t = new Date(parseInt(timestamp, 10) * 1000);
		//var t = new Date();
		//t.setSeconds( timestamp );
		
		//var formatted = t.format("dd.mm.yyyy hh:MM:ss");
		var formatted = t.toLocaleString();
		//console.log(formatted);
		return formatted;
	}

	/**
	 * Draw and manage alarm list
	 */
	function drawAlarmList (deviceId, alarms) {
		if (alarms.length > 0) {
			$("#VirtualAlarmPanel_Alarms").empty();
			$.each(alarms, function(i, alarm) {
				$("#VirtualAlarmPanel_Alarms").append(
						'<div class="alarm' + (alarm.status == "1" ? ' active' : '') + (alarm.acknowledge == "1" ? ' acknowledge' : '') + '" data-alarm_id="' + alarm.id + '">'
					+		'<div class="alarmBadge"> </div>'
					+		'<div class="alarmInfos">'
					+			'<div class="alarmName" contenteditable="true">'
					+				alarm.name
					+			'</div>'
					+			'<div class="alarmLastUpdate">'
					+				convertToDate(alarm.lastUpdate)
					+			'</div>'
					+		'</div>'
					+		'<div class="alarmButtons">'
					//+			'<div class="removeButton"> </div>'
					//+			'<button class="SurveillanceStationRemote-enable ui-widget-content ui-corner-all' + (alarm.status == "1" ? ' active' : '') + '">ON</button>'
					+			'<div class="acknowledgeButton' + (alarm.acknowledge == "1" ? ' active' : '') + '" title="' + (alarm.acknowledge == "1" ? 'Remove acknowledge' : 'Acknowledge alarm') + '"> </div>'
					+		'</div>'
					+	'</div>'
				);
			});

			// Sort the alarms
			//$("#VirtualAlarmPanel_Alarms, #VirtualAlarmPanel_Trash").sortable({
			$("#VirtualAlarmPanel .connectedSortable").sortable({
				revert: true,
				dropOnEmpty: true,
				handle: "div.alarmBadge",
				cancel: "button, [contenteditable]",
				connectWith: "#VirtualAlarmPanel .connectedSortable",
				//tolerance: "pointer",
				over: function ( event, ui ) {
					if (this.id == "VirtualAlarmPanel_Trash") {
						$(ui.helper).fadeTo( "fast", 0.2 );
					} else {
						$(ui.helper).fadeTo( "fast", 1 );
					}
				},
				update: function ( event, ui ) {
					var $alarm = ui.item;
					var alarmId = $alarm.data("alarm_id");
					var alarmName = $alarm.find(".alarmName").text();
					if (this.id == "VirtualAlarmPanel_Trash") {
						$(ui.helper).fadeTo( "fast", 0 );
						if (confirm('Are you sure you want to remove alarm "' + alarmName + '" ?')) {
							myInterface.showModalLoading();
							api.performActionOnDevice(deviceId, VIRTUAL_ALARM_PANEL_SID, "RemoveAlarm", {
								actionArguments: {
									alarmId: alarmId
								},
								onSuccess: function () {
									myInterface.hideModalLoading();
								},
								onFailure: function () {
									myInterface.hideModalLoading();
									Utils.logDebug("[VirtualAlarmPanel.removeAlarm] KO");
								}
							});
						} else {
							$(ui.sender).sortable("cancel");
						}
					} else {
						var alarmPos = $("#VirtualAlarmPanel .alarm").index( $alarm ) + 1;
						myInterface.showModalLoading();
						api.performActionOnDevice(deviceId, VIRTUAL_ALARM_PANEL_SID, "SetAlarmPos", {
							actionArguments: {
								alarmId: alarmId,
								newAlarmPos: alarmPos
							},
							onSuccess: function () {
								myInterface.hideModalLoading();
							},
							onFailure: function () {
								myInterface.hideModalLoading();
								Utils.logDebug("[VirtualAlarmPanel.setAlarmAcknowledge] KO");
							}
						});
					}
				}/*,
				stop: function ( event, ui ) {
					var $alarm = ui.item;
					var alarmId = $alarm.data("alarm_id");
					var alarmPos = $("#VirtualAlarmPanel .alarm").index( $alarm ) + 1;
					myInterface.showModalLoading();
					api.performActionOnDevice(deviceId, VIRTUAL_ALARM_PANEL_SID, "SetAlarmPos", {
						actionArguments: {
							alarmId: alarmId,
							newAlarmPos: alarmPos
						},
						onSuccess: function () {
							myInterface.hideModalLoading();
						},
						onFailure: function () {
							myInterface.hideModalLoading();
							Utils.logDebug("[VirtualAlarmPanel.setAlarmAcknowledge] KO");
						}
					});
				}*/
			});

			// Remove button
			/*
			$("#VirtualAlarmPanel_Alarms .removeButton").click(function () {
				var $alarm = $(this).parent().parent();
				var alarmId = $alarm.data("alarm_id");
				var alarmName = $alarm.children(".alarmName").text();
				if (confirm('Are you sure you want to remove alarm "' + alarmName + '" ?')) {
					$alarm.remove();
				}
			});
			*/

			// Acknowledge button
			$("#VirtualAlarmPanel_Alarms .acknowledgeButton").click(function () {
				var $alarm = $(this).parent().parent();
				var alarmId = $alarm.data("alarm_id");
				var alarmName = $alarm.find(".alarmName").text();
				var acknowledge;
				if ($(this).hasClass("active")) {
					// Remove acknowledge
					$(this).removeClass("active").attr("title", "Acknowledge alarm");
					$alarm.removeClass("acknowledge");
					acknowledge = "0";
				} else {
					// Add acknowledge
					if (!$alarm.hasClass("active") && !confirm('Alarm "' + alarmName + '" is not active. Are you sure you want to acknowledge in advance ?')) {
						return false;
					}
					$(this).addClass("active").attr("title", "Remove acknowledgement");
					$alarm.addClass("acknowledge");
					acknowledge = "1";
				}
				myInterface.showModalLoading();
				api.performActionOnDevice(deviceId, VIRTUAL_ALARM_PANEL_SID, "SetAlarmAcknowledge", {
					actionArguments: {
						alarmId: alarmId,
						newAcknowledge: acknowledge
					},
					onSuccess: function () {
						myInterface.hideModalLoading();
					},
					onFailure: function () {
						myInterface.hideModalLoading();
						Utils.logDebug("[VirtualAlarmPanel.setAlarmAcknowledge] KO");
					}
				});
			});

			// Editable alarm name
			$("#VirtualAlarmPanel_Alarms .alarmName[contenteditable=true]").blur(function() {
				var $alarm = $(this).parent().parent();
				var alarmId = $alarm.data("alarm_id");
				var newAlarmName = $(this).text();
				if (newAlarmName != "") {
					myInterface.showModalLoading();
					api.performActionOnDevice(deviceId, VIRTUAL_ALARM_PANEL_SID, "SetAlarmName", {
						actionArguments: {
							alarmId: alarmId,
							newAlarmName: newAlarmName
						},
						onSuccess: function () {
							myInterface.hideModalLoading();
						},
						onFailure: function () {
							myInterface.hideModalLoading();
							Utils.logDebug("[VirtualAlarmPanel.setAlarmAcknowledge] KO");
						}
					});
				}
			});
		} else {
			$("#VirtualAlarmPanel_Alarms").html("There's no alarm.");
		}
	}

	/**
	 *
	 */
	function onDeviceStatusChanged (deviceObjectFromLuStatus) {
		if (deviceObjectFromLuStatus.id == _deviceId) {
			for (i = 0; i < deviceObjectFromLuStatus.states.length; i++) { 
				if (deviceObjectFromLuStatus.states[i].variable == "Alarms") {
					var alarms = [];
					try {
						alarms = $.parseJSON(deviceObjectFromLuStatus.states[i].value);
					} catch (err) {
						Utils.logError('Error in VirtualAlarmPanel.onDeviceStatusChanged(): ' + err);
					}
					drawAlarmList(_deviceId, alarms);
					return;
				}
			}
		}
	}

	/**
	 * Show alarms
	 */
	function showAlarms (deviceId) {
		try {
			_deviceId = deviceId;
			api.setCpanelContent(
					'<div id="VirtualAlarmPanel">'
				+		'<div id="VirtualAlarmPanel_Add"></div>'
				+		'<div id="VirtualAlarmPanel_Trash" class="connectedSortable"></div>'
				+		'<div id="VirtualAlarmPanel_Alarms" class="connectedSortable">'
				+			"There's no alarm."
				+		'</div>'
				+	'</div>'
			);

			// Add alarm button
			$("#VirtualAlarmPanel_Add").click(function () {
				myInterface.showModalLoading();
				api.performActionOnDevice(deviceId, VIRTUAL_ALARM_PANEL_SID, "AddAlarm", {
					actionArguments: {
						//alarmId: null,
						alarmName: "New alarm"
					},
					onSuccess: function () {
						myInterface.hideModalLoading();
					},
					onFailure: function () {
						myInterface.hideModalLoading();
						Utils.logDebug("[VirtualAlarmPanel.addAlarm] KO");
					}
				});
			});

			// Show alarm list
			var alarms = getAlarmList(deviceId);
			drawAlarmList(deviceId, alarms);

			// Register
			api.registerEventHandler("on_ui_deviceStatusChanged", myModule, "onDeviceStatusChanged");
		} catch (err) {
			Utils.logError('Error in VirtualAlarmPanel.showAlarms(): ' + err);
		}
	}

	myModule.onDeviceStatusChanged = onDeviceStatusChanged;
	myModule.showAlarms = showAlarms;
	return myModule;

})(api, jQuery);
