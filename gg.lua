local Players = game:GetService("Players")
local httpService = game:GetService("HttpService")

local SaveManager = {} do
	SaveManager.Folder = "FluentSettings"
	SaveManager.Ignore = {}
	SaveManager.AutoSaveEnabled = true
	SaveManager.AutoSaveInterval = 1 -- seconds
	SaveManager.AutoSaveConnection = nil
	SaveManager.CurrentConfig = nil
	SaveManager.UsePlayerName = true -- New: Use player name in config files
	SaveManager.PlayerName = Players.LocalPlayer.Name -- Get current player name
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object) 
				return { type = "Toggle", idx = idx, value = object.Value } 
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = "Slider", idx = idx, value = tostring(object.Value) }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = "Dropdown", idx = idx, value = object.Value, multi = object.Multi }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Colorpicker = {
			Save = function(idx, object)
				return { type = "Colorpicker", idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
				end
			end,
		},
		Keybind = {
			Save = function(idx, object)
				return { type = "Keybind", idx = idx, mode = object.Mode, key = object.Value }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValue(data.key, data.mode)
				end
			end,
		},
		Input = {
			Save = function(idx, object)
				return { type = "Input", idx = idx, text = object.Value }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] and type(data.text) == "string" then
					SaveManager.Options[idx]:SetValue(data.text)
				end
			end,
		},
	}

	-- New: Get config file name with player name
	function SaveManager:GetConfigFileName(name)
		if self.UsePlayerName then
			return self.PlayerName .. "_" .. name
		else
			return name
		end
	end

	-- New: Get config display name (remove player prefix)
	function SaveManager:GetConfigDisplayName(fileName)
		if self.UsePlayerName then
			local prefix = self.PlayerName .. "_"
			if fileName:sub(1, #prefix) == prefix then
				return fileName:sub(#prefix + 1)
			end
		end
		return fileName
	end

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder
		self:BuildFolderTree()
	end

	-- New: Enable/disable player name usage
	function SaveManager:SetUsePlayerName(enabled)
		self.UsePlayerName = enabled
	end

	function SaveManager:EnableAutoSave(configName, interval)
		self.AutoSaveEnabled = true
		self.CurrentConfig = configName or "autosave"
		self.AutoSaveInterval = interval or 30
		
		if self.AutoSaveConnection then
			self.AutoSaveConnection:Disconnect()
		end
		
		self.AutoSaveConnection = task.spawn(function()
			while self.AutoSaveEnabled do
				task.wait(self.AutoSaveInterval)
				if self.AutoSaveEnabled and self.CurrentConfig then
					local success, err = self:Save(self.CurrentConfig)
					if success then
						print("[SaveManager] Auto saved config: " .. self.CurrentConfig)
					else
						warn("[SaveManager] Auto save failed: " .. err)
					end
				end
			end
		end)
		
		-- Save auto save settings
		self:SaveAutoSaveSettings()
	end

	function SaveManager:DisableAutoSave()
		self.AutoSaveEnabled = false
		if self.AutoSaveConnection then
			self.AutoSaveConnection:Disconnect()
			self.AutoSaveConnection = nil
		end
		
		-- Save auto save settings
		self:SaveAutoSaveSettings()
	end

	function SaveManager:SaveAutoSaveSettings()
		local autoSaveData = {
			enabled = self.AutoSaveEnabled,
			config = self.CurrentConfig,
			interval = self.AutoSaveInterval,
			usePlayerName = self.UsePlayerName, -- New: Save player name setting
			playerName = self.PlayerName -- New: Save current player name
		}
		
		local success, encoded = pcall(httpService.JSONEncode, httpService, autoSaveData)
		if success then
			local fileName = self:GetConfigFileName("autosave_settings")
			writefile(self.Folder .. "/settings/" .. fileName .. ".json", encoded)
		end
	end

	function SaveManager:LoadAutoSaveSettings()
		local fileName = self:GetConfigFileName("autosave_settings")
		local file = self.Folder .. "/settings/" .. fileName .. ".json"
		
		-- Try to load with player name first, then fallback to old format
		if not isfile(file) then
			file = self.Folder .. "/settings/autosave_settings.json"
		end
		
		if isfile(file) then
			local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
			if success and decoded then
				self.AutoSaveEnabled = decoded.enabled or true
				self.CurrentConfig = decoded.config or "autosave"
				self.AutoSaveInterval = decoded.interval or 1
				
				-- New: Load player name settings
				if decoded.usePlayerName ~= nil then
					self.UsePlayerName = decoded.usePlayerName
				end
				if decoded.playerName then
					self.PlayerName = decoded.playerName
				end
				
				if self.AutoSaveEnabled then
					self:EnableAutoSave(self.CurrentConfig, self.AutoSaveInterval)
				end
			end
		else
			-- Default values if no settings file exists
			self.AutoSaveEnabled = true
			self.CurrentConfig = "autosave"
			self.AutoSaveInterval = 1
			self:EnableAutoSave(self.CurrentConfig, self.AutoSaveInterval)
		end
	end

	function SaveManager:Save(name)
		if (not name) then
			return false, "no config file is selected"
		end

		local fileName = self:GetConfigFileName(name)
		local fullPath = self.Folder .. "/settings/" .. fileName .. ".json"

		local data = {
			objects = {},
			metadata = { -- New: Add metadata
				playerName = self.PlayerName,
				createdAt = os.date("%Y-%m-%d %H:%M:%S"),
				configName = name
			}
		}

		for idx, option in next, SaveManager.Options do
			if not self.Parser[option.Type] then continue end
			if self.Ignore[idx] then continue end

			table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
		end	

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, "failed to encode data"
		end

		-- New: Create backup of existing config
		if isfile(fullPath) then
			local backupPath = self.Folder .. "/settings/backups/" .. fileName .. "_backup_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
			local success, content = pcall(readfile, fullPath)
			if success then
				writefile(backupPath, content)
			end
		end

		writefile(fullPath, encoded)
		return true
	end

	function SaveManager:Load(name)
		if (not name) then
			return false, "no config file is selected"
		end
		
		local fileName = self:GetConfigFileName(name)
		local file = self.Folder .. "/settings/" .. fileName .. ".json"
		
		-- Try to load with player name first, then fallback to old format
		if not isfile(file) then
			file = self.Folder .. "/settings/" .. name .. ".json"
		end
		
		if not isfile(file) then 
			return false, "config file not found"
		end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then 
			return false, "failed to decode config file"
		end

		-- New: Check if config belongs to current player
		if decoded.metadata and decoded.metadata.playerName then
			if decoded.metadata.playerName ~= self.PlayerName and self.UsePlayerName then
				local choice = self.Library:Notify({
					Title = "Config Loader",
					Content = "Player Mismatch",
					SubContent = "This config belongs to " .. decoded.metadata.playerName .. ". Load anyway?",
					Duration = 10,
					Actions = {
						Confirm = {
							Name = "Load",
							Callback = function()
								-- Continue loading
							end
						},
						Cancel = {
							Name = "Cancel",
							Callback = function()
								return false, "cancelled by user"
							end
						}
					}
				})
			end
		end

		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				task.spawn(function() 
					self.Parser[option.type].Load(option.idx, option) 
				end)
			end
		end

		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ 
			"InterfaceTheme", "AcrylicToggle", "TransparentToggle", "MenuKeybind"
		})
	end

	function SaveManager:BuildFolderTree()
		local paths = {
			self.Folder,
			self.Folder .. "/settings",
			self.Folder .. "/settings/backups" -- New: Backup folder
		}

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function SaveManager:RefreshConfigList()
		local list = listfiles(self.Folder .. "/settings")
		local out = {}
		
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == ".json" then
				local pos = file:find(".json", 1, true)
				local start = pos

				local char = file:sub(pos, pos)
				while char ~= "/" and char ~= "\\" and char ~= "" do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == "/" or char == "\\" then
					local fileName = file:sub(pos + 1, start - 1)
					if fileName ~= "options" and not fileName:find("autosave_settings") and not fileName:find("_backup_") then
						local displayName = self:GetConfigDisplayName(fileName)
						-- New: Only show configs for current player or global configs
						if not self.UsePlayerName or fileName:find("^" .. self.PlayerName .. "_") or not fileName:find("_") then
							table.insert(out, displayName)
						end
					end
				end
			end
		end
		
		return out
	end

	-- New: Get all configs (including other players)
	function SaveManager:GetAllConfigs()
		local list = listfiles(self.Folder .. "/settings")
		local out = {}
		
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == ".json" then
				local pos = file:find(".json", 1, true)
				local start = pos

				local char = file:sub(pos, pos)
				while char ~= "/" and char ~= "\\" and char ~= "" do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == "/" or char == "\\" then
					local fileName = file:sub(pos + 1, start - 1)
					if fileName ~= "options" and not fileName:find("autosave_settings") and not fileName:find("_backup_") then
						table.insert(out, fileName)
					end
				end
			end
		end
		
		return out
	end

	-- New: Delete config
	function SaveManager:DeleteConfig(name)
		if not name then
			return false, "no config name provided"
		end
		
		local fileName = self:GetConfigFileName(name)
		local file = self.Folder .. "/settings/" .. fileName .. ".json"
		
		if not isfile(file) then
			return false, "config file not found"
		end
		
		-- Create backup before deletion
		local backupPath = self.Folder .. "/settings/backups/" .. fileName .. "_deleted_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
		local success, content = pcall(readfile, file)
		if success then
			writefile(backupPath, content)
		end
		
		delfile(file)
		return true
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
		self.Options = library.Options
	end

	function SaveManager:LoadAutoloadConfig()
		local fileName = self:GetConfigFileName("autoload")
		local file = self.Folder .. "/settings/" .. fileName .. ".txt"
		
		-- Try to load with player name first, then fallback to old format
		if not isfile(file) then
			file = self.Folder .. "/settings/autoload.txt"
		end
		
		if isfile(file) then
			local name = readfile(file)

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = "Failed to load autoload config: " .. err,
					Duration = 7
				})
			end

			self.Library:Notify({
				Title = "Interface",
				Content = "Config loader",
				SubContent = string.format("Auto loaded config %q", name),
				Duration = 7
			})
		end
	end

	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, "Must set SaveManager.Library")

		local section = tab:AddSection("Configuration")

		section:AddInput("SaveManager_ConfigName", { Title = "Config name" })
		section:AddDropdown("SaveManager_ConfigList", { Title = "Config list", Values = self:RefreshConfigList(), AllowNull = true })

		-- New: Player name toggle
		section:AddToggle("SaveManager_UsePlayerName", {
			Title = "Use Player Name",
			Description = "Include player name in config files",
			Default = self.UsePlayerName,
			Callback = function(value)
				self.UsePlayerName = value
				self:SaveAutoSaveSettings()
				-- Refresh config list
				SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			end
		})

		-- Auto Save Toggle
		section:AddToggle("SaveManager_AutoSave", { 
			Title = "Auto Save", 
			Description = "Automatically save config every " .. self.AutoSaveInterval .. " seconds",
			Default = self.AutoSaveEnabled,
			Callback = function(value)
				if value then
					local configName = SaveManager.Options.SaveManager_ConfigList.Value or "autosave"
					self:EnableAutoSave(configName, self.AutoSaveInterval)
					self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "Auto save enabled for config: " .. configName,
						Duration = 5
					})
				else
					self:DisableAutoSave()
					self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "Auto save disabled",
						Duration = 5
					})
				end
			end
		})

		-- Auto Save Interval Slider
		section:AddSlider("SaveManager_AutoSaveInterval", {
			Title = "Auto Save Interval",
			Description = "Time between auto saves (seconds)",
			Default = self.AutoSaveInterval,
			Min = 1,
			Max = 300,
			Rounding = 0,
			Callback = function(value)
				self.AutoSaveInterval = value
				if self.AutoSaveEnabled then
					local currentConfig = self.CurrentConfig
					self:DisableAutoSave()
					self:EnableAutoSave(currentConfig, value)
				end
				if SaveManager.Options.SaveManager_AutoSave then
					SaveManager.Options.SaveManager_AutoSave:SetDesc("Automatically save config every " .. value .. " seconds")
				end
			end
		})

		section:AddButton({
			Title = "Create config",
			Callback = function()
				local name = SaveManager.Options.SaveManager_ConfigName.Value

				if name:gsub(" ", "") == "" then 
					return self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "Invalid config name (empty)",
						Duration = 7
					})
				end

				local success, err = self:Save(name)
				if not success then
					return self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "Failed to save config: " .. err,
						Duration = 7
					})
				end

				self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = string.format("Created config %q for player %s", name, self.PlayerName),
					Duration = 7
				})

				SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
				SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
			end
		})

		section:AddButton({
			Title = "Load config", 
			Callback = function()
				local name = SaveManager.Options.SaveManager_ConfigList.Value

				local success, err = self:Load(name)
				if not success then
					return self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "Failed to load config: " .. err,
						Duration = 7
					})
				end

				if self.AutoSaveEnabled then
					self.CurrentConfig = name
					self:SaveAutoSaveSettings()
				end

				self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = string.format("Loaded config %q", name),
					Duration = 7
				})
			end
		})

		section:AddButton({
			Title = "Overwrite config", 
			Callback = function()
				local name = SaveManager.Options.SaveManager_ConfigList.Value

				local success, err = self:Save(name)
				if not success then
					return self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "Failed to overwrite config: " .. err,
						Duration = 7
					})
				end

				self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = string.format("Overwrote config %q", name),
					Duration = 7
				})
			end
		})

		-- New: Delete config button
		section:AddButton({
			Title = "Delete config",
			Callback = function()
				local name = SaveManager.Options.SaveManager_ConfigList.Value
				if not name then
					return self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "No config selected",
						Duration = 7
					})
				end

				local success, err = self:DeleteConfig(name)
				if not success then
					return self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "Failed to delete config: " .. err,
						Duration = 7
					})
				end

				self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = string.format("Deleted config %q", name),
					Duration = 7
				})

				SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
				SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
			end
		})

		section:AddButton({
			Title = "Refresh list", 
			Callback = function()
				SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
				SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
			end
		})

		local AutoloadButton
		AutoloadButton = section:AddButton({
			Title = "Set as autoload", 
			Description = "Current autoload config: none", 
			Callback = function()
				local name = SaveManager.Options.SaveManager_ConfigList.Value
				local fileName = self:GetConfigFileName("autoload")
				writefile(self.Folder .. "/settings/" .. fileName .. ".txt", name)
				AutoloadButton:SetDesc("Current autoload config: " .. name)
				self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = string.format("Set %q to auto load", name),
					Duration = 7
				})
			end
		})

		-- Check for existing autoload config
		local fileName = self:GetConfigFileName("autoload")
		local file = self.Folder .. "/settings/" .. fileName .. ".txt"
		if not isfile(file) then
			file = self.Folder .. "/settings/autoload.txt"
		end
		
		if isfile(file) then
			local name = readfile(file)
			AutoloadButton:SetDesc("Current autoload config: " .. name)
		end

		SaveManager:SetIgnoreIndexes({ 
			"SaveManager_ConfigList", 
			"SaveManager_ConfigName", 
			"SaveManager_AutoSave", 
			"SaveManager_AutoSaveInterval",
			"SaveManager_UsePlayerName"
		})
	end

	function SaveManager:Initialize()
		self:BuildFolderTree()
		self:LoadAutoSaveSettings()
	end

	SaveManager:Initialize()
end

return SaveManager
