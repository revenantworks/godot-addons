class_name KeybindAtomicFile
extends RefCounted
## Crash-safe file writes. A file is written whole to `path + ".tmp"` and only
## then moved over `path`, so a crash, a kill or a full disk mid-write leaves
## the old file whole, never a short one. KeybindStore writes the bindings file
## through save_config; store_var and store_string are here for your own
## save files.
##
## A failed replace keeps the whole tmp: store_var's loaders read it through
## readable_var_path, and store_string's and save_config's readers through
## readable_config_path, while `path` is missing. The next write promotes it.


## Moves `tmp` over `path`, and never removes `path` itself.
## The engine's rename is not atomic on every platform: on Windows it removes
## an existing target before it moves the tmp, so a tmp held open by a virus
## scanner or a sync tool can fail the move after `path` is already gone.
## So every rename here targets a missing file, and the engine never
## removes a live one. An existing `path` is first moved aside to
## `path + ".bak"`; the tmp then moves onto the free name, and the backup is
## removed only once that move reports OK. A failed move puts the backup back
## at `path`, so the last good file stays where its loader reads it. A failed
## move aside returns its error with `path` and the tmp untouched. If the
## restore fails too, nothing is removed: the old file stays in the backup and
## the new one in the tmp, which the loaders read. A stale backup (a crash
## after the move, before the remove) is overwritten by the next move aside;
## no loader or listing reads a .bak.
static func atomic_replace(tmp: String, path: String) -> Error:
	if not FileAccess.file_exists(path):
		return _rename(tmp, path)
	var bak := path + ".bak"
	var aside := _rename(path, bak)
	if aside != OK:
		return aside
	var moved := _rename(tmp, path)
	if moved != OK:
		_rename(bak, path)
		return moved
	DirAccess.remove_absolute(bak)
	return OK


## Test seam: a Callable(from, to) -> Error used in place of the engine's
## rename when valid. Tests reset it to Callable() after each run.
static var rename_seam: Callable = Callable()


static func _rename(from: String, to: String) -> Error:
	if rename_seam.is_valid():
		return rename_seam.call(from, to)
	return DirAccess.rename_absolute(from, to)


## Whether `p` holds one whole store_var record -- a 4-byte length
## and exactly that many bytes after it. False when missing or short.
static func is_whole_var(p: String) -> bool:
	if not FileAccess.file_exists(p):
		return false
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return false
	var n := f.get_length()
	var whole := n >= 4 and f.get_32() + 4 == n
	f.close()
	return whole


## The file a store_var loader reads for `path` -- `path` itself, or
## `path + ".tmp"` when `path` is missing or short and the tmp is whole (a
## replace that failed after the tmp was written, see atomic_replace). `path`
## when neither is whole, so the caller's own missing or corrupt branch runs.
static func readable_var_path(path: String) -> String:
	if not is_whole_var(path) and is_whole_var(path + ".tmp"):
		return path + ".tmp"
	return path


## The warning a store_var failure prints, saying what happened to
## `path` -- unchanged (the tmp was dropped), kept beside a whole new tmp, or
## gone with the new save kept in the tmp, where the loader reads it.
static func failure_note(path: String, err: Error) -> String:
	var tmp := path + ".tmp"
	if not is_whole_var(tmp):
		return "write failed (%s), %s is unchanged" % [error_string(err), path]
	if is_whole_var(path):
		return "replace failed (%s), %s keeps the last save; the new one is kept in %s" % [error_string(err), path, tmp]
	return "replace failed (%s), %s is gone; the new save is kept in %s and loads from there" % [error_string(err), path, tmp]


