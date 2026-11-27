extends GutTest
## KeybindStore: the file round trip, parse() over every file case, the
## conflict rules as pure functions, and the [settings] helpers. Every real
## file is a "user://test_keybind_<n>.cfg" scratch file; nothing here touches
## KeybindStore.DEFAULT_PATH.


func before_each() -> void:
	KeybindActions.reserved = []
	KeybindActions.dev_keys = true
	KeybindActions.configure(KeybindActions.DEFAULT_ACTIONS)
	KeybindActions.install()


func after_each() -> void:
	KeybindActions.reserved = []
	KeybindAtomicFile.rename_seam = Callable()
	KeybindActions.configure(KeybindActions.DEFAULT_ACTIONS)
	KeybindActions.install()


func _cfg_v1() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	return cfg


func _clear(paths: Array) -> void:
	for p in paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


# --- parse(): every file case, in memory ------------------------------------

func test_parse_missing_meta_version_is_invalid() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("bindings", "quick_save", ["key:C:83"])
	var result := KeybindStore.parse(cfg, KeybindActions.actions)
	assert_true(result["invalid"], "no [meta] version at all is unreadable")
	assert_eq(result["bindings"]["quick_save"], KeybindActions.defaults_for("quick_save"),
			"an invalid file is ignored entirely")
	assert_false(result["warnings"].is_empty())


func test_parse_meta_version_not_int_is_invalid() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", "1")
	assert_true(KeybindStore.parse(cfg, KeybindActions.actions)["invalid"])


func test_parse_meta_version_newer_is_invalid() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", KeybindStore.VERSION + 1)
	assert_true(KeybindStore.parse(cfg, KeybindActions.actions)["invalid"], "a file from a newer build")


func test_parse_meta_version_older_goes_through_migrate_and_is_invalid_today() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 0)
	assert_true(KeybindStore.parse(cfg, KeybindActions.actions)["invalid"])
	assert_eq(KeybindStore.migrate(0, cfg), cfg, "migrate is callable and returns the cfg unchanged")


func test_parse_unknown_action_is_ignored_with_one_warning() -> void:
	var cfg := _cfg_v1()
	cfg.set_value("bindings", "not_a_real_action", ["key:-:%d" % KEY_B])
	var result := KeybindStore.parse(cfg, KeybindActions.actions)
	assert_false(result["invalid"])
	assert_eq(result["warnings"].size(), 1)
	assert_false(result["bindings"].has("not_a_real_action"))


func test_parse_non_array_value_keeps_default() -> void:
	var cfg := _cfg_v1()
	cfg.set_value("bindings", "quick_save", "not an array")
	var result := KeybindStore.parse(cfg, KeybindActions.actions)
	assert_eq(result["bindings"]["quick_save"], KeybindActions.defaults_for("quick_save"))


func test_parse_mixed_good_and_bad_tokens_keeps_only_the_good() -> void:
	var cfg := _cfg_v1()
	cfg.set_value("bindings", "quick_save",
			["key:87", "key:SC:83", "key:-:%d" % KEY_CTRL, 7, "key:-:%d" % KEY_B])
	var result := KeybindStore.parse(cfg, KeybindActions.actions)
	assert_eq(result["bindings"]["quick_save"], ["key:-:%d" % KEY_B])


func test_parse_all_bad_tokens_keeps_default() -> void:
	var cfg := _cfg_v1()
	cfg.set_value("bindings", "quick_save", ["key:87", "pad:-:7"])
	var result := KeybindStore.parse(cfg, KeybindActions.actions)
	assert_eq(result["bindings"]["quick_save"], KeybindActions.defaults_for("quick_save"))


func test_parse_empty_array_is_deliberately_unbound() -> void:
	var cfg := _cfg_v1()
	cfg.set_value("bindings", "quick_save", [])
	assert_eq(KeybindStore.parse(cfg, KeybindActions.actions)["bindings"]["quick_save"], [])


