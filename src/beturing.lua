#!/usr/local/bin/lua
--
-- beturing.lua
-- A Befunge-flavoured Turing(-esque) machine
-- Implemented in Lua 5 by Chris Pressey, June 2005
--

--
-- Copyright (c)2005 Cat's Eye Technologies.  All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
--
--   Redistributions of source code must retain the above copyright
--   notice, this list of conditions and the following disclaimer.
--
--   Redistributions in binary form must reproduce the above copyright
--   notice, this list of conditions and the following disclaimer in
--   the documentation and/or other materials provided with the
--   distribution.
--
--   Neither the name of Cat's Eye Technologies nor the names of its
--   contributors may be used to endorse or promote products derived
--   from this software without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
-- ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
-- LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
-- FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
-- COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
-- INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
-- SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
-- STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
-- OF THE POSSIBILITY OF SUCH DAMAGE. 
--
-- $Id: beturing.lua 2 2005-06-06 22:28:23Z catseye $

--[[ Common functions ]]--

local debug_log = print
local usage = function()
    io.stderr:write("Usage: [lua] beturing.lua [-q] [filename.bet]\n")
    os.exit(1)
end

--[[ Object Classes ]]--

--[[-----------]]--
--[[ Playfield ]]--
--[[-----------]]--

--
-- Store an unbounded grid.
--
Playfield = {}
Playfield.new = function(tab)
    tab = tab or {}
    local nw, ne, sw, se = {}, {}, {}, {}  -- quadrant storage
    local min_x, min_y, max_x, max_y       -- limits seen so far
    local method = {}

    --
    -- Private function: pick the appropriate quadrant & translate
    --
    local pick_quadrant = function(x, y)
        if x >  0 and y >  0 then return se, x, y end
        if x >  0 and y <= 0 then return ne, x, 1-y end
        if x <= 0 and y >  0 then return sw, 1-x, y end
        if x <= 0 and y <= 0 then return nw, 1-x, 1-y end
    end

    --
    -- Read the symbol at a given position in the playfield
    --
    method.peek = function(pf, x, y)
        local contents, nx, ny = pick_quadrant(x, y)
        contents[ny] = contents[ny] or {} -- make sure row exists
        local sym = contents[ny][nx] or " "
	return sym
    end

    --
    -- Write a symbol at a given position in the playfield
    --
    method.poke = function(pf, x, y, sym)
        local contents, nx, ny = pick_quadrant(x, y)
        contents[ny] = contents[ny] or {} -- make sure row exists
        contents[ny][nx] = sym
	if not min_x or x < min_x then min_x = x end
	if not max_x or x > max_x then max_x = x end
	if not min_y or y < min_y then min_y = y end
	if not max_y or y > max_y then max_y = y end
    end

    --
    -- Store a string starting at (x, y).
    --
    method.poke_str = function(pf, x, y, str)
	local i
	for i = 1, string.len(str) do
	    pf:poke(x + (i - 1), y, string.sub(str, i, i))
	end
    end

    --
    -- Load the playfield from a file.
    --
    method.load = function(pf, filename, callback)
        local file = io.open(filename)
	local line = file:read("*l")
	local x, y = 0, 0

        while line do
	    if string.find(line, "^%s*%#") then
	        -- comment or directive - not included in playfield.
		local found, len, nx, ny =
		  string.find(line, "^%s*%#%s*%@%(%s*(%-?%d+)%s*%,%s*(%-?%d+)%s*%)")
		if found then
		    x = tonumber(nx)
		    y = tonumber(ny)
		    debug_log("Now loading at " ..
		      "(" .. tostring(x) .. "," .. tostring(y) .. ")")
		else
		    callback(line)
		end
	    else
	        pf:poke_str(x, y, line)
		y = y + 1
	    end
            line = file:read("*l")
	end
	file:close()
    end

    --
    -- Return a string representing the playfield.
    --
    method.render = function(pf)
        local y = min_y
	local s = "--- (" .. tostring(min_x) .. "," .. tostring(min_y) .. ")-"
	s = s .. "(" .. tostring(max_x) .. "," .. tostring(max_y) .. ") ---\n"
        while y <= max_y do
	    local x = min_x
	    while x <= max_x do
	        s = s .. pf:peek(x, y)
	        x = x + 1
	    end
	    s = s .. "\n"
            y = y + 1
	end

	return s
    end

    return method
end

--[[------]]--
--[[ Head ]]--
--[[------]]--

--
-- Represent a readable(/writeable) location within a playfield.
--
Head = {}
Head.new = function(tab)
    tab = tab or {}

    local pf = assert(tab.playfield)
    local x = tab.x or 0
    local y = tab.y or 0

    local method = {}

    method.read = function(hd, sym)
        return pf:peek(x, y)
    end

    method.write = function(hd, sym)
        pf:poke(x, y, sym)
    end

    --
    -- look for this symbol         -> 13 <- on match, write this symbol
    -- on match, move head this way -> 24 <- choose next state on this
    --
    method.read_code = function(hd)
        local seek_sym, repl_sym, move_cmd, state_cmd

	debug_log("rd cd")
	seek_sym = hd:read()
	hd:move(">")
	repl_sym = hd:read()
	hd:move("v")
	state_cmd = hd:read()
	hd:move("<")
	move_cmd = hd:read()
	hd:move("^")
	debug_log("cd rd")
	
	return seek_sym, repl_sym, move_cmd, state_cmd
    end

    method.move = function(hd, sym)
        if sym == "^" then
            y = y - 1
        elseif sym == "v" then
            y = y + 1
        elseif sym == "<" then
            x = x - 1
        elseif sym == ">" then
            x = x + 1
        elseif sym ~= "." then
            error("Illegal movement symbol '" .. sym .. "'")
        end
    end

    return method