## Writes `value` (FileAccess.store_var's format, read back by get_var) to
## `path` atomically. The tmp must report no write error and hold exactly
## the bytes store_var writes (a 4-byte length plus var_to_bytes) before it
## replaces `path`; otherwise the tmp is removed, `path` is left as it was,
## and the error is returned. A replace that fails after that check keeps
## the tmp (atomic_replace). `cut` >= 0 is a test seam: the tmp is
## cut to that many bytes after the write, standing in for a crash or a full
## disk. `fail_replace` true is the second seam: the replace removes `path`
## and fails with the tmp left whole, standing in for the engine's Windows
## rename on a locked tmp.
## A whole tmp stranded beside a missing or short `path` is promoted
## before the write, so the write cannot truncate the only copy of a save; a
## failed promote returns its error with both files left as they are.
static func store_var(path: String, value: Variant, cut: int = -1, fail_replace: bool = false) -> Error:
	var tmp := path + ".tmp"
	if readable_var_path(path) == tmp:
		var moved := atomic_replace(tmp, path)
		if moved != OK:
			return moved
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_var(value)
	var err := f.get_error()
	f.close()
	if err == OK and cut >= 0:
		_cut(tmp, cut)
	if err == OK:
		var want := 4 + var_to_bytes(value).size()
		var r := FileAccess.open(tmp, FileAccess.READ)
		if r == null:
			err = FileAccess.get_open_error()
		else:
			if r.get_length() != want:
				err = ERR_FILE_CORRUPT
			r.close()
	if err != OK:
		if FileAccess.file_exists(tmp):
			DirAccess.remove_absolute(tmp)
		return err
	if fail_replace:
		return _fail_replace(path)
	return atomic_replace(tmp, path)


## The file a reader of store_string's or save_config's files (ConfigFile
## text) reads for `path`: `path` itself, or `path + ".tmp"` when `path`
## is missing and the tmp parses (a replace that failed after the tmp was
## written whole, see atomic_replace). `path` otherwise, so the caller's own
## missing or unreadable branch runs; "" stays "".
static func readable_config_path(path: String) -> String:
	var tmp := path + ".tmp"
	if path == "" or FileAccess.file_exists(path) or not FileAccess.file_exists(tmp):
		return path
	return tmp if ConfigFile.new().load(tmp) == OK else path


## store_var's promote for the text and config files -- a whole tmp
## stranded beside a missing `path` (readable_config_path) is moved over `path`
## before a write, so a write that then fails cannot remove the only copy. OK
## when nothing is stranded; a failed move returns its error, both files left.
static func promote_config_tmp(path: String) -> Error:
	var tmp := path + ".tmp"
	if readable_config_path(path) != tmp:
		return OK
	return atomic_replace(tmp, path)


## Writes `text` to `path` atomically (store_string, the write error checked
## before the close). The tmp must also hold exactly
## the text's UTF-8 bytes, so a full disk never renames a short tmp over a
## good file. save_config below checks only ConfigFile.save's error: its
## byte count is the engine's own, so a short config tmp is not caught.
## A stranded tmp is promoted first (promote_config_tmp); `cut` and
## `fail_replace` are store_var's two test seams, with store_var's meaning.
static func store_string(path: String, text: String, cut: int = -1, fail_replace: bool = false) -> Error:
	var tmp := path + ".tmp"
	var moved := promote_config_tmp(path)
	if moved != OK:
		return moved
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	var err := f.get_error()
	f.close()
	if err == OK and cut >= 0:
		_cut(tmp, cut)
	if err == OK and FileAccess.get_file_as_bytes(tmp).size() != text.to_utf8_buffer().size():
		err = ERR_FILE_CORRUPT
	if err != OK:
		if FileAccess.file_exists(tmp):
			DirAccess.remove_absolute(tmp)
		return err
	if fail_replace:
		return _fail_replace(path)
	return atomic_replace(tmp, path)


## Saves `cfg` to `path` atomically (ConfigFile.save to the tmp first).
## A stranded tmp is promoted first (promote_config_tmp);
## `fail_replace` is store_var's second seam, with its meaning.
static func save_config(cfg: ConfigFile, path: String, fail_replace: bool = false) -> Error:
	var tmp := path + ".tmp"
	var moved := promote_config_tmp(path)
	if moved != OK:
		return moved
	var err := cfg.save(tmp)
	if err != OK:
		if FileAccess.file_exists(tmp):
			DirAccess.remove_absolute(tmp)
		return err
	if fail_replace:
		return _fail_replace(path)
	return atomic_replace(tmp, path)


## The fail_replace seam: the replace removes `path` and fails with
## the tmp left whole, standing in for the engine's Windows rename on a
## locked tmp.
static func _fail_replace(path: String) -> Error:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return ERR_FILE_CANT_WRITE


## The test seam's cut: `tmp` keeps only its first `n` bytes.
static func _cut(tmp: String, n: int) -> void:
	var r := FileAccess.open(tmp, FileAccess.READ)
	if r == null:
		return
	var head := r.get_buffer(mini(n, r.get_length()))
	r.close()
	var w := FileAccess.open(tmp, FileAccess.WRITE)
	if w != null:
		w.store_buffer(head)
		w.close()