func test_parse_file_vs_file_conflict_earlier_action_wins() -> void:
	var cfg := _cfg_v1()
	cfg.set_value("bindings", "quick_save", ["key:C:83"])
	cfg.set_value("bindings", "quick_load", ["key:C:83"])
	var result := KeybindStore.parse(cfg, KeybindActions.actions)
	assert_eq(result["bindings"]["quick_save"], ["key:C:83"], "quick_save is earlier in the table")
	assert_eq(result["bindings"]["quick_load"], [])


func test_parse_file_vs_default_conflict_file_wins() -> void:
	var cfg := _cfg_v1()
	cfg.set_value("bindings", "quick_load", ["key:-:%d" % KEY_F5])
	var result := KeybindStore.parse(cfg, KeybindActions.actions)
	assert_eq(result["bindings"]["quick_load"], ["key:-:%d" % KEY_F5])
	assert_eq(result["bindings"]["quick_save"], [],
			"the default holder loses the token it never asked to keep")


func test_parse_drops_tokens_past_the_cap() -> void:
	var cfg := _cfg_v1()
	cfg.set_value("bindings", "quick_save", ["key:-:%d" % KEY_1, "key:-:%d" % KEY_2,
			"key:-:%d" % KEY_3, "key:-:%d" % KEY_4, "key:-:%d" % KEY_5])
	var result := KeybindStore.parse(cfg, KeybindActions.actions)
	assert_eq(result["bindings"]["quick_save"].size(), KeybindStore.MAX_BINDINGS, "a hand-edited fifth is dropped")


func test_parse_skips_a_reserved_token() -> void:
	KeybindActions.reserved = ["key:CS:%d" % KEY_P]
	var cfg := _cfg_v1()
	cfg.set_value("bindings", "quick_save", ["key:CS:%d" % KEY_P, "key:-:%d" % KEY_B])
	var result := KeybindStore.parse(cfg, KeybindActions.actions)
	assert_eq(result["bindings"]["quick_save"], ["key:-:%d" % KEY_B], "the reserved chord never loads")


func test_parse_returns_the_whole_settings_section() -> void:
	var cfg := _cfg_v1()
	cfg.set_value("settings", "show_hints", false)
	cfg.set_value("settings", "volumes", {"music": 0.5})
	var result := KeybindStore.parse(cfg, KeybindActions.actions)
	assert_eq(result["settings"], {"show_hints": false, "volumes": {"music": 0.5}})
	assert_true(result["warnings"].is_empty(), "settings are never a warning")


# --- load() and save(): the thin file shell --------------------------------

func test_load_missing_file_returns_defaults_with_no_warning() -> void:
	var path := "user://test_keybind_missing.cfg"
	_clear([path])
	var result := KeybindStore.load(path)
	assert_true(result["warnings"].is_empty())
	assert_eq(result["bindings"]["quick_save"], KeybindActions.defaults_for("quick_save"))
	assert_eq(result["settings"], {})


func test_load_corrupt_file_quarantines_to_bad_and_warns() -> void:
	var path := "user://test_keybind_corrupt.cfg"
	var bad := path + ".bad"
	_clear([path, bad])
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("this is not valid ini {{{ [[[ ===")
	f.close()
	var result := KeybindStore.load(path)
	assert_engine_error_count(1, "ConfigFile's own parse error on the garbage")
	assert_false(result["warnings"].is_empty())
	assert_true(FileAccess.file_exists(bad), "the corrupt file is renamed to .bad")
	assert_false(FileAccess.file_exists(path), "the live path is never left as the corrupt one")
	assert_eq(result["bindings"]["quick_save"], KeybindActions.defaults_for("quick_save"))
	_clear([bad])


func test_load_with_quarantine_false_leaves_corrupt_file_in_place() -> void:
	var path := "user://test_keybind_corrupt_kept.cfg"
	var bad := path + ".bad"
	_clear([path, bad])
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("this is not valid ini {{{ [[[ ===")
	f.close()
	var result := KeybindStore.load(path, false)
	assert_engine_error_count(1, "ConfigFile's own parse error on the garbage")
	assert_false(result["warnings"].is_empty())
	assert_true(FileAccess.file_exists(path), "left on disk, untouched")
	assert_false(FileAccess.file_exists(bad), "no .bad when quarantine is false")
	_clear([path])


