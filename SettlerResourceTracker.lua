-----------------------------------------------------------------------------------------------
-- Client Lua Script for SettlerResourceTracker
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

-----------------------------------------------------------------------------------------------
-- SettlerResourceTracker Module Definition
-----------------------------------------------------------------------------------------------
local SettlerResourceTracker = {}

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function SettlerResourceTracker:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    -- initialize variables here

    return o
end

function SettlerResourceTracker:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end


-----------------------------------------------------------------------------------------------
-- SettlerResourceTracker OnLoad
-----------------------------------------------------------------------------------------------
function SettlerResourceTracker:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("SettlerResourceTracker.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)

	-- Define some vars
	self.iFound = 0;
	self.tLoot = {}
	self.zoneItems = setmetatable({}, {__index = function(tbl, key) tbl[key] = {} return tbl[key] end })
	
	if GameLib.GetPlayerUnit() then
		self:Refresh()
	else
		Apollo.RegisterEventHandler("CharacterCreated", "Refresh", self)
	end
end

-----------------------------------------------------------------------------------------------
-- SettlerResourceTracker OnDocLoaded
-----------------------------------------------------------------------------------------------
function SettlerResourceTracker:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "SRTForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end

	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil

		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("srt", "OnSettlerResourceTrackerOn", self)
		Apollo.RegisterEventHandler("LootedItem","OnLooted", self)
		Apollo.RegisterEventHandler("UpdateInventory","Refresh", self)
		Apollo.RegisterEventHandler("SubZoneChanged", "OnSubZoneChanged", self)

		--self.timer = ApolloTimer.Create(1.0, true, "Refresh", self)

		-- Do additional Addon initialization here
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "SRTForm", nil, self)
		self.wndMini = Apollo.LoadForm(self.xmlDoc, "SRTMini", nil, self)
		self.wndMini:Show(false)
		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = "Settler Resource Tracker"})
		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMini, strName = "Settler Resource Tracker Mini"})
		self.lootTable = self.wndMain:FindChild("Grid")
	end
end

-----------------------------------------------------------------------------------------------
-- SettlerResourceTracker Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/srt"
function SettlerResourceTracker:OnSettlerResourceTrackerOn()
	if not self.wndMain then 
		self.wndMain:Invoke() -- show the window
	else
		self.wndMain:Show(not self.wndMain:IsVisible())
	end
end

-- Saving Stuff
function SettlerResourceTracker:OnSave(eType)
	if eType == GameLib.CodeEnumAddonSaveLevel.Character then
		return self.zoneItems
	end
end

-- Loading Stuff
function SettlerResourceTracker:OnRestore(eType, tData)
	for k,v in pairs(tData) do
		self.zoneItems[k] = v
	end
end

-- Add an item to the zoneItems table
function SettlerResourceTracker:RecordItem(item)
	self.zoneItems[GameLib.GetCurrentZoneMap().id][item:GetName()] = item:GetItemId()
end

-- Lookup an item in the zoneItems table
function SettlerResourceTracker:Contains(item)
	return self.zoneItems[GameLib.GetCurrentZoneMap().id][item:GetName()]
end

-- Looting an item triggers this
function SettlerResourceTracker:OnLooted(item, nCount)
	if item:GetItemCategory() == 111 then -- if we have a settler resource item...
	
		if self.wndMain:FindChild("NothingHere"):IsVisible(true) then
			self.wndMain:FindChild("Grid"):Invoke()
			self.wndMain:FindChild("NothingHere"):Close()
			self.wndMain:FindChild("Title"):SetText("Settler Resource Tracker")
		end

		local iName = item:GetName()
		local iId = item:GetItemId()
		local zoneId = GameLib.GetCurrentZoneMap().id

		if self:Contains(item) ~= true then -- ... and it's not in the table...
			if zoneId ~= 60 then -- ... and we're not in our house...
				self:RecordItem(item) -- add it to the table with the zone we're in.
			end
		end

		if type(self.tLoot[1]) == "table" then
			for i = 1, #self.tLoot do
				if self.tLoot[i][1] == iName then
					self.iFound = 1;

					local prev_val = self.tLoot[i][2]
					self.tLoot[i] = {
						iName,
						nCount + prev_val
					}

					self.lootTable:SetCellText(i, 2, self.tLoot[i][2]);
				end
			end

			if self.iFound == 0 then
				local key = #self.tLoot + 1;
				self.tLoot[key] = {
					iName,
					nCount
				}

				self.lootTable:AddRow(self.tLoot[key][1]);
				self.lootTable:SetCellText(key, 2, self.tLoot[key][2])
			end

			self.iFound = 0;

		else
			self.tLoot[1] = {
				iName,
				nCount
			}

			self.lootTable:AddRow(self.tLoot[1][1]);
			self.lootTable:SetCellText(1, 2, self.tLoot[1][2])
		end

		self:Refresh()
	end
