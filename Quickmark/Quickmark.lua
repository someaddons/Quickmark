-------- Variables --------

BINDING_HEADER_QUICKMARK = "Quickmark"

-- stores functions
Quickmark = {}
-- store Frames created(saves getglobal calls)
Quickmark.Frames = {}
-- stores state
Quickmark.state = "default"
-- store used icons during marking
local usedIcons = {}
-- cursor position for last mobs
local mobCursor = {}

------ Target Data ------
local currentTargetGroup = "undefined"
-- Saved Variables
QM_TargetData = QM_TargetData or {}
QM_GroupData = QM_GroupData or {"undefined"}
QM_SortedViewList = {}
QM_Options = QM_Options or {markType="safe", miniMap="true", debug=3}
-------- FUNCTIONS --------

-- triggered on PLAYER_ENTERING_WORLD
function Quickmark:OnLoad()
	Quickmark:ReloadListItems()
	
	-- Load Options
	if QM_Options.miniMap == "false" then QM_MINIMAPFRAME:Hide() end
	if QM_Options and QM_Options.miniMap and QM_Options.miniMap == "true" then QM_HELP_OPTIONS_FRAMEMiniMapButton:SetChecked(1) else QM_HELP_OPTIONS_FRAMEMiniMapButton:SetChecked(0) end
	if QM_Options.markType == "fast" then  QM_HELP_OPTIONS_FRAMEMarkState:SetChecked(1) end
end

-- triggered after this file is loaded
function Quickmark:LuaInit()
Quickmark:DebugMsg("Quickmark Loaded",0)
end

-- Adding slash commands to the slash table
SLASH_QUICKMARK1,SLASH_QUICKMARK2,SLASH_QUICKMARK3,SLASH_QUICKMARK4 = '/qm','/quickmark','/Quickmark','/QuickMark';
function SlashCmdList.QUICKMARK(cmd)
		if QuickmarkFrame:IsVisible() == 1 then
			QuickmarkFrame:Hide()
		else			
			QuickmarkFrame:Show()
		end
		Quickmark:DebugMsg("Quickmark Slash command",3)
end

-- Clear Target Markers
function Quickmark:ClearRaidTargets()
	Quickmark:DebugMsg("Quickmark:ClearRaidTargets()",3)
	for i = 1,8 do
		SetRaidTarget("player",i)
	end
	
	-- Create Frame to wait for the last mark and clear it
	local f = CreateFrame("Frame")
	f:RegisterEvent("OnUpdate")
	f.startTime = GetTime()
	f:SetScript("OnUpdate", function()
		if GetTime() - this.startTime > 0.2 and GetRaidTargetIndex("player")~=nil then 
			SetRaidTarget("player",0)
			this:SetScript("OnUpdate",nil)
			this:Hide()
		end
	end)
	usedIcons = {}
	mobCursor = {}
end

-- Mark the targets
function Quickmark:markPack()
	-- Check if we are already marking
	if Quickmark.state == "PACK_MARKING" then Quickmark:DebugMsg("Quickmark:markPack() is already marking",1) return end
	-- Set Quickmark.state
	Quickmark.state = "PACK_MARKING"
	
	-- direct Mark(Tab)
	if UnitExists("target") and UnitIsEnemy("target","player") and not UnitIsDead("target") and CheckInteractDistance("target",4) then 
		-- Nearest 5 targets
		for i = 1,5 do
			TargetNearestEnemy()
			if GetRaidTargetIndex("target") == nil then
				Quickmark:markUnit("target")		
			end		
		end
	
	-- mouseover mark
	else
		
		local f=CreateFrame('Frame',"QuickmarkMarkFrame")
		f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
		f:RegisterEvent("RAID_TARGET_UPDATE")
		f:RegisterEvent("OnUpdate")
		f.startTime = GetTime()
		f.markReady = 1
		
		-- Bigwigs timer for marking
		if BWLCB then BWLCB(10,"Marking pack") end
		f:SetScript("OnEvent", function() 


			if event == "RAID_TARGET_UPDATE" then
				this.markReady = 1
				return
			end

			if this.markReady or not QM_Options.markType or not QM_Options.markType == "safe" then
				local x, y = GetCursorPosition()
				if not mobCursor[UnitName("mouseover")] or 
					(GetTime() - mobCursor[UnitName("mouseover")]["time"]) > 0.5 or
					(abs(mobCursor[UnitName("mouseover")]["x"]-x) +abs(mobCursor[UnitName("mouseover")]["y"]-y)) > 15 then
						if Quickmark:markUnit("mouseover") then 
											
							-- save cursor position to not mark the same mob twice fast
							mobCursor[UnitName("mouseover")] = {}
							mobCursor[UnitName("mouseover")]["x"] = x
							mobCursor[UnitName("mouseover")]["y"] = y
							mobCursor[UnitName("mouseover")]["time"] = GetTime()	

							this.markReady = nil		
						end
				end
			end
		end)
		f:SetScript("OnUpdate", function()
			if GetTime() - this.startTime > 10 then 
				this:SetScript("OnEvent",nil)
				this:SetScript("OnUpdate",nil)
				Quickmark:DebugMsg("Quickmark:markPack() finished",3) 
				Quickmark.state = "default"
			end
			if Quickmark.state ~= "PACK_MARKING" then
				this:SetScript("OnEvent",nil)
				this:SetScript("OnUpdate",nil)
				Quickmark:DebugMsg("Quickmark:markPack() canceled, wrong state",2) 
			end
		end)
	end