func test_save_then_load_then_delete_round_trip() -> void:
	var path := "user://test_keybind_1.cfg"
	_clear([path])
	var bindings := KeybindStore.reset_all()
	bindings["quick_save"] = ["key:C:%d" % KEY_F6]
	assert_eq(KeybindStore.save(bindings, {"show_hints": false}, path), OK)
	var result := KeybindStore.load(path)
	assert_eq(result["bindings"]["quick_save"], ["key:C:%d" % KEY_F6])
	assert_false(result["settings"]["show_hints"])
	assert_eq(result["bindings"]["quick_load"], KeybindActions.defaults_for("quick_load"))
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(path), OK)
	assert_eq(cfg.get_section_keys("bindings"), PackedStringArray(["quick_save"]),
			"an action at its default is not written at all")
	_clear([path])
	assert_false(FileAccess.file_exists(path))


func test_save_keeps_settings_already_in_the_file() -> void:
	var path := "user://test_keybind_keep.cfg"
	_clear([path])
	assert_eq(KeybindStore.set_setting("music_volume", 0.4, path), OK)
	var bindings := KeybindStore.reset_all()
	bindings["jump"] = ["key:-:%d" % KEY_J]
	assert_eq(KeybindStore.save(bindings, {"show_hints": true}, path), OK)
	var result := KeybindStore.load(path)
	assert_eq(result["bindings"]["jump"], ["key:-:%d" % KEY_J])
	assert_almost_eq(float(result["settings"]["music_volume"]), 0.4, 0.0001, "a bindings save keeps the old setting")
	assert_true(result["settings"]["show_hints"], "and adds the new one")
	_clear([path])


# --- the rules as pure functions --------------------------------------------

func test_resolve_file_binding_beats_a_default_holder() -> void:
	var bindings := {"a": ["t1"], "b": ["t1", "t2"]}
	var overridden: Array[String] = ["a"]
	var out := KeybindStore.resolve(bindings, overridden)
	assert_eq(out["a"], ["t1"])
	assert_eq(out["b"], ["t2"], "b never opted in to t1 and loses it")


func test_owner_of_free_and_owned() -> void:
	var bindings := {"a": ["x"], "b": ["y", "z"]}
	assert_eq(KeybindStore.owner_of(bindings, "x"), "a")
	assert_eq(KeybindStore.owner_of(bindings, "y"), "b")
	assert_eq(KeybindStore.owner_of(bindings, "nope"), "")


func test_rebind_free_token() -> void:
	var r := KeybindStore.rebind({"a": ["x"], "b": []}, "b", 0, "y")
	assert_true(r["ok"])
	assert_eq(r["displaced"], "")
	assert_eq(r["bindings"]["b"], ["y"])
	assert_eq(r["bindings"]["a"], ["x"])


func test_rebind_owned_token_displaces() -> void:
	var r := KeybindStore.rebind({"a": ["x"], "b": []}, "b", 0, "x")
	assert_true(r["ok"])
	assert_eq(r["displaced"], "a")
	assert_eq(r["bindings"]["a"], [])
	assert_eq(r["bindings"]["b"], ["x"])


func test_rebind_same_action_duplicate_is_noop() -> void:
	var r := KeybindStore.rebind({"a": ["x", "y"]}, "a", 0, "y")
	assert_true(r["ok"])
	assert_eq(r["displaced"], "")
	assert_eq(r["bindings"]["a"], ["x", "y"])


func test_no_row_exceeds_the_cap_and_zoom_in_is_at_it() -> void:
	for row in KeybindActions.actions:
		assert_true(row["defaults"].size() <= KeybindStore.MAX_BINDINGS, "%s over the cap" % row["name"])
	assert_eq(KeybindActions.defaults_for("zoom_in").size(), KeybindStore.MAX_BINDINGS, "zoom_in ships at the cap")


