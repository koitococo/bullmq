--[[
  Function to get queue qualified name form jobKey.
]]

local function getQueueQualifiedName(jobKey, jobId)
  return string.sub(jobKey, 0, #jobKey - #jobId - 1)
end