end

-- Marks the given unit with preset icons
function Quickmark:markUnit(unit)
	
	if unit == nil or unit == "" or not UnitExists(unit) or UnitIsDead(unit) or UnitIsPlayer(unit) or UnitName(unit) == nil or UnitName(unit) == "" then return end

	local unitName = string.lower(UnitName(unit))
	
	if QM_TargetData[unitName] and GetRaidTargetIndex(unit) == nil then 		
		-- Cycle through the icons for this unit
		for i = 1,getn(QM_TargetData[unitName]["RaidIcons"]) do
			-- check if mark exists yet
			local markExists = 0 
			
			if usedIcons[QM_TargetData[unitName]["RaidIcons"][i]] and (GetTime() - usedIcons[QM_TargetData[unitName]["RaidIcons"][i]]) < 60 then markExists = 1 end

			-- Set Mark if not used yet
			if markExists == 0 then 
				Quickmark:DebugMsg("Quickmark:markUnit Marked: "..unitName.." with: "..QM_TargetData[unitName]["RaidIcons"][i],1) 
				SetRaidTarget(unit,QM_TargetData[unitName]["RaidIcons"][i])
				usedIcons[QM_TargetData[unitName]["RaidIcons"][i]] = GetTime()
				return 1
			end
		end
	end
	
	return
end

-- Starts the recording of targets/raidmarks
function Quickmark:StartRecording()
	
	-- Only one recording
	if Quickmark.state == "RECORDING" then return end
	
	Quickmark.state = "RECORDING"
	
	-- Register Events
	Quickmark.recordFrame = CreateFrame("Frame")
	local f = Quickmark.recordFrame
	f:RegisterEvent("PLAYER_TARGET_CHANGED")
	f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	f:RegisterEvent("OnUpdate")
	
	-- OnEvent: PLAYER_TARGET_CHANGED and UPDATE_MOUSEOVER_UNIT
	f:SetScript("OnEvent", function()
	
		local targetUnit;
		if event == "PLAYER_TARGET_CHANGED" then targetUnit = "target" else targetUnit = "mouseover" end
		local targetName = string.lower(UnitName(targetUnit) or "")
		local raidMark = GetRaidTargetIndex(targetUnit)
		-- Check for RaidIcon
		if raidMark == nil or targetName == nil or targetName=="" or UnitIsPlayer(targetUnit)  then return end
		
		-- Add new target
		if QM_TargetData[targetName] == nil then
				local t = {}
				table.insert(t,raidMark)
				Quickmark:addTargetData(targetName,t) 
		else
			-- Check if mark was added yet
			for index,val in pairs(QM_TargetData[targetName]["RaidIcons"]) do
				if val == raidMark then return end
			end
			
			table.insert(QM_TargetData[targetName]["RaidIcons"],raidMark)
			Quickmark:ReloadListItems()
		end
	end)
	
	f.t = GetTime()
		f:SetScript("OnUpdate", function() 

		-- different state, stop processing
		if Quickmark.state ~= "RECORDING" then
				this:SetScript("OnEvent",nil)
				this:SetScript("OnUpdate",nil)
				QM_PLAY_BUTTON:Show()
				QM_RECORD_BUTTON:Hide()
		end

		-- Run once each  2 seconds
		if GetTime() - this.t < 2 then return end
		this.t = GetTime()

		if not UnitExists("target") or UnitIsDead("target") or UnitIsPlayer("target") then return end
		local targetName = string.lower(UnitName("target") or "")
		local raidMark = GetRaidTargetIndex("target")
		-- Check for RaidIcon
		if raidMark == nil or targetName == nil or targetName == "" or UnitIsPlayer("target")  then return end
		
		-- Add new target
		if QM_TargetData[targetName] == nil then
				local t = {}
				table.insert(t,raidMark)
				Quickmark:addTargetData(targetName,t) 
		else
			-- Check if mark was added yet
			for index,val in pairs(QM_TargetData[targetName]["RaidIcons"]) do
				if val == raidMark then return end
			end
			
			table.insert(QM_TargetData[targetName]["RaidIcons"],raidMark)
			Quickmark:ReloadListItems()
		end
	end)