func test_rebind_refuses_a_fifth_slot_at_the_cap() -> void:
	var bindings := KeybindStore.reset_all()
	var before: Array = bindings["zoom_in"].duplicate()
	var r := KeybindStore.rebind(bindings, "zoom_in", before.size(), "key:-:%d" % KEY_Z)
	assert_false(r["ok"], "a fifth slot is refused")
	assert_eq(r["bindings"]["zoom_in"], before, "and changes nothing")


func test_remove_slot_then_rebind_succeeds_past_the_cap() -> void:
	var reduced := KeybindStore.remove_slot(KeybindStore.reset_all(), "zoom_in", 0)
	assert_eq(reduced["zoom_in"].size(), KeybindStore.MAX_BINDINGS - 1)
	var r := KeybindStore.rebind(reduced, "zoom_in", reduced["zoom_in"].size(), "key:-:%d" % KEY_Z)
	assert_true(r["ok"])
	assert_eq(r["bindings"]["zoom_in"].size(), KeybindStore.MAX_BINDINGS)


func test_reset_action_takes_a_default_back_from_another_action() -> void:
	var bindings := KeybindStore.reset_all()
	bindings["quick_load"] = ["key:-:%d" % KEY_F5]
	bindings["quick_save"] = []
	var out := KeybindStore.reset_action(bindings, "quick_save")
	assert_eq(out["quick_save"], KeybindActions.defaults_for("quick_save"))
	assert_eq(out["quick_load"], [], "the player asked for the default")


func test_reset_all_restores_every_row() -> void:
	var out := KeybindStore.reset_all()
	for row in KeybindActions.actions:
		assert_eq(out[row["name"]], row["defaults"], "%s at its default" % row["name"])


func test_chord_three_actions_owner_of_and_rebind_displaces_none() -> void:
	var bindings := {
		"act_bare": ["key:-:83"],
		"act_ctrl": ["key:C:83"],
		"act_ctrl_shift": ["key:CS:83"],
	}
	assert_eq(KeybindStore.owner_of(bindings, "key:-:83"), "act_bare")
	assert_eq(KeybindStore.owner_of(bindings, "key:C:83"), "act_ctrl")
	assert_eq(KeybindStore.owner_of(bindings, "key:CS:83"), "act_ctrl_shift")
	var r := KeybindStore.rebind(bindings, "act_bare", 0, "key:-:83")
	assert_eq(r["displaced"], "")
	assert_eq(r["bindings"]["act_ctrl"], ["key:C:83"])
	assert_eq(r["bindings"]["act_ctrl_shift"], ["key:CS:83"])


func test_rebind_never_takes_a_reserved_token() -> void:
	KeybindActions.reserved = ["key:CS:%d" % KEY_P, "key:-:%d" % KEY_F12]
	var b := KeybindStore.from_input_map()
	for t in KeybindActions.reserved:
		var r := KeybindStore.rebind(b, "quick_save", 0, t)
		assert_false(r["ok"], "%s refused" % t)
		assert_eq(r["bindings"], b, "and nothing changed")
	assert_true(KeybindStore.rebind(b, "quick_save", 0, "key:C:%d" % KEY_F6)["ok"], "control: Ctrl+F6 binds")


func test_apply_installs_bindings_into_the_live_inputmap() -> void:
	var custom := KeybindStore.reset_all()
	custom["quick_save"] = ["key:-:%d" % KEY_B]
	KeybindStore.apply(custom)
	assert_true(InputMap.action_has_event("quick_save", KeybindActions.decode("key:-:%d" % KEY_B)))
	assert_false(InputMap.action_has_event("quick_save", KeybindActions.decode("key:-:%d" % KEY_F5)),
			"the old default is gone once apply() re-installs the row")
	assert_eq(KeybindStore.from_input_map()["quick_save"], ["key:-:%d" % KEY_B], "and reads back")


# --- [settings] --------------------------------------------------------------