end

function SettlerResourceTracker:Refresh()
	self.tLoot = {}
	if self.lootTable then
		self.lootTable:DeleteAll()
	end
	if GameLib.GetPlayerUnit():GetSupplySatchelItems()["Settler Resources"] ~= nil then
		local settlerItems = GameLib.GetPlayerUnit():GetSupplySatchelItems()["Settler Resources"]
		local zoneId = GameLib.GetCurrentZoneMap().id
		
		for i, item in ipairs(settlerItems) do
			local iCount = item.nCount
			local sName = item.itemMaterial:GetName()
		
			if self.zoneItems[zoneId][sName] then
				if type(self.tLoot[1]) == "table" then
					for j = 1, #self.tLoot do
						if self.tLoot[j][1] == sName then
							self.iFound = 1;
							
							local oldVal = self.tLoot[j][2]
							self.tLoot[j] = {
								sName,
								oldVal + iCount
							}

							self.lootTable:SetCellText(j, 2, iCount)
						end
					end
				
					if self.iFound == 0 and self.zoneItems[zoneId][sName] then
						local key = #self.tLoot + 1;
						
						self.tLoot[key] = {
							sName,
							iCount
						}

						self.lootTable:AddRow(self.tLoot[key][1])
						self.lootTable:SetCellText(key, 2, self.tLoot[key][2])
					end
					self.iFound = 0
				
				else
					self.tLoot[1] = {
						sName,
						iCount
					}
					
					self.lootTable:AddRow(self.tLoot[1][1])
					self.lootTable:SetCellText(1, 2, self.tLoot[1][2])
				end
			end
		end
	else
		self.wndMain:FindChild("Grid"):Close()
		self.wndMain:FindChild("NothingHere"):Invoke()
		self.wndMain:FindChild("Title"):SetText("Sorry, cupcake! Nothin' to see.")
	end
end

-- Changing the Zone triggers this
function SettlerResourceTracker:OnSubZoneChanged(idZone, pszZoneName)
	self.curLoc = GameLib.GetCurrentZoneMap().strFolder
	
	if not self.curLoc:find("Adventure") and not self.curLoc:find("Hous") then
		self.wndMain:Show(true)
		self:Refresh()
	else
		self.wndMain:Show(false)
	end		
end
-----------------------------------------------------------------------------------------------
-- SettlerResourceTrackerForm Functions
-----------------------------------------------------------------------------------------------
-- when the Cancel button is clicked
function SettlerResourceTracker:OnCancel(wndHandler, wndControl, eMouseButton)
	wndControl:GetParent():Close() -- hide the window
end


---------------------------------------------------------------------------------------------------
-- SRTForm Functions
---------------------------------------------------------------------------------------------------

function SettlerResourceTracker:RemoveRow(tData)
	self.test = tData
	self.zoneItems[GameLib.GetCurrentZoneMap().id][tData:GetCellText(tData:GetCurrentRow(), 1)] = nil
	self.lootTable:DeleteRow(tData:GetCurrentRow())
end

function SettlerResourceTracker:OnLargeWinToggle( wndHandler, wndControl, eMouseButton )
	if not self.wndMini then
		self.wndMini:Invoke()
	else
		self.wndMain:Show(not self.wndMain:IsVisible())
		self.wndMini:Show(not self.wndMini:IsVisible())
	end
	wndControl:SetCheck(false)
end

-----------------------------------------------------------------------------------------------
-- SettlerResourceTracker Instance
-----------------------------------------------------------------------------------------------
local SettlerResourceTrackerInst = SettlerResourceTracker:new()
SettlerResourceTrackerInst:Init()
