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
