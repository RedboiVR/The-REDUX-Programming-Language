-- REDUX profiler.

local redux_clock = {
    timings = {}
}

local started = false

local started_time = 0

-- Starts the profiler. After this, you can create a phase
-- using 'redux_clock:phase()' to make an initial step, and
-- stop the clock using 'redux_clock:stop()' to stop the clock
-- and return the timings table.
function redux_clock:start()
    if started == false then started = true else return end
    self.timings = {}
    started_time = os.clock()
end

-- create phases.
function redux_clock:phase()
    if started == false then return end   
    local phase = os.clock()
    local time = math.abs(started_time - phase)
    started_time = phase
    self.timings[#self.timings+1] = time
    return time
end

-- stop the clock.
function redux_clock:stop()
    if started == false then return end
    local time = math.abs(started_time - os.clock())
    self.timings[#self.timings+1] = time
    started = false
    return self.timings
end

return redux_clock
