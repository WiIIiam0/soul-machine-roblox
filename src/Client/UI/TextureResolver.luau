--!strict
-- TextureResolver.luau: Resolves and caches icon asset IDs from ReplicatedStorage / Workspace

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
	return nil
end

function TextureResolver.Resolve(iconFile: string?, rawIcon: string?): string?
	if not iconFile or iconFile == "" then
		if rawIcon and rawIcon ~= "" and not string.find(rawIcon, "rbxassetid://10709791") then
			return rawIcon
		end
		return nil
	end

	local cleanName = string.gsub(iconFile, "%.png$", "")
	local cleanLower = string.lower(cleanName)

	if textureCache[cleanLower] then
		return textureCache[cleanLower]
	end

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
					return tex
				end
			end
		end
	end

	-- Pass 1: Exact name match across all descendants
	for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
		local dLower = string.lower(string.gsub(desc.Name, "%.png$", ""))
		if dLower == cleanLower then
			local tex = extractTextureString(desc)
			if tex then
				textureCache[cleanLower] = tex
				return tex
			end
		end
	end

	for _, desc in ipairs(Workspace:GetDescendants()) do
		local dLower = string.lower(string.gsub(desc.Name, "%.png$", ""))
		if dLower == cleanLower then
			local tex = extractTextureString(desc)
			if tex then
				textureCache[cleanLower] = tex
				return tex
			end
		end
	end

	-- Pass 2: Exact trailing sprite index match (e.g. "05" -> 5 vs "50" -> 50, avoiding substring clashes)
	if spriteNum then
		for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
			local dLower = string.lower(string.gsub(desc.Name, "%.png$", ""))
			local dNum = tonumber(string.match(dLower, "(%d+)$"))
			if dNum == spriteNum then
				if string.find(dLower, "skill", 1, true) or string.find(dLower, "csf", 1, true) or dLower == tostring(spriteNum) or dLower == string.format("%02d", spriteNum) then
					local tex = extractTextureString(desc)
					if tex then
						textureCache[cleanLower] = tex
						return tex
					end
				end
			end
		end

		for _, desc in ipairs(Workspace:GetDescendants()) do
			local dLower = string.lower(string.gsub(desc.Name, "%.png$", ""))
			local dNum = tonumber(string.match(dLower, "(%d+)$"))
			if dNum == spriteNum then
				if string.find(dLower, "skill", 1, true) or string.find(dLower, "csf", 1, true) or dLower == tostring(spriteNum) or dLower == string.format("%02d", spriteNum) then
					local tex = extractTextureString(desc)
					if tex then
						textureCache[cleanLower] = tex
						return tex
					end
				end
			end
		end
	end

	if rawIcon and rawIcon ~= "" and not string.find(rawIcon, "rbxassetid://10709791") then
		return rawIcon
	end

	return nil
end

return TextureResolver
