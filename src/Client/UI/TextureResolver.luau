--!strict
-- TextureResolver.luau: Resolves and caches icon asset IDs from ReplicatedStorage / Workspace / PlayerGui

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TextureResolver = {}
local textureCache: { [string]: string } = {}

local function extractTextureString(inst: Instance): string?
	if inst:IsA("Decal") or inst:IsA("Texture") then
		if inst.Texture and inst.Texture ~= "" then
			return inst.Texture
		end
	elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		if inst.Image and inst.Image ~= "" then
			return inst.Image
		end
	elseif inst:IsA("StringValue") then
		if inst.Value and inst.Value ~= "" then
			return inst.Value
		end
	elseif inst:IsA("MeshPart") then
		if inst.TextureID and inst.TextureID ~= "" then
			return inst.TextureID
		end
	end

	-- Also check immediate children for Decals or Textures (e.g. Parts imported by Asset Manager)
	local decalChild = inst:FindFirstChildOfClass("Decal")
	if decalChild and decalChild.Texture and decalChild.Texture ~= "" then
		return decalChild.Texture
	end
	local texChild = inst:FindFirstChildOfClass("Texture")
	if texChild and texChild.Texture and texChild.Texture ~= "" then
		return texChild.Texture
	end
	local imgChild = inst:FindFirstChildOfClass("ImageLabel")
	if imgChild and imgChild.Image and imgChild.Image ~= "" then
		return imgChild.Image
	end
	local strChild = inst:FindFirstChildOfClass("StringValue")
	if strChild and strChild.Value and strChild.Value ~= "" then
		return strChild.Value
	end

	return nil
end

function TextureResolver.Resolve(iconFile: string?, rawIcon: string?): string?
	if not iconFile or iconFile == "" then
		if rawIcon and rawIcon ~= "" and not string.find(rawIcon, "rbxassetid://1070979") then
			return rawIcon
		end
		return nil
	end

	local cleanName = string.gsub(iconFile, "%.png$", "")
	local cleanLower = string.lower(cleanName)

	if textureCache[cleanLower] then
		return textureCache[cleanLower]
	end

	local numMatch = string.match(cleanLower, "%d+_%d+$") or string.match(cleanLower, "%d+$")
	local spriteNum = tonumber(string.match(cleanLower, "(%d+)$"))

	local candidates = {
		ReplicatedStorage:FindFirstChild("Icons"),
		ReplicatedStorage:FindFirstChild("Assets"),
		ReplicatedStorage:FindFirstChild("Images"),
		ReplicatedStorage:FindFirstChild("CustomCreeps"),
		ReplicatedStorage,
		Workspace:FindFirstChild("Icons"),
		Workspace:FindFirstChild("Assets"),
	}

	for _, folder in ipairs(candidates) do
		if folder then
			local found = folder:FindFirstChild(iconFile) or folder:FindFirstChild(cleanName)
			if found then
				local tex = extractTextureString(found)
				if tex then
					textureCache[cleanLower] = tex
					print(string.format("[TextureResolver] ✓ Icon resolved for '%s': %s (direct lookup in %s)", cleanName, tex, found:GetFullName()))
					return tex
				end
			end
		end
	end

	-- Search ReplicatedStorage, Workspace, and PlayerGui
	local searchContainers = { ReplicatedStorage, Workspace }
	local localPlayer = Players.LocalPlayer
	if localPlayer then
		local pGui = localPlayer:FindFirstChild("PlayerGui")
		if pGui then table.insert(searchContainers, pGui) end
	end

	for _, container in ipairs(searchContainers) do
		for _, desc in ipairs(container:GetDescendants()) do
			local dLower = string.lower(string.gsub(desc.Name, "%.png$", ""))
			local isMatch = (dLower == cleanLower)
				or string.find(dLower, cleanLower, 1, true)
				or (numMatch and string.find(dLower, numMatch, 1, true))

			if not isMatch and spriteNum then
				local dNum = tonumber(string.match(dLower, "(%d+)$"))
				if dNum == spriteNum then
					isMatch = string.find(dLower, "skill", 1, true)
						or string.find(dLower, "csf", 1, true)
						or dLower == tostring(spriteNum)
						or dLower == string.format("%02d", spriteNum)
				end
			end

			if isMatch then
				local tex = extractTextureString(desc)
				if tex then
					textureCache[cleanLower] = tex
					print(string.format("[TextureResolver] ✓ Icon resolved for '%s': %s (from %s)", cleanName, tex, desc:GetFullName()))
					return tex
				end
			end
		end
	end

	-- Do NOT fall back to generic Lucide icons if rawIcon is one of them
	if rawIcon and rawIcon ~= "" and not string.find(rawIcon, "rbxassetid://1070979") then
		return rawIcon
	end

	return nil
end

return TextureResolver