end

-- Starts the automatic marking of targets
function Quickmark:StartAutoMark()

	-- Only one recording
	if Quickmark.state == "AUTO_MARKING" then return end
	
	Quickmark.state = "AUTO_MARKING"
	
	local f = CreateFrame("Frame")
	Quickmark.autoMarkFrame = f
	
	f:RegisterEvent("PLAYER_TARGET_CHANGED")
	f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	f:RegisterEvent("OnUpdate")
	f:SetScript("OnEvent", function ()
		if event =="PLAYER_TARGET_CHANGED" then Quickmark:markUnit("target") else Quickmark:markUnit("mouseover") end
	end)
	f:SetScript("OnUpdate",function()
	if Quickmark.state ~= "AUTO_MARKING" then this:SetScript("OnUpdate",nil) this:SetScript("OnEvent",nil)  QM_MARK_ACTIVE:Hide() QM_MARK_INACTIVE:Show() end
	 end)

end

----- Data Functions -----
-- Save a Target with Icons
function Quickmark:addTargetData(name,raidIcons)
	if type(raidIcons) ~= "table" or type(name) ~= "string" then message("Quickmark:addTarget() wrong Parameter type: type(name):"..type(name).." type(RaidIcons):"..type(raidIcons)) return end
	
	name = string.lower(name)
	
	-- Insert Target name and Icons
	if QM_TargetData[name] == nil then QM_TargetData[name] = {} end
	QM_TargetData[name]["Name"] = name
	QM_TargetData[name]["RaidIcons"] = raidIcons
	QM_TargetData[name]["Group"] = currentTargetGroup
	
	Quickmark:RebuildViewGroup()
	
	-- Sets parameter of the scrollbar, amount of items items shown etc, call when changing amount of items
	FauxScrollFrame_Update(QuickmarkListScrollFrame,getn(QM_SortedViewList[currentTargetGroup]),20,16);
	Quickmark:ReloadListItems()
end

-- Remove a target
function Quickmark:removeTargetData(name)
	if type(name) ~= "string" then message("Quickmark:removeTargetData() wrong Parameter type: type(name):"..type(name)) return end
	
	name = string.lower(name)
	
	-- Remove Target
	if QM_TargetData[name] == nil then return end
	QM_TargetData[name] = nil
	
	Quickmark:RebuildViewGroup()
	
	-- Sets parameter of the scrollbar, amount of items items shown etc, call when changing amount of items
	FauxScrollFrame_Update(QuickmarkListScrollFrame,getn(QM_SortedViewList[currentTargetGroup]),20,16);
	Quickmark:ReloadListItems()
end

-- Add new group, sort after
function Quickmark:AddGroup(name)
	if type(name) ~= "string" or name == "" then return; end
	
	-- Check if same name exists already
	for i,v in pairs(QM_GroupData) do
		if string.upper(v) == string.upper(name) then message("Category exists already") return end
	end
	
	table.insert(QM_GroupData,name)
	table.sort(QM_GroupData)
end

