class_name KeybindStore
extends RefCounted
## Saving and loading the player's bindings, and the rules for changing them.
##
## `bindings` everywhere in this file is a plain Dictionary: one action name
## to its Array of tokens (see KeybindActions for the token grammar). It is the
## one source of truth once loaded. Whether an action differs from its default
## is always answered by comparing with KeybindActions.defaults_for(), and that
## comparison is what save() uses to decide what to write.
##
## The file is a ConfigFile:
##   [meta]      version, the file format (VERSION)
##   [bindings]  only the actions that differ from their defaults
##   [settings]  any other values your game keeps here (get_setting/set_setting)
## Every write goes through KeybindAtomicFile, so a crash mid-write never leaves
## a short file.
##
## The rules:
## - One token belongs to at most one action. Binding a taken token moves it
##   (rebind() returns the action that lost it as "displaced").
## - An action holds at most MAX_BINDINGS tokens.
## - Reset puts an action back to its defaults, and takes them back from any
##   action that has since claimed one: the player asked for the default.
## - In a file, an action the player changed beats an action still at its
##   default; between two changed actions, the earlier one in the table wins.

const VERSION := 1
const DEFAULT_PATH := "user://keybinds.cfg"
const MAX_BINDINGS := KeybindActions.MAX_BINDINGS

const _UNREADABLE_NOTICE := "Your key bindings could not be read; defaults restored"


## Reads the bindings file. Returns {"bindings", "settings", "warnings"}:
## the bindings for every action in the table, the [settings] section as a
## Dictionary, and the notices a player should see (empty when all is well).
## A missing file reads as defaults with no warning. An unreadable file reads
## as defaults with one warning and, while `quarantine` is true, is renamed to
## `<path>.bad`, so it is never read again but stays there to look at. Pass
## quarantine = false from tests and tools that must not touch a real file.
static func load(path: String = DEFAULT_PATH, quarantine: bool = true) -> Dictionary:
	var src := KeybindAtomicFile.readable_config_path(path)
	if not FileAccess.file_exists(src):
		return {
			"bindings": _defaults_map(KeybindActions.actions),
			"settings": {},
			"warnings": [],
		}
	var cfg := ConfigFile.new()
	var err := cfg.load(src)
	if err != OK:
		if quarantine:
			_quarantine(src)
		push_warning(_UNREADABLE_NOTICE)
		return {
			"bindings": _defaults_map(KeybindActions.actions),
			"settings": {},
			"warnings": [_UNREADABLE_NOTICE],
		}
	var result := parse(cfg, KeybindActions.actions)
	if result["invalid"] and quarantine:
		_quarantine(src)
	return {
		"bindings": result["bindings"],
		"settings": result["settings"],
		"warnings": result["warnings"],
	}


