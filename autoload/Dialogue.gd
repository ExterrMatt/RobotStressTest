extends Node
## Dialogue autoload.
##
## Loads .dlg text files (see data/dialogue/school.dlg for the format) and
## exposes them as a key -> Array[Array[String]] map:
##   pages[i]        -> the i-th "page" (revealed on one click).
##   pages[i][j]     -> the j-th line on that page (always 1 line per page
##                      unless the author joined lines with a trailing '\').
##
## Default semantics: ONE LINE PER PAGE.
##   Each non-blank source line becomes its own page. The player clicks to
##   advance between them. Blank lines in the source are purely decorative
##   (use them to visually group sentences in your editor).
##
## Merging two lines into one page:
##   End a line with a trailing backslash. The next non-blank line is joined
##   to it with a space and they share a single page. Stack multiple
##   backslashes to merge more than two.
##
## You normally do NOT call get_pages directly - the DialogueBox scene drives
## itself off this. You just call DialogueBox.play(key, fmt_vars) and it does
## the rest.

## Map of file_id -> Dictionary[key: String, pages: Array]
var _files: Dictionary = {}


## Load a .dlg file under the given id. Safe to call repeatedly; idempotent.
##   file_id: short tag like "school" used to namespace lookups.
##   path:    res:// path to the .dlg file.
func load_file(file_id: String, path: String) -> void:
	if _files.has(file_id):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Dialogue: could not open %s" % path)
		_files[file_id] = {}
		return
	var text: String = f.get_as_text()
	f.close()
	_files[file_id] = _parse(text)


## Get the pages for a key. Each page is an Array[String] of lines.
## fmt: optional Dictionary of {placeholder_name: value} substituted into the
##      text via String.format (so "{name}" in the file becomes fmt["name"]).
##
## Returns [] if the key is unknown (and pushes a warning so you notice in dev).
func get_pages(file_id: String, key: String, fmt: Dictionary = {}) -> Array:
	var file_data: Dictionary = _files.get(file_id, {})
	if not file_data.has(key):
		push_warning("Dialogue: unknown key '%s' in file '%s'" % [key, file_id])
		return []
	var raw_pages: Array = file_data[key]
	if fmt.is_empty():
		return raw_pages
	# Format-substitute. We duplicate so the cached pages aren't mutated.
	var out: Array = []
	for page in raw_pages:
		var formatted_page: Array[String] = []
		for line in page:
			formatted_page.append(String(line).format(fmt))
		out.append(formatted_page)
	return out


# --- Parser ---------------------------------------------------------------

func _parse(text: String) -> Dictionary:
	var result: Dictionary = {}
	var current_key: String = ""
	var current_pages: Array = []
	var pending_join: String = ""  # accumulates lines ending in trailing backslash

	# Normalize line endings.
	text = text.replace("\r\n", "\n").replace("\r", "\n")
	for raw_line in text.split("\n"):
		var line: String = String(raw_line).strip_edges()

		# Comments: full-line only. Inline '#' is not a comment so prose
		# can use '#' freely (e.g. "#1 in the class").
		if line.begins_with("#"):
			continue

		# Section header: [some.key]
		if line.begins_with("[") and line.ends_with("]") and not line.contains(" ") \
				and _looks_like_key(line):
			# Close out the previous key.
			_finalize_key(result, current_key, current_pages, pending_join)
			current_key = line.substr(1, line.length() - 2)
			current_pages = []
			pending_join = ""
			continue

		if current_key == "":
			# Stray content before any [key]; ignore.
			continue

		if line == "":
			# Blank lines are decorative separators. Flush any pending join
			# as a finished line, but otherwise do nothing.
			if pending_join != "":
				current_pages.append([pending_join.strip_edges()])
				pending_join = ""
			continue

		# Content line. Trailing backslash means "join with the next line
		# onto the same page".
		if line.ends_with("\\"):
			var stripped: String = line.substr(0, line.length() - 1).strip_edges()
			if pending_join == "":
				pending_join = stripped
			else:
				pending_join += " " + stripped
		else:
			var final_line: String = line
			if pending_join != "":
				final_line = pending_join + " " + final_line
				pending_join = ""
			# Each non-joined line is its own page.
			current_pages.append([final_line])

	# Close out the final key.
	_finalize_key(result, current_key, current_pages, pending_join)
	return result


func _finalize_key(
	result: Dictionary,
	key: String,
	pages: Array,
	pending_join: String,
) -> void:
	if key == "":
		return
	# Flush any dangling join as its own final page.
	if pending_join != "":
		pages.append([pending_join.strip_edges()])
	result[key] = pages


## Heuristic: a "[...]" line is a section header iff its contents look like
## a dotted/underscored identifier - that way "[i]italic[/i]" at the start of
## a content line doesn't get mistaken for a header.
func _looks_like_key(bracketed: String) -> bool:
	var inner: String = bracketed.substr(1, bracketed.length() - 2)
	if inner == "":
		return false
	for c in inner:
		var lc: String = c.to_lower()
		var is_alnum: bool = (lc >= "a" and lc <= "z") or (lc >= "0" and lc <= "9")
		if not is_alnum and c != "." and c != "_":
			return false
	return true