-- Remove Group, sort after and remove from all Targets
function Quickmark:RemoveGroup(name)
	if type(name) ~= "string" or name == "" then return end
	
	-- Never remove the default category
	if string.upper(name) == string.upper("undefined") then message("Cannot remove default Category undefined") return end
	
	-- Remove from Group Table
	for index,value in pairs(QM_GroupData) do
		if string.upper(value) == string.upper(name) then 
			table.remove(QM_GroupData,index)
			table.sort(QM_GroupData)
			break
		end
	end
	
	-- Replace Targetdata
	for target in pairs(QM_TargetData) do
		if string.upper(QM_TargetData[target]["Group"]) == string.upper(name) then
			QM_TargetData[target]["Group"] = "undefined"
		end
	end
	
	-- Select default Group(visual)
	UIDropDownMenu_SetSelectedName(QuickmarkTargetGroupDropDown, "undefined");
	currentTargetGroup = "undefined"
	Quickmark:RebuildViewGroup()
	Quickmark:ReloadListItems()
end

-- Gathers statistics about targets(damage armor etc)
function Quickmark:AquireTargetStats(event)
	local targetUnit = event == "PLAYER_TARGET_CHANGED" and "target" or "mouseover"
	
	if not targetUnit or targetUnit == "" or not UnitExists(targetUnit) or UnitIsPlayer(targetUnit) then return end

	local targetName = string.lower(UnitName(targetUnit))

	-- Target is saved but stats are not
	if QM_TargetData[targetName] and not QM_TargetData[targetName]["Stats"] then
		QM_TargetData[targetName]["Stats"] = {}

		QM_TargetData[targetName]["Stats"]["Type"] = UnitCreatureType(targetUnit) or "none"
		local lowDmg, hiDmg = UnitDamage(targetUnit);
		QM_TargetData[targetName]["Stats"]["Damage"] = string.format("%.0f",lowDmg).."-"..string.format("%.0f",hiDmg)
		QM_TargetData[targetName]["Stats"]["Attackpower"] = UnitAttackPower(targetUnit)
		local mainSpeed, offSpeed = UnitAttackSpeed(targetUnit);
		QM_TargetData[targetName]["Stats"]["Attackspeed"] = "MH:"..string.format("%.2f",mainSpeed).." OH:"..string.format("%.2f",offSpeed or 0)
		QM_TargetData[targetName]["Stats"]["Armor"] = UnitResistance(targetUnit,0)
		QM_TargetData[targetName]["Stats"]["Fire"] = UnitResistance(targetUnit,2)
		QM_TargetData[targetName]["Stats"]["Nature"] = UnitResistance(targetUnit,3)
		QM_TargetData[targetName]["Stats"]["Frost"] = UnitResistance(targetUnit,4)
		QM_TargetData[targetName]["Stats"]["Shadow"] = UnitResistance(targetUnit,5)
		QM_TargetData[targetName]["Stats"]["Arcane"] = UnitResistance(targetUnit,6)

	end

end

---- UI Functions ----
-- Rebuild the sorted view list
function Quickmark:RebuildViewGroup()
	QM_SortedViewList[currentTargetGroup] = {}
	for name in pairs(QM_TargetData) do
		if QM_TargetData[name]["Group"] == currentTargetGroup then 
				table.insert(QM_SortedViewList[currentTargetGroup], name)
			end
		end
	table.sort(QM_SortedViewList[currentTargetGroup])
end

-- Reloads items shown in the list currently
function Quickmark:ReloadListItems()

	-- Reset current list items
	for i = 1,20 do
		if Quickmark.Frames["QuickmarkItem"..i] == nil then message("NIL FRAME: QuickmarkItem"..i) end
		Quickmark.Frames["QuickmarkItem"..i]:Hide()
		
	end

	-- Visually shown rownumber
	local listIndex = 1
	-- Scroll Offset(at which entry do we start listing)
	local offset = FauxScrollFrame_GetOffset(QuickmarkListScrollFrame)
	
	-- Loop current Group
	for i = 1+offset,getn(QM_SortedViewList[currentTargetGroup] or {}) do
	
		-- Name of the Target in list
		local unitName = QM_SortedViewList[currentTargetGroup][i]
		Quickmark.Frames["QuickmarkItem"..listIndex]:Show()
		Quickmark.Frames["QuickmarkItem"..listIndex.."Name"]:SetText(unitName)
		
		-- Hide All RaidIcons
		for k = 1,8 do 
			Quickmark.Frames["QuickmarkItem"..listIndex.."Raid"..k]:Hide()
		end
		-- Show set RaidIcons
		for j = 1,getn(QM_TargetData[unitName]["RaidIcons"]) do
			Quickmark.Frames["QuickmarkItem"..listIndex.."Raid"..QM_TargetData[unitName]["RaidIcons"][j]]:Show()
		end
		listIndex = listIndex + 1
		
		-- Only 20 items are shown
		if listIndex > 20 then break end
	end
