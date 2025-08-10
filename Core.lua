-- Create a new addon object using AceAddon-3.0 and include AceConsole-3.0 for chat commands
DRT = LibStub("AceAddon-3.0"):NewAddon("DRT", "AceConsole-3.0")


-- Called when the addon is first loaded (before it is enabled)
function DRT:OnInitialize()
    -- Setup database
    self.db = LibStub("AceDB-3.0"):New("DRTDB", {
        profile = {
            modules = {
                ['*'] = {
                    enabled = false,
                },
                Icons = {
                    enabled = true,
                },
            }
        }
    })

    -- Disable modules based on saved profile settings (AceAddon will auto-enable the module at startup, regardless of saved profile settings)
    for name, module in self:IterateModules() do
        local modSettings = self.db.profile.modules[name]
        if modSettings and modSettings.enabled == false then
            self:DisableModule(name)
        end
    end

    -- Get the addon configuration options
    self:GetOptions()
end


-- Called when the addon is enabled (e.g., when logging in or reloading UI)
function DRT:OnEnable()
    -- Register slash commands to open the configuration panel
    self:RegisterChatCommand("drt", "OpenOptions")
    self:RegisterChatCommand("diminishingreturnstracker", "OpenOptions")
end


-- Called when the addon is disabled
function DRT:OnDisable()
end


-- Opens the configuration window for the addon when the slash command is used
function DRT:OpenOptions()
    LibStub("AceConfigDialog-3.0"):Open("DRT")
end


function DRT:TestModules()
    for name, module in self:IterateModules() do
        if type(module.Test) == "function" then
            module:Test()
        else
            return
        end
    end
end


function DRT:FrameSelector(onSelectCallback)
	local frameChooserFrame = DRT.frameChooserFrame
	local frameChooserBox = DRT.frameChooserBox
	local focusName


	local function StopFrameChooser()
		if frameChooserFrame then
			frameChooserFrame:SetScript("OnUpdate", nil)
			frameChooserFrame:Hide()
		end
		if frameChooserBox then
			frameChooserBox:Hide()
		end
	end


	if not frameChooserFrame then
		frameChooserFrame = CreateFrame("Frame", "DRT_FrameChooserFrame", UIParent)
		DRT.frameChooserFrame = frameChooserFrame
	end

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

	frameChooserFrame:Show()

	frameChooserFrame:SetScript("OnUpdate", function()
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
