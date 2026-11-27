extends GutTest
## KeybindAtomicFile: the tmp-and-rename writer, and what it keeps when a rename
## fails the way the engine's Windows rename can (the target removed first,
## then the move fails on a tmp held open by a scanner or a sync tool).

const FILE := "user://test_keybind_atomic.txt"


func before_each() -> void:
	_rm()


func after_each() -> void:
	KeybindAtomicFile.rename_seam = Callable()
	_rm()


func _rm() -> void:
	for p in [FILE, FILE + ".tmp", FILE + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## The engine's Windows rename as a seam: an existing target is removed first,
## then the move runs. A move whose source is in `fail_from` fails after that
## removal, leaving the source whole.
static func _windows_rename(fail_from: Array) -> Callable:
	return func(from: String, to: String) -> Error:
		if FileAccess.file_exists(to):
			DirAccess.remove_absolute(to)
		if fail_from.has(from):
			return ERR_FILE_CANT_WRITE
		return DirAccess.rename_absolute(from, to)


func _write(p: String, text: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_atomic_replace_moves_the_tmp_over_an_existing_file() -> void:
	assert_eq(KeybindAtomicFile.store_string(FILE, "old"), OK, "control: the first write")
	_write(FILE + ".tmp", "new")
	assert_eq(KeybindAtomicFile.atomic_replace(FILE + ".tmp", FILE), OK)
	assert_eq(FileAccess.get_file_as_string(FILE), "new", "the tmp's bytes replace the file")
	assert_false(FileAccess.file_exists(FILE + ".tmp"), "the tmp is gone")


func test_the_text_and_config_writers_leave_no_tmp() -> void:
	assert_eq(KeybindAtomicFile.store_string(FILE, "a\nb\n"), OK)
	assert_eq(FileAccess.get_file_as_string(FILE), "a\nb\n")
	assert_false(FileAccess.file_exists(FILE + ".tmp"), "no tmp after the text write")
	var cfg := ConfigFile.new()
	cfg.set_value("s", "k", 3)
	assert_eq(KeybindAtomicFile.save_config(cfg, FILE), OK)
	var back := ConfigFile.new()
	assert_eq(back.load(FILE), OK)
	assert_eq(back.get_value("s", "k"), 3, "the config reads back")
	assert_false(FileAccess.file_exists(FILE + ".tmp"), "no tmp after the config write")


## Positive control: the bare Windows-style rename loses the old file when the
## move fails. The seam reproduces the failure the guard below is written for.
func test_control_the_bare_rename_loses_the_old_file() -> void:
	_write(FILE, "old")
	_write(FILE + ".tmp", "new")
	var bare := _windows_rename([FILE + ".tmp"])
	assert_ne(bare.call(FILE + ".tmp", FILE), OK, "control: the move fails")
	assert_false(FileAccess.file_exists(FILE), "control: the old file is gone")


func test_a_failed_move_keeps_the_old_file() -> void:
	_write(FILE, "old")
	_write(FILE + ".tmp", "new")
	KeybindAtomicFile.rename_seam = _windows_rename([FILE + ".tmp"])
	assert_ne(KeybindAtomicFile.atomic_replace(FILE + ".tmp", FILE), OK, "the replace reports the failure")
	assert_eq(FileAccess.get_file_as_string(FILE), "old", "the last good file is back in place")
	assert_eq(FileAccess.get_file_as_string(FILE + ".tmp"), "new", "the new bytes stay whole in the tmp")
	assert_false(FileAccess.file_exists(FILE + ".bak"), "the backup is not left behind")


func test_store_var_keeps_the_last_good_save() -> void:
	assert_eq(KeybindAtomicFile.store_var(FILE, {"day": 1}), OK, "control: the first save")
	KeybindAtomicFile.rename_seam = _windows_rename([FILE + ".tmp"])
	var err := KeybindAtomicFile.store_var(FILE, {"day": 2})
	assert_ne(err, OK, "the second save reports the failure")
	var src := KeybindAtomicFile.readable_var_path(FILE)
	assert_eq(src, FILE, "the loader reads the save itself")
	var f := FileAccess.open(src, FileAccess.READ)
	assert_eq(f.get_var(), {"day": 1}, "and finds the last good save")
	f.close()
	assert_string_contains(KeybindAtomicFile.failure_note(FILE, err), "keeps the last save")
	KeybindAtomicFile.rename_seam = Callable()
	assert_eq(KeybindAtomicFile.store_var(FILE, {"day": 3}), OK, "the next save goes through")
	f = FileAccess.open(FILE, FileAccess.READ)
	assert_eq(f.get_var(), {"day": 3}, "and replaces it")
	f.close()


func test_a_failed_restore_keeps_both_copies() -> void:
	assert_eq(KeybindAtomicFile.store_var(FILE, {"day": 1}), OK, "control: the first save")
	KeybindAtomicFile.rename_seam = _windows_rename([FILE + ".tmp", FILE + ".bak"])
	assert_ne(KeybindAtomicFile.store_var(FILE, {"day": 2}), OK)
	assert_true(KeybindAtomicFile.is_whole_var(FILE + ".bak"), "the old save is whole in the backup")
	assert_eq(KeybindAtomicFile.readable_var_path(FILE), FILE + ".tmp", "the loader reads the new save")


func test_a_failed_move_aside_leaves_the_save() -> void:
	_write(FILE, "old")
	_write(FILE + ".tmp", "new")
	KeybindAtomicFile.rename_seam = _windows_rename([FILE])
	assert_ne(KeybindAtomicFile.atomic_replace(FILE + ".tmp", FILE), OK)
	assert_eq(FileAccess.get_file_as_string(FILE), "old", "the save is untouched")
	assert_eq(FileAccess.get_file_as_string(FILE + ".tmp"), "new", "the tmp is untouched")


func test_a_good_replace_leaves_no_backup() -> void:
	_write(FILE, "old")
	_write(FILE + ".tmp", "new")
	KeybindAtomicFile.rename_seam = _windows_rename([])
	assert_eq(KeybindAtomicFile.atomic_replace(FILE + ".tmp", FILE), OK)
	assert_eq(FileAccess.get_file_as_string(FILE), "new")
	assert_false(FileAccess.file_exists(FILE + ".tmp"), "no tmp")
	assert_false(FileAccess.file_exists(FILE + ".bak"), "no backup")


## A short tmp (a crash or a full disk mid-write) never replaces the file.
func test_a_cut_tmp_never_replaces_the_file() -> void:
	assert_eq(KeybindAtomicFile.store_var(FILE, {"day": 1}), OK)
	assert_ne(KeybindAtomicFile.store_var(FILE, {"day": 2}, 3), OK, "a tmp cut to 3 bytes is refused")
	assert_false(FileAccess.file_exists(FILE + ".tmp"), "and removed")
	var f := FileAccess.open(FILE, FileAccess.READ)
	assert_eq(f.get_var(), {"day": 1}, "the old save is whole")
	f.close()
	assert_eq(KeybindAtomicFile.store_string(FILE, "hello"), OK)
	assert_ne(KeybindAtomicFile.store_string(FILE, "goodbye", 2), OK, "a cut text tmp is refused too")
	assert_eq(FileAccess.get_file_as_string(FILE), "hello")
