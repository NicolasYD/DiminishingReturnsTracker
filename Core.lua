-- Create a new addon object using AceAddon-3.0 and include AceConsole-3.0 and AceEvent-3.0 as mixins
DRT = LibStub("AceAddon-3.0"):NewAddon("DRT", "AceConsole-3.0", "AceEvent-3.0")


-- Called when the addon is first loaded (before it is enabled)
function DRT:OnInitialize()
    -- Setup database
    self.db = LibStub("AceDB-3.0"):New("DRTDB", {
        profile = {
            modules = {
                ['*'] = {
                    enabled = false,
                },
                UF = {
                    enabled = true,
                },
				NP = {
                    enabled = true,
                },
            }
        }
    })

	self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")

    -- Disable modules based on saved profile settings (AceAddon will auto-enable the module at startup, regardless of saved profile settings)
    for name, module in self:IterateModules() do
        local modSettings = self.db.profile.modules[name]
        if modSettings and modSettings.enabled == false then
            self:DisableModule(name)
        end
    end

    -- Get the addon configuration options
    self:GetOptions()

	self:CheckVersion()
end


-- Called when the addon is enabled (e.g., when logging in or reloading UI)
function DRT:OnEnable()
    -- Register slash commands to open the configuration panel
    self:RegisterChatCommand("drt", "OpenOptions")
    self:RegisterChatCommand("diminishingreturnstracker", "OpenOptions")

	self:RegisterEvent("PLAYER_ENTERING_WORLD")
end


-- Called when the addon is disabled
function DRT:OnDisable()
end


function DRT:OnProfileChanged()
	for name, module in self:IterateModules() do
        if type(module.OnProfileChanged) == "function" then
            module:OnProfileChanged()
        else
            return
        end
    end
end


function DRT:CheckVersion()
	local currentVersion = C_AddOns.GetAddOnMetadata("DiminishingReturnsTracker", "Version")
	local storedVersion = self.db.global.version

	StaticPopupDialogs["DRT_CHANGELOG"] = {
		text = "",
		button1 = "OK",
		timeout = 0,
		whileDead = true,
		hideOnEscape = false,
	}

    if not storedVersion or storedVersion ~= currentVersion then
        -- Get changelog from changelog table
        local changelog = DRT_CHANGELOGS[currentVersion]

		if changelog then
			-- Inject text dynamically
			StaticPopupDialogs["DRT_CHANGELOG"].text = "Diminishing Returns Tracker (DRT)" .. "\n\n" .. "|cff00ff00" .. "New Version " .. currentVersion .. "|r" .. "\n\n" .. changelog
			StaticPopup_Show("DRT_CHANGELOG")
		end

        -- Save the new version to the database
        self.db.global.version = currentVersion
    end
end


-- Opens the configuration window for the addon when the slash command is used
function DRT:OpenOptions()
    LibStub("AceConfigDialog-3.0"):Open("DRT")
end


-- Execute the test function of every enabled module
function DRT:TestModules()
	if not DRT.testing then
		DRT.testing = true
	else
		DRT.testing = false
	end

    for name, module in self:IterateModules() do
		if self.db.profile.modules[name].enabled then
			if DRT.testing then
				if module.StartTest or type(module.StartTest) == "function" then
					module:StartTest()
				else
					print("ERROR: " .. name .. " Module is missing the StartTest() function!")
				end
			else
				if module.StopTest or type(module.StopTest) == "function" then
					module:StopTest()
				else
					print("ERROR: " .. name .. " Module is missing the StopTest() function!")
				end
			end
		end
    end
end


function DRT:PLAYER_ENTERING_WORLD()
    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType == "arena" then
		DRT.testing = false
		for name, module in self:IterateModules() do
		if self.db.profile.modules[name].enabled then
				if module.StopTest or type(module.StopTest) == "function" then
					module:StopTest()
				end
			end
		end
    end
end


function DRT:FrameSelector(onSelectCallback)
	local frameChooserFrame = DRT.frameChooserFrame
	local frameChooserBox = DRT.frameChooserBox
	local cursorCrosshairs = DRT.cursorCrosshairs
	local focusName

	local function StopFrameChooser()
		if frameChooserFrame then
			frameChooserFrame:SetScript("OnUpdate", nil)
			frameChooserFrame:Hide()
		end
		if frameChooserBox then
			frameChooserBox:Hide()
		end
		if cursorCrosshairs then
			cursorCrosshairs:Hide()
		end
	end

	-- Create the main frame chooser frame
	if not frameChooserFrame then
		frameChooserFrame = CreateFrame("Frame", "DRT_FrameChooserFrame", UIParent)
		DRT.frameChooserFrame = frameChooserFrame
	end

	-- Create the green selection box
	if not frameChooserBox then
		frameChooserBox = CreateFrame("Frame", "DRT_FrameChooserBox", frameChooserFrame, "BackdropTemplate")
		frameChooserBox:SetFrameStrata("TOOLTIP")
		frameChooserBox:SetBackdrop({
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 12,
			insets = { left = 0, right = 0, top = 0, bottom = 0 }
		})
		frameChooserBox:SetBackdropBorderColor(0, 1, 0)
		frameChooserBox:Hide()
		DRT.frameChooserBox = frameChooserBox
	end

	-- Create the cursor crosshairs
	if not cursorCrosshairs then
		cursorCrosshairs = CreateFrame("Frame", "DRT_cursorCrosshairs", UIParent)
		cursorCrosshairs:SetSize(32, 32)
		cursorCrosshairs:SetFrameStrata("TOOLTIP")
		local tex = cursorCrosshairs:CreateTexture(nil, "OVERLAY")
		tex:SetAllPoints()
		tex:SetTexture("Interface\\CURSOR\\Crosshairs")
		DRT.cursorCrosshairs = cursorCrosshairs
	end

	frameChooserFrame:Show()
	cursorCrosshairs:Show()

	frameChooserFrame:SetScript("OnUpdate", function()
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		cursorCrosshairs:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)

		if IsMouseButtonDown("RightButton") then
			StopFrameChooser()
		elseif IsMouseButtonDown("LeftButton") and focusName then
			StopFrameChooser()
			if onSelectCallback then
				onSelectCallback(focusName)
			end
		else
			local focus
			local foci = GetMouseFoci()

			if foci and #foci > 0 then
				focus = foci[1]
				focusName = focus:GetName()
			else
				focusName = nil
			end

			if focus and focusName then
				frameChooserBox:ClearAllPoints()
				frameChooserBox:SetPoint("BOTTOMLEFT", focus, "BOTTOMLEFT", -4, -4)
				frameChooserBox:SetPoint("TOPRIGHT", focus, "TOPRIGHT", 4, 4)
				frameChooserBox:Show()
			else
				frameChooserBox:Hide()
			end
		end
	end)
end
