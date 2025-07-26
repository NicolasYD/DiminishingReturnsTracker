-- Create a new addon object using AceAddon-3.0 and include AceConsole-3.0 for chat commands
MyAddon = LibStub("AceAddon-3.0"):NewAddon("MyAddon", "AceConsole-3.0")


-- Called when the addon is first loaded (before it is enabled)
function MyAddon:OnInitialize()
    -- Setup database
    self.db = LibStub("AceDB-3.0"):New("MyAddonDB", {
        profile = {
            modules = {
                ['*'] = {
                    enabled = true,
                },
                Icons = {
                    enabled = false,
                },
            }
        }
    })

    -- Enable/disable modules based on profile settings
    for name, module in self:IterateModules() do
        if self.db.profile.modules[name].enabled then
            module:Enable()
        else
            module:Disable()
        end
    end

    -- Get the addon configuration options
    self:GetOptions()
    print("Core initialized")
end


-- Called when the addon is enabled (e.g., when logging in or reloading UI)
function MyAddon:OnEnable()
    -- Register slash commands to open the configuration panel
    self:RegisterChatCommand("drt", "OpenOptions")
    self:RegisterChatCommand("diminishingreturnstracker", "OpenOptions")
    print("Core enabled")
end


-- Called when the addon is disabled
function MyAddon:OnDisable()
    print("Core disabled")
end


-- Opens the configuration window for the addon when the slash command is used
function MyAddon:OpenOptions()
    LibStub("AceConfigDialog-3.0"):Open("MyAddon")
end
