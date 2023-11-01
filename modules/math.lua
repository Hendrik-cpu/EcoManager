-- function round(num, numDecimalPlaces)
-- 	local mult = 10^(numDecimalPlaces or 0)
-- 	return math.floor(num * mult + 0.5) / mult
-- end
function round(num, idp)
    if(idp > 0) then
        return string.format("%."..idp.. "f", num)
    else
        return string.format("%d", num)
    end
end
-- function round(num, idp)
-- 	if not idp then
-- 		return tonumber(string.format("%." .. (idp or 0) .. "f", num))
-- 	else
--   		local mult = 10^(idp or 0)
-- 		return math.floor(num * mult + 0.5) / mult
--   	end
-- end
-- function round(num, idp)
--     return tonumber(string.format("%." .. (idp or 0) .. "f", num))
--   end