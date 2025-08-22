local DRT = LibStub("AceAddon-3.0"):GetAddon("DRT")
local ACR = LibStub("AceConfigRegistry-3.0")
local NP = DRT:NewModule("Nameplates", "AceEvent-3.0")

local DRList = LibStub("DRList-1.0")


function NP:OnInitialize()

end


function NP:OnEnable()

end


function NP:OnDisable()

end


function NP:OnProfileChanged()

end


function NP:SetupDB()
    self.db = DRT.db:RegisterNamespace("Nameplates", {
        profile = {
            -- Settings here
        }
    })
end


function NP:ResetModule()
    self.db:ResetProfile()
end


function NP:GetOptions()
    if not self.db then
        self:SetupDB()
    end

    local options = {
        type = "group",
        name = "Nameplates",
        childGroups = "tab",
        order = 20,
        args = {
            isEnabled = {
                type = "toggle",
                name = "Enable Module",
                get = function()
                    return DRT.db.profile.modules["Nameplates"].enabled
                end,
                set = function(_, value)
                    DRT.db.profile.modules["Nameplates"].enabled = value
                    if value then
                        DRT:EnableModule("Nameplates")
                    else
                        DRT:DisableModule("Nameplates")
                    end
                end,
                order = 100
            },
            resetButton = {
                type = "execute",
				name = "Reset Module",
                desc = "Restore default settings for the entire module.",
				func = function ()
                    self:ResetModule()
                end,
                disabled = function ()
                    return not self:IsEnabled()
                end,
                order = 200
            },
            separator1 = {
                type = "description",
                name = "",
                width = "full",
                order = 300
            },
        }
    }

    return options
end
