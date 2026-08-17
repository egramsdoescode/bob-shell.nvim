--- Bob FFI / SQLite helpers
local M = {}

local config = require("bob.config")

--- ffi.cdef can only be called once per symbol set — guard with a module-level flag.
local _sqlite_cdef_done = false

--- Load tasks from bob.db via LuaJIT FFI + libsqlite3 (zero extra dependencies).
--- Returns a list of {id, status, display_title} tables, newest-first.
--- @param limit number Maximum number of tasks to return
--- @param workspace string Filter to tasks whose workspace matches this path
--- @return table[] tasks, string|nil error
M.load_tasks_from_db = function(limit, workspace)
	local db_path = config.config.db_path or (os.getenv("HOME") .. "/.bob/db/bob.db")

	local ffi = require("ffi")

	if not _sqlite_cdef_done then
		ffi.cdef([[
			typedef struct sqlite3 sqlite3;
			typedef struct sqlite3_stmt sqlite3_stmt;
			int    sqlite3_open(const char *filename, sqlite3 **ppDb);
			int    sqlite3_close(sqlite3 *db);
			int    sqlite3_prepare_v2(sqlite3 *db, const char *zSql, int nByte,
			                          sqlite3_stmt **ppStmt, const char **pzTail);
			int    sqlite3_step(sqlite3_stmt *pStmt);
			int    sqlite3_finalize(sqlite3_stmt *pStmt);
			const unsigned char *sqlite3_column_text(sqlite3_stmt *pStmt, int iCol);
			int    sqlite3_bind_int(sqlite3_stmt *pStmt, int i, int iValue);
			int    sqlite3_bind_text(sqlite3_stmt *pStmt, int i, const char *zData,
			                         int nData, void *xDel);
		]])
		_sqlite_cdef_done = true
	end

	local SQLITE_ROW = 100
	local SQLITE_OK = 0

	local lib_ok, lib = pcall(ffi.load, "sqlite3")
	if not lib_ok then
		return nil, "could not load libsqlite3: " .. tostring(lib)
	end

	local db_ptr = ffi.new("sqlite3*[1]")
	if lib.sqlite3_open(db_path, db_ptr) ~= SQLITE_OK then
		return nil, "could not open bob.db at " .. db_path
	end
	local db = db_ptr[0]

	local sql = [[
		SELECT
		  id,
		  status,
		  REPLACE(
		    COALESCE(NULLIF(TRIM(title),''), NULLIF(TRIM(first_message),''), id),
		    char(10), ' '
		  ) AS display_title
		FROM tasks
		WHERE time_archived IS NULL
		  AND COALESCE(
		        NULLIF(directory, ''),
		        json_extract(env, '$.workspace'),
		        json_extract(env, '$.staticEnvInfo.primaryWorkspace')
		      ) = ?
		  AND EXISTS (
		        SELECT 1 FROM messages
		        WHERE messages.task_id = tasks.id
		          AND messages.role IN ('user', 'assistant')
		      )
		ORDER BY updated_at DESC
		LIMIT ?
	]]

	local stmt_ptr = ffi.new("sqlite3_stmt*[1]")
	if lib.sqlite3_prepare_v2(db, sql, -1, stmt_ptr, nil) ~= SQLITE_OK then
		lib.sqlite3_close(db)
		return nil, "failed to prepare SQL statement"
	end
	local stmt = stmt_ptr[0]
	-- SQLITE_TRANSIENT (-1 cast to pointer) tells SQLite to copy the string
	local SQLITE_TRANSIENT = ffi.cast("void *", -1)
	lib.sqlite3_bind_text(stmt, 1, workspace, #workspace, SQLITE_TRANSIENT)
	lib.sqlite3_bind_int(stmt, 2, limit)

	local tasks = {}
	while lib.sqlite3_step(stmt) == SQLITE_ROW do
		local id_ptr = lib.sqlite3_column_text(stmt, 0)
		local st_ptr = lib.sqlite3_column_text(stmt, 1)
		local title_ptr = lib.sqlite3_column_text(stmt, 2)
		-- sqlite3_column_text returns NULL for SQL NULL values; skip rows with a NULL id
		if id_ptr ~= nil then
			local id = ffi.string(id_ptr)
			local st = st_ptr ~= nil and ffi.string(st_ptr) or ""
			local title = title_ptr ~= nil and ffi.string(title_ptr) or id
			table.insert(tasks, { id = id, status = st, display_title = title })
		end
	end

	lib.sqlite3_finalize(stmt)
	lib.sqlite3_close(db)

	return tasks, nil
end

--- Load recent messages for a task from bob.db via LuaJIT FFI.
--- Returns {role, content}[] in chronological order (oldest first).
--- Only user/assistant turns with non-empty content are returned.
--- @param task_id string Task ID to load messages for
--- @param limit number Maximum number of messages to return
--- @return table[]|nil rows, string|nil error
M.load_messages_for_task = function(task_id, limit)
	local db_path = config.config.db_path or (os.getenv("HOME") .. "/.bob/db/bob.db")

	local ffi = require("ffi")
	-- _sqlite_cdef_done guard already ran in load_tasks_from_db; no second cdef needed.

	local SQLITE_ROW = 100
	local SQLITE_OK = 0

	local lib_ok, lib = pcall(ffi.load, "sqlite3")
	if not lib_ok then
		return nil, "could not load libsqlite3: " .. tostring(lib)
	end

	local db_ptr = ffi.new("sqlite3*[1]")
	if lib.sqlite3_open(db_path, db_ptr) ~= SQLITE_OK then
		return nil, "could not open bob.db at " .. db_path
	end
	local db = db_ptr[0]

	local sql = [[
		SELECT role,
		       json_extract(data, '$.content') AS content
		FROM messages
		WHERE task_id = ?
		  AND role IN ('user', 'assistant')
		  AND json_extract(data, '$.content') != ''
		ORDER BY created_at ASC
		LIMIT ?
	]]

	local stmt_ptr = ffi.new("sqlite3_stmt*[1]")
	if lib.sqlite3_prepare_v2(db, sql, -1, stmt_ptr, nil) ~= SQLITE_OK then
		lib.sqlite3_close(db)
		return nil, "failed to prepare messages SQL statement"
	end
	local stmt = stmt_ptr[0]
	local SQLITE_TRANSIENT = ffi.cast("void *", -1)
	lib.sqlite3_bind_text(stmt, 1, task_id, #task_id, SQLITE_TRANSIENT)
	lib.sqlite3_bind_int(stmt, 2, limit)

	local rows = {}
	while lib.sqlite3_step(stmt) == SQLITE_ROW do
		local role_ptr = lib.sqlite3_column_text(stmt, 0)
		local content_ptr = lib.sqlite3_column_text(stmt, 1)
		if role_ptr ~= nil and content_ptr ~= nil then
			table.insert(rows, {
				role = ffi.string(role_ptr),
				content = ffi.string(content_ptr),
			})
		end
	end

	lib.sqlite3_finalize(stmt)
	lib.sqlite3_close(db)

	return rows, nil
end

return M
