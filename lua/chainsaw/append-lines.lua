local M = {}
--------------------------------------------------------------------------------

---Most reliable way seems to be to get the indent of the line *after* the
---cursor. If that line is a blank, we look further down. If the next line has
---less indentation than the current line, it is the end of an indentation and
---we return the current indentation instead.
---@return string -- the indent as string
local function determineIndent()
	local function getLine(lnum) return vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1] end
	local function isBlank(lnum) return getLine(lnum):find("^%s*$") ~= nil end

	local startLnum = vim.api.nvim_win_get_cursor(0)[1]
	local lastLnumInBuf = vim.api.nvim_buf_line_count(0)
	local currentIndent = getLine(startLnum):match("^%s*")

	if startLnum == lastLnumInBuf then return currentIndent end
	local lnum = startLnum
	repeat
		lnum = lnum + 1
	until lnum >= lastLnumInBuf or not isBlank(lnum)

	local nextLineIndent = getLine(lnum):match("^%s*")
	local lineIsEndOfIndentation = #nextLineIndent < #currentIndent
	if lineIsEndOfIndentation then return currentIndent end
	return nextLineIndent
end

---@param logType string
---@return string[]|false -- returns false if not configured or invalid
---@nodiscard
local function getTemplateStr(logType)
	local notify = require("chainsaw.utils").notify

	local ft = vim.bo.filetype
	if vim.api.nvim_buf_get_name(0):find("nvim.*%.lua$") then ft = "nvim_lua" end

	local logStatements = require("chainsaw.config").config.logStatements
	local templateStr = logStatements[logType][ft]
	if type(templateStr) == "string" then templateStr = { templateStr } end

	-- GUARD unconfigured filetype
	if not templateStr then
		notify(("There is no configuration for %q in %q."):format(logType, ft), "warn")
		return false
	end

	-- GUARD statement has line breaks
	local hasLineBreaks = vim.iter(templateStr):any(function(line) return line:find("[\r\n]") end)
	if hasLineBreaks then
		local msg = table.concat({
			("%q for %q has line breaks."):format(logType, ft),
			"The nvim-api does not accept line breaks in string when appending text.",
			"Use a list of strings instead, each string representing one line.",
		}, "\n")
		notify(msg, "warn")
		return false
	end

	return templateStr
end

--------------------------------------------------------------------------------

---@param logType? string
---@param specialPlaceholder? string
---@return boolean success
function M.append(logType, specialPlaceholder)
	if not logType then logType = vim.b.chainsawLastLogtype end
	local logLines = getTemplateStr(logType)
	if not logLines then return false end

	local config = require("chainsaw.config").config

	local logtypePlaceholders = config.logStatements[logType]._placeholders
	local placeholders = vim.iter(logtypePlaceholders)
		:map(function(p)
			if p == "marker" then return config.marker end
			if p == "var" then return require("chainsaw.var-detect").getVar() end
			if p == "special" then return specialPlaceholder end
			assert(false, "Unknown placeholder: " .. p)
		end)
		:totable()

	local ln = vim.api.nvim_win_get_cursor(0)[1]

	-- Prevent nested quotes from making statements invalid.
	-- example: `var["field"]` would make `console.log("…")` invalid when inserted.
	local quotesInVar
	for _, var in pairs(placeholders) do
		quotesInVar = var:match("'") or var:match('"')
		if quotesInVar then break end
	end
	if quotesInVar then
		local repl = quotesInVar == "'" and '"' or "'"
		logLines = vim.tbl_map(function(line) return line:gsub(quotesInVar, repl) end, logLines)
	end

	-- INFO we cannot use `:normal ==` to auto-indent the lines, because it using
	-- a normal command messes up dot-repeatability. Thus, we have to determine
	-- the indent manually ourselves.
	local indent = determineIndent()

	-- insert all lines
	local toInsert
	for _, line in pairs(logLines) do
		toInsert = indent .. line:format(unpack(placeholders))
		vim.api.nvim_buf_set_lines(0, ln, ln, true, { toInsert })
		ln = ln + 1
	end

	-- move cursor to first non-whitespace character of the last inserted line
	local col = toInsert:find("%S")
	vim.api.nvim_win_set_cursor(0, { ln, col - 1 })

	return true
end

--------------------------------------------------------------------------------
return M
