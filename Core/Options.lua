local DRT = LibStub("AceAddon-3.0"):GetAddon("DRT")

-- Defines and registers the addon’s options for use in the Blizzard interface options
function DRT:GetOptions()
	self.options = {
		type = "group",
		name = "Diminishing Returns Tracker (DRT)",
		plugins = {},
		args = {
			test = {
				type = "execute",
				name = "Toggle Test Mode",
				order = 1,
				func = function()
					self:TestModules()
				end,
				disabled = function ()
					local inInstance, instanceType = IsInInstance()
					return inInstance and instanceType == "arena"
				end,
			},
			general = {
				type = "group",
				name = "General",
				desc = "General settings",
				order = 2,
				args = {
					general = {
						type = "group",
						name = "General",
						desc = "General settings",
						inline = true,
						order = 1,
						args = {
							test = {
								type = "execute",
								name = "Restore Defaults",
								order = 1,
								func = function()
									StaticPopupDialogs["DRT_RESTORE_DEFAULTS"] = {
										text = "Are you sure you want to restore defaults?\n\n\n|cffff0000WARNING:|r\n\nAll settings will be permanently lost!\nThis will reload your UI.",
										button1 = "Yes",
										button2 = "No",
										OnAccept = function()
											DRTDB = nil
											ReloadUI()
										end,
										timeout = 0,
										whileDead = true,
										hideOnEscape = false,
									}

									local popup = StaticPopup_Show("DRT_RESTORE_DEFAULTS")
									popup:SetFrameStrata("TOOLTIP")
								end,
							},
						}
					}
				}
			},
		}
	}

	-- Pull in module options if available
	for name, module in self:IterateModules() do
		if module.GetOptions then
			self.options.args[name] = module:GetOptions()
		end
	end

	-- Profiles management tab
	self.options.plugins.profiles = {
		profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	}
	self.options.plugins.profiles.profiles.order = 100

	LibStub("AceConfig-3.0"):RegisterOptionsTable("DRT", self.options)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("DRT", "DRT")
end
