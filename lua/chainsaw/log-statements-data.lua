---@alias logStatementData table<string, table<string, string|string[]>>

--------------------------------------------------------------------------------
-- INFO
-- 1. The strings may not include linebreaks. If you want to use multi-line log
-- statements, use a list of strings instead, each string representing one line.
-- 2. All `%s` are replaced with the respective `_placeholders`.
--------------------------------------------------------------------------------

---@type logStatementData
local M = {
	variableLog = {
		_placeholders = { "marker", "var", "var" },
		lua = 'print("%s %s: " .. tostring(%s))',
		nvim_lua = 'vim.notify("%s %s: " .. tostring(%s))', -- not using `print` due to https://github.com/folke/noice.nvim/issues/556
		python = 'print(f"%s {%s = }")',
		javascript = 'console.log("%s %s:", %s);',
		sh = 'echo "%s %s: $%s" >&2',
		applescript = 'log "%s %s:" & %s',
		css = "outline: 2px solid red !important; /* %s */",
		rust = 'println!("{} {}: {:?}", "%s", "%s", %s);',
		ruby = 'puts "%s %s: #{%s}"',
	},
	objectLog = {
		_placeholders = { "marker", "var", "var" },
		nvim_lua = 'vim.notify("%s %s: " .. vim.inspect(%s))', -- no built-in method in normal lua
		javascript = 'console.log("%s %s:", JSON.stringify(%s))',
		ruby = 'puts "%s %s: #{%s.inspect}"',
	},
	assertLog = {
		_placeholders = { "var", "marker", "var" },
		lua = 'assert(%s, "%s %s")',
		python = 'assert %s, "%s %s"',
		typescript = 'console.assert(%s, "%s %s");',
	},
	typeLog = {
		_placeholders = { "marker", "var", "var" },
		lua = 'print("%s %s: type is " .. type(%s))',
		nvim_lua = 'vim.notify("%s %s: type is " .. type(%s))',
		javascript = 'console.log("%s %s: type is " + typeof %s)',
		python = 'print(f"%s %s: {type(%s)}")',
	},
	emojiLog = {
		_placeholders = { "marker", "special" }, -- special = emoji
		lua = 'print("%s %s")',
		nvim_lua = 'vim.notify("%s %s")',
		python = 'print("%s %s")',
		javascript = 'console.log("%s %s");',
		sh = 'echo "%s %s" >&2',
		applescript = 'log "%s %s"',
		ruby = 'puts "%s %s"',
	},
	sound = { -- NOTE system bell commands requires program to run in a terminal supporting it
		_placeholders = { "marker" },
		sh = 'printf "\\a" # %s', -- system bell
		python = 'print("\\a")  # %s', -- system bell
		applescript = "beep -- %s",
		-- javascript = 'console.log("\\u0007"); // %s', -- system bell
		javascript = 'new Audio("data:audio/wav;base64,UklGRl9vT19XQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YU"+Array(800).join("200")).play()',
	},
	messageLog = {
		_placeholders = { "marker" },
		lua = 'print("%s ")',
		nvim_lua = 'vim.notify("%s ")',
		python = 'print("%s ")',
		javascript = 'console.log("%s ");',
		sh = 'echo "%s " >&2',
		applescript = 'log "%s "',
		rust = 'println!("{} ", "%s");',
		ruby = 'puts "%s "',
	},
	stacktraceLog = {
		_placeholders = { "marker" },
		lua = 'print(debug.traceback("%s"))', -- `debug.traceback` already prepends "stacktrace"
		nvim_lua = 'vim.notify(debug.traceback("%s"))',
		zsh = 'print "%s stacktrack: $funcfiletrace $funcstack"',
		bash = "print '%s stacktrace: ' ; caller 0",
		javascript = 'console.log("%s stacktrace: ", new Error()?.stack?.replaceAll("\\n", " "));', -- not all JS engines support console.trace()
		typescript = 'console.trace("%s stacktrace: ");',
	},
	debugLog = {
		_placeholders = { "marker" },
		javascript = "debugger; // %s",
		python = "breakpoint()  # %s",
		sh = {
			"set -exuo pipefail # %s", -- https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
			"set +exuo pipefail # %s", -- re-enable, so it does not disturb stuff from interactive shell
		},
	},
	clearLog = {
		_placeholders = { "marker" },
		javascript = "console.clear(); // %s",
		python = "clear()  # %s",
		sh = "clear # %s",
	},
	timeLogStart = {
		_placeholders = { "special", "marker" }, -- special = index
		lua = "local timelogStart%s = os.clock() -- %s",
		python = "local timelog_start_%s = time.perf_counter()  # %s",
		javascript = "const timelogStart%s = Date.now(); // %s", -- not all JS engines support console.time
		typescript = 'console.time("#%s %s");', -- string needs to be identical to `console.timeEnd`
		sh = "timelog_start_%s=$(date +%%s) # %s",
		ruby = "timelog_start_%s = Process.clock_gettime(Process::CLOCK_MONOTONIC) # %s",
	},
	timeLogStop = {
		_placeholders = { "special", "marker", "special" }, -- special = index
		lua = 'print(("#%s %s: %%.3fs"):format(os.clock() - timelogStart%s))',
		nvim_lua = 'vim.notify(("#%s %s: %%.3fs"):format(os.clock() - timelogStart%s))',
		python = 'print(f"#%s %s: {round(time.perf_counter() - timelog_start_%s, 3)}s")',
		javascript = "console.log(`#%s %s: ${(Date.now() - timelogStart%s) / 1000}s`);",
		typescript = 'console.timeEnd("#%s %s");',
		sh = 'echo "#%s %s $(($(date +%%s) - timelog_start_%s))s" >&2',
		ruby = 'puts "#%s %s: #{Process.clock_gettime(Process::CLOCK_MONOTONIC) - timelog_start_%s}s"',
	},
}

--------------------------------------------------------------------------------
-- SUPERSETS
local logTypes = vim.tbl_keys(M)

-- JS supersets inherit from `typescript`, and in turn `typescript` form
-- `javascript`, if it set itself.
local jsSupersets = { "typescriptreact", "javascriptreact", "vue", "svelte" }
for _, logType in ipairs(logTypes) do
	if not M[logType].typescript then M[logType].typescript = M[logType].javascript end
	for _, lang in ipairs(jsSupersets) do
		M[logType][lang] = M[logType].typescript
	end
end

-- shell supersets inherit from `sh`, if they have no config of their own.
local shellSupersets = { "bash", "zsh", "fish", "nu" }
for _, logType in ipairs(logTypes) do
	for _, lang in ipairs(shellSupersets) do
		if not M[logType][lang] then M[logType][lang] = M[logType].sh end
	end
end

-- CSS supersets inherit from `css`, if they have no config of their own.
local cssSupersets = { "scss", "less", "sass" }
for _, logType in ipairs(logTypes) do
	for _, lang in ipairs(cssSupersets) do
		if not M[logType][lang] then M[logType][lang] = M[logType].css end
	end
end

-- `nvim-lua` inherits from `lua`, if it has no config of its own.
for _, logType in ipairs(logTypes) do
	if not M[logType].nvim_lua and M[logType].lua then M[logType].nvim_lua = M[logType].lua end
end

--------------------------------------------------------------------------------
return M
