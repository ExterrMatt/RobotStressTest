# Dialogue system

This is a reusable text/dialogue system shared across the entire game.
Every line of prose lives in a plain-text `.dlg` file you can edit by hand.

## Files

```
autoload/Dialogue.gd          # singleton: loads/parses .dlg files
scenes/ui/DialogueBox.gd      # reusable bounded dialogue box widget
scenes/ui/DialogueBox.tscn    # scene to instance anywhere
data/dialogue/*.dlg           # all the prose, one file per area
```

`Dialogue` is registered as an autoload in `project.godot`.

## Editing dialogue

Open any `.dlg` file. Format:

```
# A comment line (full line only).

[some.key]
First sentence shown on one click.
Second sentence shown on the next click.
Third sentence shown on the click after that.

[another.key]
Short line one. \
Joined onto the same click as this one.
A separate click again.
```

Rules:

- `# ...` lines are comments.
- `[some.key]` starts a new entry. The key must be a dotted identifier
  (letters/numbers/dots/underscores only).
- **Each non-blank line is one click in-game.** The player sees the
  sentence type out, then clicks to advance to the next sentence.
- Blank lines are **decorative** — they don't affect playback, you can use
  them however you like to group things visually while editing.
- A trailing `\` joins this line onto the next one so they appear in the
  same click — handy for short sentences you want shown together (e.g.
  `"Wrong."` followed by `"Ms. Okorie sighs."`).
- BBCode tags work: `[i]italic[/i]`, `[b]bold[/b]`, `[color=#7fdf7f]green[/color]`.
- Placeholders: any `{name}` in the text is replaced by `fmt["name"]`
  when you call `Dialogue.get_pages(file, key, fmt)`.

## Using a `DialogueBox` from a new location

1. Drop a `DialogueBox` scene into your location's layout.
2. From the script:

```gdscript
@onready var dialogue_box: DialogueBox = %DialogueBox

func _ready() -> void:
    Dialogue.load_file("home", "res://data/dialogue/home.dlg")
    dialogue_box.finished.connect(_on_dialogue_done)
    dialogue_box.play_pages(Dialogue.get_pages("home", "mom.greeting"))

func _on_dialogue_done() -> void:
    # show choices, advance phase, whatever comes next.
    pass
```

For a one-off line that isn't in any `.dlg` file:

```gdscript
dialogue_box.play_text("You feel a chill run down your spine.")
```

## Tuning the box

All tunables are `@export` so they show up in the inspector on any
`DialogueBox` instance:

| property                  | what it does                                 | typical |
|---------------------------|----------------------------------------------|---------|
| `chars_per_second`        | typing speed                                 | 40      |
| `fast_forward_multiplier` | how much SHIFT speeds up typing              | 3.0     |
| `sentence_pause`          | extra pause after `. ! ?`                    | 0.15    |
| `comma_pause`             | extra pause after `, ; :`                    | 0.05    |
| `box_height`              | fixed height of the dialogue area            | 140     |
| `advance_arrow_texture`   | drop your pixel-art arrow here when ready    | (none)  |

If `advance_arrow_texture` is empty, a `▼` glyph is shown as a fallback so
the system works out of the box.

## Player controls

- **Click** anywhere on the box: if typing, finishes the current page
  instantly; if a page is done, advances to the next page (or emits
  `finished` after the last page).
- **Hold Shift**: typing runs at `fast_forward_multiplier` × speed.

## Signals

`DialogueBox.finished` — emitted after the last page is dismissed. Connect
this to wire up what happens next (show question buttons, advance scene
phase, etc).

`DialogueBox.page_advanced(index)` — emitted at the start of each page,
in case you want to drive sound effects, portrait swaps, etc.