## Writes the bindings that differ from their defaults, plus [meta] version.
## [settings] keeps every value already in the file, with the values in
## `settings` written over them. Returns the write's error (OK on success).
static func save(bindings: Dictionary, settings: Dictionary = {}, path: String = DEFAULT_PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	for row in KeybindActions.actions:
		var name: String = row["name"]
		var current: Array = bindings.get(name, row["defaults"])
		if current != row["defaults"]:
			cfg.set_value("bindings", name, current)
	var merged := _file_settings(path)
	merged.merge(settings, true)
	for key in merged:
		cfg.set_value("settings", key, merged[key])
	return KeybindAtomicFile.save_config(cfg, path)


## The pure parse behind load(). `cfg` is an already-loaded ConfigFile;
## `action_rows` is the table (KeybindActions.actions). Returns {"bindings",
## "settings", "warnings", "invalid"}. "invalid" true means the whole file is
## judged unreadable (a missing, non-int, newer or older [meta] version), and
## the bindings are then plain defaults.
static func parse(cfg: ConfigFile, action_rows: Array[Dictionary]) -> Dictionary:
	if not cfg.has_section_key("meta", "version"):
		return _invalid_result(action_rows)
	var version = cfg.get_value("meta", "version", -1)
	if typeof(version) != TYPE_INT:
		return _invalid_result(action_rows)
	if version > VERSION:
		return _invalid_result(action_rows)
	if version < VERSION:
		# Version 1 is the first format, so there is nowhere yet for an older
		# file to migrate from; the call is here for the next version.
		migrate(version, cfg)
		return _invalid_result(action_rows)

	var warnings: Array[String] = []
	var known := {}
	for row in action_rows:
		known[row["name"]] = true

	var bindings := _defaults_map(action_rows)
	var overridden: Array[String] = []
	var claimed := {}  # token -> action name, in table order (file against file)

	for row in action_rows:
		var name: String = row["name"]
		if not cfg.has_section_key("bindings", name):
			continue
		var raw = cfg.get_value("bindings", name)
		if typeof(raw) != TYPE_ARRAY:
			continue  # keeps its default
		var any_valid := false
		var valid_tokens: Array[String] = []
		for tok in raw:
			if typeof(tok) != TYPE_STRING:
				continue
			if KeybindActions.decode(tok) == null:
				continue
			if KeybindActions.reserved.has(tok):
				continue
			any_valid = true
			if claimed.has(tok):
				continue  # an earlier action in the table already took it
			if valid_tokens.size() >= MAX_BINDINGS:
				# A hand-edited file can list more than the cap. Extra tokens are
				# dropped, not the whole entry, and stay unclaimed so a later
				# action may still have them.
				continue
			valid_tokens.append(tok)
			claimed[tok] = name
		if not any_valid and not (raw as Array).is_empty():
			continue  # every token was unusable: keep the default
		bindings[name] = valid_tokens
		overridden.append(name)

	bindings = resolve(bindings, overridden)

	if cfg.has_section("bindings"):
		for key in cfg.get_section_keys("bindings"):
			if not known.has(key):
				push_warning("KeybindStore: unknown action '%s' ignored" % key)
				warnings.append("Unknown action '%s' ignored" % key)

	var settings := {}
	if cfg.has_section("settings"):
		for key in cfg.get_section_keys("settings"):
			settings[key] = cfg.get_value("settings", key)

	return {
		"bindings": bindings,
		"settings": settings,
		"warnings": warnings,
		"invalid": false,
	}


## The hook for the next file version's migration. Version 1 is the first,
## so there is nothing to migrate: it returns `cfg` unchanged, and parse()
## still treats an older file as unreadable.
static func migrate(_from_version: int, cfg: ConfigFile) -> ConfigFile:
	return cfg


## Puts `bindings` into the live InputMap. Every action of the table has its
## events erased and re-added, so no stale event lingers. An action missing
## from `bindings` gets its defaults; a dev_only row binds nothing while
## KeybindActions.dev_keys is off.
static func apply(bindings: Dictionary) -> void:
	for row in KeybindActions.actions:
		var name: String = row["name"]
		if not InputMap.has_action(name):
			InputMap.add_action(name)
		else:
			InputMap.action_erase_events(name)
		if not KeybindActions.binds_now(row):
			continue
		var tokens: Array = bindings.get(name, row["defaults"])
		for token in tokens:
			var event := KeybindActions.decode(token)
			if event != null:
				InputMap.action_add_event(name, event)


## The bindings the live InputMap holds now, for every action in the table.
## A dev_only row that is unbound only because dev_keys is off reads as its
## defaults, so a save never writes it as unbound.
static func from_input_map() -> Dictionary:
	var out := {}
	for row in KeybindActions.actions:
		var name: String = row["name"]
		if not KeybindActions.binds_now(row):
			out[name] = (row["defaults"] as Array).duplicate()
			continue
		var tokens: Array[String] = []
		if InputMap.has_action(name):
			for ev in InputMap.action_get_events(name):
				var tok := KeybindActions.encode(ev)
				if tok != "":
					tokens.append(tok)
		out[name] = tokens
	return out


## The action that holds `token`, or "" when it is free.
static func owner_of(bindings: Dictionary, token: String) -> String:
	for name in bindings:
		if (bindings[name] as Array).has(token):
			return name
	return ""


## Gives `token` to `action`'s `slot`. A token the action already holds (in
## any slot) is a no-op. A token another action holds moves here, and that
## action is returned as "displaced". A new slot (slot >= the action's count)
## is refused once the action holds MAX_BINDINGS, and a reserved token is
## always refused. Returns {"bindings", "displaced": "" or an action name,
## "ok": bool}; a refused or no-op call returns `bindings` unchanged.
static func rebind(bindings: Dictionary, action: String, slot: int, token: String) -> Dictionary:
	var current: Array = (bindings.get(action, []) as Array).duplicate()
	if current.has(token):
		return {"bindings": bindings, "displaced": "", "ok": true}
	if KeybindActions.reserved.has(token):
		return {"bindings": bindings, "displaced": "", "ok": false}
	var owner := owner_of(bindings, token)
	if slot >= current.size() and current.size() >= MAX_BINDINGS:
		return {"bindings": bindings, "displaced": "", "ok": false}
	var out: Dictionary = bindings.duplicate(true)
	var displaced := ""
	if owner != "" and owner != action:
		var owner_tokens: Array = (out[owner] as Array).duplicate()
		owner_tokens.erase(token)
		out[owner] = owner_tokens
		displaced = owner
	var action_tokens: Array = current.duplicate()
	if slot < action_tokens.size():
		action_tokens[slot] = token
	else:
		action_tokens.append(token)
	out[action] = action_tokens
	return {"bindings": out, "displaced": displaced, "ok": true}


## One action back to its defaults. Any other action that has since taken one
## of those tokens loses it.
static func reset_action(bindings: Dictionary, action: String) -> Dictionary:
	var out: Dictionary = bindings.duplicate(true)
	var defaults := KeybindActions.defaults_for(action)
	for other in out.keys():
		if other == action:
			continue
		var other_tokens: Array = out[other] as Array
		var changed := false
		var kept: Array[String] = []
		for tok in other_tokens:
			if defaults.has(tok):
				changed = true
			else:
				kept.append(tok)
		if changed:
			out[other] = kept
	out[action] = defaults.duplicate()
	return out


## Every action back to its defaults. The defaults are conflict-free
## (KeybindActions.configure() refuses a table that is not), so nothing else
## needs adjusting.
static func reset_all() -> Dictionary:
	return _defaults_map(KeybindActions.actions)


## Drops the token at `slot` from `action`, if that slot exists.
static func remove_slot(bindings: Dictionary, action: String, slot: int) -> Dictionary:
	var out: Dictionary = bindings.duplicate(true)
	var arr: Array = (out.get(action, []) as Array).duplicate()
	if slot >= 0 and slot < arr.size():
		arr.remove_at(slot)
	out[action] = arr
	return out


## The file's rule when a changed action and an unchanged one share a token:
## the changed one keeps it. For every token an action in `overridden` holds,
## strip it from every action that is not itself overridden. Generic over any
## Dictionary of Arrays; it knows nothing about the table.
static func resolve(bindings: Dictionary, overridden: Array[String]) -> Dictionary:
	var out: Dictionary = bindings.duplicate(true)
	for name in overridden:
		for token in (out[name] as Array):
			for other in out.keys():
				if other == name or overridden.has(other):
					continue
				var other_tokens: Array = out[other] as Array
				if other_tokens.has(token):
					var kept: Array = other_tokens.duplicate()
					kept.erase(token)
					out[other] = kept
	return out


## One [settings] value, read on its own (no quarantine, no bindings parse).
## A missing file, a missing key, or a value of another type than `fallback`
## reads `fallback`. An int and a float count as one type: a float fallback
## reads an int as a float, and an int fallback a float as an int.
static func get_setting(key: String, fallback: Variant, path: String = DEFAULT_PATH) -> Variant:
	var cfg := ConfigFile.new()
	if path == "" or cfg.load(KeybindAtomicFile.readable_config_path(path)) != OK:
		return fallback
	var v = cfg.get_value("settings", key, fallback)
	var want := typeof(fallback)
	var got := typeof(v)
	if want == TYPE_FLOAT and got == TYPE_INT:
		return float(v)
	if want == TYPE_INT and got == TYPE_FLOAT:
		return int(v)
	if want != TYPE_NIL and got != want:
		return fallback
	return v


## Writes one [settings] value and keeps the rest of the file as it was. A
## missing or unreadable file starts a fresh one at VERSION.
static func set_setting(key: String, value: Variant, path: String = DEFAULT_PATH) -> Error:
	return write_settings({key: value}, path)


## Writes several [settings] values at once, keeping the rest of the file.
static func write_settings(values: Dictionary, path: String = DEFAULT_PATH) -> Error:
	var cfg := ConfigFile.new()
	if path == "" or cfg.load(KeybindAtomicFile.readable_config_path(path)) != OK:
		cfg = ConfigFile.new()
		cfg.set_value("meta", "version", VERSION)
	for key in values:
		cfg.set_value("settings", key, values[key])
	return KeybindAtomicFile.save_config(cfg, path)


static func _file_settings(path: String) -> Dictionary:
	var out := {}
	var cfg := ConfigFile.new()
	if path == "" or cfg.load(KeybindAtomicFile.readable_config_path(path)) != OK:
		return out
	if cfg.has_section("settings"):
		for key in cfg.get_section_keys("settings"):
			out[key] = cfg.get_value("settings", key)
	return out


## Every branch that judges the whole file unreadable comes here, so the
## engine log gets the same notice the player sees.
static func _invalid_result(action_rows: Array[Dictionary]) -> Dictionary:
	push_warning(_UNREADABLE_NOTICE)
	return {
		"bindings": _defaults_map(action_rows),
		"settings": {},
		"warnings": [_UNREADABLE_NOTICE],
		"invalid": true,
	}


static func _defaults_map(action_rows: Array[Dictionary]) -> Dictionary:
	var out := {}
	for row in action_rows:
		out[row["name"]] = (row["defaults"] as Array).duplicate()
	return out


## Renames a corrupt or invalid file to `<path>.bad`, replacing an older
## `.bad`, so the live path is never left as the bad one.
static func _quarantine(path: String) -> void:
	var bad := path + ".bad"
	if FileAccess.file_exists(bad):
		DirAccess.remove_absolute(bad)
	DirAccess.rename_absolute(path, bad)
