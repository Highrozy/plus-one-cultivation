--!strict
-- Format: turns big numbers into short text (1234 -> "1.23K").

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qn", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.Number(value: number): string
	if value < 1000 then
		if value == math.floor(value) then
			return tostring(value)
		end
		return string.format("%.1f", value)
	end
	local index = math.min(math.floor(math.log10(value) / 3), #SUFFIXES - 1)
	local scaled = value / 10 ^ (index * 3)
	local text = if scaled >= 100 then string.format("%.0f", scaled) else string.format("%.3g", scaled)
	return text .. SUFFIXES[index + 1]
end

return Format