end

-- Clears the UI Raid Icons selected
function Quickmark:ClearTargetIcons()
	QuickmarkRaidIcon8:SetChecked(0)
	QuickmarkRaidIcon7:SetChecked(0)
	QuickmarkRaidIcon6:SetChecked(0)
	QuickmarkRaidIcon5:SetChecked(0)
	QuickmarkRaidIcon4:SetChecked(0)
	QuickmarkRaidIcon3:SetChecked(0)
	QuickmarkRaidIcon2:SetChecked(0)
	QuickmarkRaidIcon1:SetChecked(0)
end

function Quickmark:buildStatTooltip(frameName)
	local targetName = Quickmark.Frames[frameName.."Name"] and Quickmark.Frames[frameName.."Name"]:GetText() or ""
	if not targetName or targetName == "" then return end
	
	-- Check if stats were recorded
	if QM_TargetData[targetName] and QM_TargetData[targetName]["Stats"] then

		local text = "Name: "..targetName
		text = text .. "\nType: "..QM_TargetData[targetName]["Stats"]["Type"]
		text = text .. "\nDamage: "..QM_TargetData[targetName]["Stats"]["Damage"]
		text = text .. "\nAttackpower: "..QM_TargetData[targetName]["Stats"]["Attackpower"]
		text = text .. "\nAttackspeed: "..QM_TargetData[targetName]["Stats"]["Attackspeed"]
		text = text .. "\nArmor: "..QM_TargetData[targetName]["Stats"]["Armor"]
		text = text .. "\nFire: "..QM_TargetData[targetName]["Stats"]["Fire"]
		text = text .. "\nNature: "..QM_TargetData[targetName]["Stats"]["Nature"]
		text = text .. "\nFrost: "..QM_TargetData[targetName]["Stats"]["Frost"]
		text = text .. "\nShadow: "..QM_TargetData[targetName]["Stats"]["Shadow"]
		text = text .. "\nArcane: "..QM_TargetData[targetName]["Stats"]["Arcane"]
		GameTooltip:SetText(text)
	end
end

-- On Group Add Click
function Quickmark:GroupCreateUI()
	
	StaticPopupDialogs["QuickmarkGroupCreate"] = {
		text = "Name of the Category you want to ADD",
		button1 = "Create",
		button2 = "Cancel",
		OnAccept = function()
			Quickmark:AddGroup(getglobal(this:GetParent():GetName().."WideEditBox"):GetText())
			StaticPopup_Hide ("QuickmarkGroupCreate")
		end,
		OnCancel = function()
			StaticPopup_Hide ("QuickmarkGroupCreate")
		end,
		OnShow = function (self, data)
			local editbox = getglobal(this:GetName().."WideEditBox")
			editbox:SetWidth(250)
			editbox:SetText("")
			editbox:SetScript("OnEscapePressed", function() StaticPopup_Hide ("QuickmarkGroupCreate") end)
		end,
		hasEditBox = true,
		hasWideEditBox = true,
		maxLetters = 42,
		--EditBox:setText("Text"),
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
	}

	StaticPopup_Show ("QuickmarkGroupCreate")
end

-- On Group Remove Click
function Quickmark:GroupRemoveUI()
	
	StaticPopupDialogs["QuickmarkGroupRemove"] = {
		text = "Name of the Category you want to REMOVE",
		button1 = "Remove",
		button2 = "Cancel",
		OnAccept = function()
			Quickmark:RemoveGroup(getglobal(this:GetParent():GetName().."WideEditBox"):GetText())
			StaticPopup_Hide ("QuickmarkGroupRemove")
		end,
		OnCancel = function()
			StaticPopup_Hide ("QuickmarkGroupRemove")
		end,
		OnShow = function (self, data)
			local editbox = getglobal(this:GetName().."WideEditBox")
			editbox:SetWidth(250)
			editbox:SetText("")
			editbox:SetScript("OnEscapePressed", function() StaticPopup_Hide ("QuickmarkGroupRemove") end)
		end,
		hasEditBox = true,
		hasWideEditBox = true,
		maxLetters = 42,
		--EditBox:setText("Text"),
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
	}

	StaticPopup_Show ("QuickmarkGroupRemove")
end

