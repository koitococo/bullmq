--[[
  Adds a parent job to the queue by doing the following:
    - Increases the job counter if needed.
    - Creates a new job key with the job data.
    - adds the job to the waiting-children zset

    Input:
      KEYS[1]  'meta'
      KEYS[2]  'id'
      KEYS[3]  'wait'
      KEYS[4]  'paused'
      KEYS[5]  'prioritized'
      KEYS[6]  'delayed'
      KEYS[7]  'active'
      KEYS[8]  'completed'
      KEYS[9]  events stream key
      KEYS[10] 'marker'
      KEYS[11] 'pc' priority counter

      ARGV[1] msgpacked arguments array
            [1]  key prefix,
            [2]  custom id (will not generate one automatically)
            [3]  name
            [4]  timestamp
            [5]  parentKey?
            [6]  waitChildrenKey key.
            [7]  parent dependencies key.
            [8]  parent? {id, queueKey}
            [9]  repeat job key
            [10] deduplication key
            [11] chain key

      ARGV[2] Json stringified job data
      ARGV[3] msgpacked options

      Output:
        jobId  - OK
        -5     - Missing parent key
]]
local metaKey = KEYS[1]
local idKey = KEYS[2]
local waitKey = KEYS[3]
local pausedKey = KEYS[4]
local prioritizedKey = KEYS[5]
local delayedKey = KEYS[6]
local activeKey = KEYS[7]
local completedKey = KEYS[8]
local eventsKey = KEYS[9]
local markerKey = KEYS[10]
local priorityCounterKey = KEYS[11]

local jobId
local jobIdKey
local rcall = redis.call

local args = cmsgpack.unpack(ARGV[1])

local data = ARGV[2]
local opts = cmsgpack.unpack(ARGV[3])

local parentKey = args[5]
local parent = args[8]
local repeatJobKey = args[9]
local deduplicationKey = args[10]
local chainKey = args[11]
local parentData

local function addJobInWaitingChildren(waitingChildrenKey, jobId, timestamp, eventsKey, maxEvents)
  rcall("ZADD", waitingChildrenKey, timestamp, jobId)
  rcall("XADD", eventsKey, "MAXLEN", "~", maxEvents, "*", "event",
        "waiting-children", "jobId", jobId)
end

-- Includes
--- @include "includes/addDelayedJob"
--- @include "includes/addJobInTargetList"
--- @include "includes/addJobWithPriority"
--- @include "includes/deduplicateJob"
--- @include "includes/getOrSetMaxEvents"
--- @include "includes/getTargetQueueList"
--- @include "includes/handleDuplicatedJob"
--- @include "includes/isQueuePausedOrMaxed"
--- @include "includes/storeJob"
--- @include "includes/updateParentInLastJobInChain"
--- @include "includes/upsertChainKeyIfNeeded"

if parentKey ~= nil then
    if rcall("EXISTS", parentKey) ~= 1 then return -5 end

    parentData = cjson.encode(parent)
end

local jobCounter = rcall("INCR", idKey)

local maxEvents = getOrSetMaxEvents(metaKey)

local parentDependenciesKey = args[7]
local timestamp = args[4]
if args[2] == "" then
    jobId = jobCounter
    jobIdKey = args[1] .. jobId
else
    jobId = args[2]
    jobIdKey = args[1] .. jobId
    if rcall("EXISTS", jobIdKey) == 1 then
        return handleDuplicatedJob(jobIdKey, jobId, parentKey, parent,
            parentData, parentDependenciesKey, completedKey, eventsKey,
            maxEvents, timestamp)
    end
end

local deduplicationJobId = deduplicateJob(opts['de'], jobId, delayedKey,
  deduplicationKey, eventsKey, maxEvents, args[1])
if deduplicationJobId then
  return deduplicationJobId
end

-- Store the job.
local delay, priority = storeJob(eventsKey, jobIdKey, jobId, args[3], ARGV[2], opts, timestamp,
      parentKey, parentData, repeatJobKey, chainKey)

if chainKey then
  local lastJobKeyInChain = upsertChainKeyIfNeeded(chainKey, jobIdKey)

  if lastJobKeyInChain then
    updateParentInLastJobInChain(lastJobKeyInChain, jobIdKey, jobId)

    local waitingChildrenKey = args[6]

    addJobInWaitingChildren(waitingChildrenKey, jobId, timestamp, eventsKey, maxEvents)
  else
    if delay ~= 0 then
      addDelayedJob(jobId, delayedKey, eventsKey, timestamp, maxEvents, markerKey, delay)
    else
      if priority ~= 0 then
        local isPausedOrMaxed = isQueuePausedOrMaxed(metaKey, activeKey)
        addJobWithPriority(markerKey, prioritizedKey, priority, jobId, priorityCounterKey, isPausedOrMaxed)
      else
        local target, isPausedOrMaxed = getTargetQueueList(metaKey, activeKey, waitKey, pausedKey)

        -- LIFO or FIFO
        local pushCmd = opts['lifo'] and 'RPUSH' or 'LPUSH'
        addJobInTargetList(target, markerKey, pushCmd, isPausedOrMaxed, jobId)
      end

      -- Emit waiting event
      rcall("XADD", eventsKey, "MAXLEN", "~", maxEvents, "*", "event", "waiting",
            "jobId", jobId)
    end
  end
else
  local waitingChildrenKey = args[6]
  addJobInWaitingChildren(waitingChildrenKey, jobId, timestamp, eventsKey, maxEvents)
end

-- Check if this job is a child of another job, if so add it to the parents dependencies
if parentDependenciesKey ~= nil then
    rcall("SADD", parentDependenciesKey, jobIdKey)
end

return jobId .. "" -- convert to string
