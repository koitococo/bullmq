--[[
  Function to remove job.
]]

-- Includes
--- @include "removeChainKeyIfNeeded"
--- @include "removeDeduplicationKeyIfNeededOnRemoval"
--- @include "removeJobKeys"
--- @include "removeParentDependencyKey"

local function removeJob(jobId, hard, baseKey, shouldRemoveDedupAndChainKey)
  local jobKey = baseKey .. jobId
  removeParentDependencyKey(jobKey, hard, nil, baseKey)
  if shouldRemoveDedupAndChainKey then
    local jobAttributes = rcall("HMGET", jobKey, "deid", "chk")
    removeDeduplicationKeyIfNeededOnRemoval(baseKey, jobId, jobAttributes[1])
    removeChainKeyIfNeeded(jobAttributes[2], jobKey)
  end
  removeJobKeys(jobKey)
end