func test_get_setting_reads_the_fallback_when_missing_or_mistyped() -> void:
	var path := "user://test_keybind_settings.cfg"
	_clear([path])
	assert_eq(KeybindStore.get_setting("show_hints", true, path), true, "no file: the fallback")
	assert_false(FileAccess.file_exists(path), "a read creates nothing")
	assert_eq(KeybindStore.write_settings({"show_hints": "yes", "music": 1, "sfx": 0.5}, path), OK)
	assert_eq(KeybindStore.get_setting("show_hints", true, path), true, "a string where a bool belongs")
	assert_eq(KeybindStore.get_setting("missing", 7, path), 7, "a missing key")
	assert_almost_eq(KeybindStore.get_setting("music", 0.8, path), 1.0, 0.0001, "an int reads as a float")
	assert_eq(KeybindStore.get_setting("sfx", 3, path), 0, "a float reads as an int")
	_clear([path])


func test_set_setting_round_trips_and_keeps_its_neighbours() -> void:
	var path := "user://test_keybind_settings_2.cfg"
	_clear([path])
	var bindings := KeybindStore.reset_all()
	bindings["interact"] = ["key:-:%d" % KEY_F]
	assert_eq(KeybindStore.save(bindings, {"show_hints": true}, path), OK)
	assert_eq(KeybindStore.set_setting("pause_on_focus_loss", false, path), OK)
	assert_false(KeybindStore.get_setting("pause_on_focus_loss", true, path))
	assert_true(KeybindStore.get_setting("show_hints", false, path), "the neighbour key is untouched")
	assert_eq(KeybindStore.load(path)["bindings"]["interact"], ["key:-:%d" % KEY_F], "and the bindings")
	_clear([path])


func test_a_failed_replace_keeps_the_tmp_and_the_settings_read_from_it() -> void:
	var path := "user://test_keybind_replace.cfg"
	var tmp := path + ".tmp"
	_clear([path, tmp])
	assert_eq(KeybindStore.save(KeybindStore.reset_all(), {}, path), OK, "control: a whole write")
	# By hand: a whole newer file in the tmp, the live file gone.
	var newer := {"show_hints": false, "hard_mode": true, "volumes": {"music": 0.25}}
	assert_eq(KeybindStore.save(KeybindStore.reset_all(), newer, tmp), OK, "the newer file, whole, in the tmp")
	DirAccess.remove_absolute(path)
	assert_false(KeybindStore.load(path, false)["settings"]["show_hints"], "the live file gone: load reads the tmp")
	assert_true(KeybindStore.get_setting("hard_mode", false, path), "and get_setting")
	assert_false(FileAccess.file_exists(path), "the reads create nothing")
	# A one-key writer reads the tmp, promotes it and keeps its other keys.
	assert_eq(KeybindStore.set_setting("fullscreen", false, path), OK)
	assert_false(FileAccess.file_exists(tmp), "no tmp after a whole write")
	assert_true(KeybindStore.get_setting("hard_mode", false, path), "the tmp's other settings kept")
	assert_almost_eq(float(KeybindStore.get_setting("volumes", {}, path)["music"]), 0.25, 0.0001)
	# Through the seam: the replace removes the live file and fails, the tmp kept.
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(path), OK)
	cfg.set_value("settings", "hard_mode", false)
	assert_ne(KeybindAtomicFile.save_config(cfg, path, true), OK, "a failed replace reports failure")
	assert_false(FileAccess.file_exists(path), "the seam removed the live file, as a Windows rename does")
	assert_true(FileAccess.file_exists(tmp), "the whole tmp is kept")
	assert_false(KeybindStore.get_setting("hard_mode", true, path), "the failed write's settings, read from the tmp")
	assert_eq(KeybindStore.set_setting("fullscreen", true, path), OK, "the next write lands")
	assert_true(KeybindStore.get_setting("fullscreen", false, path))
	assert_false(KeybindStore.get_setting("hard_mode", true, path), "the live file holds the tmp's settings")
	assert_false(FileAccess.file_exists(tmp), "and no tmp is left")
	_clear([path])
