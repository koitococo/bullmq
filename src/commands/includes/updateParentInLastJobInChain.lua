--[[
  Function to store a job
]]

-- Includes
--- @include "getQueueQualifiedName"

local function updateParentInLastJobInChain(lastJobKeyInChain, parentKey, parentId)
  local rawParentData = rcall("HGET", lastJobKeyInChain, "parent")

  local parentQueueQualifiedName = getQueueQualifiedName(parentKey, parentId .. "")
  
  local lastJobParentData
  if rawParentData then
    lastJobParentData = cjson.decode(rawParentData)
  else
    lastJobParentData = {}
  end
  
  lastJobParentData["id"] = parentId
  lastJobParentData["queueKey"] = parentQueueQualifiedName
  
  local lastJobNewParentData = cjson.encode(lastJobParentData)
  rcall("HMSET", lastJobKeyInChain, "parent", lastJobNewParentData,
        "parentKey", parentKey)
end