end

--[[---------]]--
--[[ Machine ]]--
--[[---------]]--

--
-- Perform the mechanics of the machine.
--
Machine = {}
Machine.new = function(tab)
    tab = tab or {}

    local pf = tab.playfield or Playfield.new()
    local data_head = Head.new{
        playfield = pf,
        x = tab.data_head_x or 0,
	y = tab.data_head_y or 0
    }
    local code_head = Head.new{
        playfield = pf,
        x = tab.code_head_x or 0,
	y = tab.code_head_y or 0
    }

    local method = {}

    --
    -- Private function: provide interpretation of the state-
    -- transition operator.
    --
    local interpret = function(sym, sense)
        if sense then
	    -- Positive interpretation.
	    if sym == "/" then
		return ">"
	    else
	        return sym
	    end
	else
	    -- Negative interpretation.
	    if sym == "/" then
		return "v"
	    else
	        return state_cmd
	    end
	end
    end

    --
    -- Advance the machine's configuration one step.
    --
    method.step = function(m)
        local this_sym = data_head:read()
        local seek_sym, repl_sym, move_cmd, state_cmd = code_head:read_code()
	local code_move

	debug_log("Symbol under data head is '" .. this_sym .. "'")
	debug_log("Instruction under code head is:")
	debug_log("(" .. seek_sym .. repl_sym .. ")")
	debug_log("(" .. move_cmd .. state_cmd .. ")")

	--
	-- Main processing logic
	--
	if move_cmd == "*" then
	    --
	    -- Special - match anything, do no rewriting or data head
	    -- moving, and advance the state using positive intrepretation.
	    --
	    debug_log("-> Wildcard!")
	    code_move = interpret(state_cmd, true)
	elseif seek_sym == this_sym then
	    --
	    -- The seek symbol matches the symbol under the data head.
	    -- Rewrite it, move the head, and advance the state
	    -- using the positive interpretation.
	    --
	    debug_log("-> Symbol matches, replacing with '" .. repl_sym .. "'")
	    debug_log("-> moving data head '" .. move_cmd .. "'")
	    data_head:write(repl_sym)
	    data_head:move(move_cmd)
	    code_move = interpret(state_cmd, true)
	else
	    --
	    -- No match - just advance the state, using negative interp.
	    --
	    debug_log("-> No match.")
	    code_move = interpret(state_cmd, false)
	end

	--
	-- Do the actual state advancement here.
	--
	if code_move == "@" then
	    debug_log("-> Machine halted!")
	    return false
	else
            debug_log("-> moving code head '" .. code_move .. "'")
            code_head:move(code_move)
	    code_head:move(code_move)
	    return true
	end
    end

    --
    -- Run the machine 'til it halts.
    --
    method.run = function(m)
	local done = false
	while not done do
	    debug_log(pf:render())
	    done = not m:step()
	end
    end

    return method
end

--[[ INIT ]]--

local pf = Playfield.new()

--[[ command-line arguments ]]--

local argno = 1
while arg[argno] and string.find(arg[argno], "^%-") do
    if arg[argno] == "-q" then
        debug_log = function() end
    else
        usage()
    end
    argno = argno + 1
end

if not arg[argno] then
    usage()
end

--[[ load playfield ]]--

local data_head_x, data_head_y, code_head_x, code_head_y = 0, 0, 0, 0
local directive_processor = function(directive)
    local found, len, x, y

    found, len, x, y = 
      string.find(directive, "^%s*%#%s*D%(%s*(%-?%d+)%s*%,%s*(%-?%d+)%s*%)")
    if found then
        data_head_x = tonumber(x)
	data_head_y = tonumber(y)
	debug_log("Data head initially located at " ..
          "(" .. tostring(data_head_x) .. "," .. tostring(data_head_y) .. ")")
	return true
    end
    found, len, x, y = 
      string.find(directive, "^%s*%#%s*C%(%s*(%-?%d+)%s*%,%s*(%-?%d+)%s*%)")
    if found then
        code_head_x = tonumber(x)
	code_head_y = tonumber(y)
	debug_log("Code head initially located at " ..
          "(" .. tostring(code_head_x) .. "," .. tostring(code_head_y) .. ")")
	return true
    end

    return false
end

pf:load(arg[argno], directive_processor)

--[[ MAIN ]]--

local m = Machine.new{
    playfield = pf,
    data_head_x = data_head_x,
    data_head_y = data_head_y,
    code_head_x = code_head_x,
    code_head_y = code_head_y
}

m:run()
