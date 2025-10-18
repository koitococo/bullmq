--[[
  Function to remove chain key if needed.
]]

local function removeChainKeyIfNeeded(chainKey, jobKey)
  if chainKey then
    local lastJobKeyInChain = rcall("GET", chainKey)

    if lastJobKeyInChain == jobKey then
      rcall("DEL", chainKey)
    end
  end
end
