--[[
  Upsert chainKey with last job key reference and get last job key reference.
]]

local function upsertChainKeyIfNeeded(chainKey, jobKey)
  if chainKey then
    local lastJobKeyInChain = rcall("GET", chainKey)
    rcall("SET", chainKey, jobKey)
    return lastJobKeyInChain
  end
end