-- Called when the target changes, inserts name into the editbox
function Quickmark:TargetChanged()

	if event == "PLAYER_TARGET_CHANGED" then 
		if UnitName("target") ~= nil and UnitName("target") ~= "" and not UnitIsPlayer("target") and UnitName("target") ~= this:GetText() then 

			local name = string.lower(UnitName("target"))
			Quickmark:ClearTargetIcons()
			
			if QM_TargetData[name] then
				for k,v in pairs(QM_TargetData[name]["RaidIcons"]) do
					Quickmark.Frames["QuickmarkRaidIcon"..v]:SetChecked(1)
				end
			end
			
			
			
			this:SetText("")
			this.r = 1
			this:SetScript("OnUpdate",function() 
				if this.r>1 then 
					this:SetText(name or "") 
					this:SetScript("OnUpdate",nil) 
				end
				this.r = this.r + 1 
			end) 
		end 
	end
end

-- Add target to saved Data
function Quickmark:AddTarget()
	local targetName = QM_TargetEditBox:GetText();
	local raidMarks = {};

	-- Check raidmarks
	if QuickmarkRaidIcon8:GetChecked() then table.insert(raidMarks,8) end
	if QuickmarkRaidIcon7:GetChecked() then table.insert(raidMarks,7) end
	if QuickmarkRaidIcon6:GetChecked() then table.insert(raidMarks,6) end
	if QuickmarkRaidIcon5:GetChecked() then table.insert(raidMarks,5) end
	if QuickmarkRaidIcon4:GetChecked() then table.insert(raidMarks,4) end
	if QuickmarkRaidIcon3:GetChecked() then table.insert(raidMarks,3) end
	if QuickmarkRaidIcon2:GetChecked() then table.insert(raidMarks,2) end
	if QuickmarkRaidIcon1:GetChecked() then table.insert(raidMarks,1) end
	
	-- Only insert valid target data
	if targetName == nil or targetName == "" or targetName == " " or getn(raidMarks)<1 then 
		return
	end
	
	-- Save Target and clear input
	Quickmark:addTargetData(targetName,raidMarks)
	Quickmark:ClearTargetIcons()
	QM_TargetEditBox:SetText("")
end

-- Remove target from saved Data
function Quickmark:RemoveTarget()
	local targetName = QM_TargetEditBox:GetText();

	-- Only remove valid target data
	if targetName == nil or targetName == "" or targetName == " " then 
		return
	end
	
	-- Save Target and clear input
	Quickmark:removeTargetData(targetName)
	Quickmark:ClearTargetIcons()
	QM_TargetEditBox:SetText("")
end

-- Called when Target in UI List is clicked, loads Targetname/Icons
function Quickmark:SelectTarget()
	Quickmark:ClearTargetIcons()
	for i = 1,8 do 
		if Quickmark.Frames[this:GetName().."Raid"..i]:IsVisible() then 
			Quickmark.Frames["QuickmarkRaidIcon"..i]:SetChecked()
		end
	end
	
	QM_TargetEditBox:SetText(Quickmark.Frames[this:GetName().."Name"]:GetText());
	

end

-- Creates the Drop Down Items on the fly
function Quickmark:OnOpenGroupDropDown()
   
   -- Items in the Dropdown menu, default
   local info = { };
   
   for index,name in pairs(QM_GroupData) do
	   info.func = Quickmark["TargetDropDownClick"];
	   info.text = name;
	   UIDropDownMenu_AddButton(info);
   end
   
end

-- Sets the group when a dropdown icon is clicked
function Quickmark:TargetDropDownClick()
   UIDropDownMenu_SetSelectedID(QuickmarkTargetGroupDropDown, this:GetID());
   currentTargetGroup = this:GetText()
   Quickmark:RebuildViewGroup()
   Quickmark:ReloadListItems();
end

-- Fired on a ScrollEvent
function Quickmark:ScrollUpdate()
	Quickmark:ReloadListItems()
end

-- Debug Functions
function Quickmark:DebugMsg(msg,level)
	if QM_Options["debug"] < level then return end

	local t = type(msg)
	if t == "nil" then msg = "nil"
	elseif t == "number" then msg = tostring(f)
	elseif t == "boolean" then msg = msg and "true" or "false"
	elseif t == "table" then print(msg[1]) return
	elseif t == "function" then msg = "function"
	end
	if SELECTED_CHAT_FRAME then SELECTED_CHAT_FRAME:AddMessage(msg) end



end

Quickmark:LuaInit()
