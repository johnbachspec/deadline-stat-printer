# Iris viewer

`iris_viewer.luau` shows the stat printer's reports as in-game windows built with [Iris](https://sirmallard.github.io/Iris/), the UI library Deadline includes. This page covers how to use it, how it works, and what to watch out for when changing it. The notes live here rather than in the file because every line of the file counts toward [the Fiu line limit](#the-255-line-limit).

## Using it

Iris only runs in the **client** console, but profile stats only exist on the **server**, so the viewer uses both:

1. Open the Luau console, switch to **Client Luau console**, paste the whole of `iris_viewer.luau` and run it. A small "Stat printer" window opens and the console prints `[viewer] ready (Iris ... tables)`.
2. Switch to **Server Luau console** and run the scripts as usual, e.g.

   ```lua
   require("https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/print_player_stats.luau")
   ```

   Under each report the server console prints where it went: `[iris] sent bachancuc123's stats to 1 of 1 players`.

The client console has no `require`, so step 1 has to be a paste; `require(...)` there fails with `attempt to call a nil value`. You only paste it once per session.

### Starting it automatically (Client Autorun)

To skip step 1 for good, copy the whole of **`client_autorun.txt`** into the **Client Autorun** tab of the console. It is the theme and the viewer in one piece, with each file's settings at the top of its part (theme first). You can also paste `iris_viewer.luau` alone there. Deadline runs the client autorun on each player's client ("the client autorun runs per-client"), so the viewer starts by itself when you join.

That means every player on your server gets the viewer. To keep it to yourself, list your name in `ONLY_FOR` at the top of the file before pasting it:

```lua
local ONLY_FOR = { "bachancuc123" } -- only these players get the viewer; {} = everyone
```

After the viewer or theme changes, copy the new `client_autorun.txt` into Client Autorun again; the autorun keeps whatever was pasted last, not the file in this repo.

`client_autorun.txt` is generated: edit `iris_theme.luau` or `iris_viewer.luau`, then run `python tools/build_client_autorun.py` (the tests fail if it is out of date). The two files can't simply be joined, since the pasted text is one chunk and would pass [the 255-line limit](#the-255-line-limit). Instead each becomes a function passed to one call, `return run(theme, viewer)`. The compiler puts that call on the line it starts, and adds no hidden return at the end of a chunk that ends in `return`, so the chunk's own top level ends around line 100 and each part keeps its own 255 lines.

| Report | Sent by | Window |
| --- | --- | --- |
| Stat panel | `print_player_stats.luau` | "Stats: *name*": account recap, averages, weapon table |
| Attachment stats | `print_attachment_stats.luau` | "Attachments: *name*": every attachment by kills |
| Captures | `cap_announcer.luau` | "Captures": this match's standings and the latest captures, updated live |

In the windows:

- Sections collapse and expand; what you open or close is kept when the report refreshes.
- Click a column header to sort the table by it: number columns (kills, percentages, times like `1h 2m 3s`) put the most first, text columns go A-Z. Click again to reverse, and a third time to go back to the order the server sent. Cells that aren't numbers, like `N/A`, always go last. The sort is kept when the report refreshes, and the filter and pages work on the sorted rows. Tables with a single row keep a plain header.
- Tables with more than 12 rows get a filter box (matches any cell, case-insensitive). Tables with more than 50 rows get **< Prev** / **Next >** pages and a **Show all** button that puts every row on one page (**Pages** switches back). Show all on a very long table, like 1,000+ attachments, can cost frame rate, because every visible cell is drawn each frame.
- Hovering a button or the filter box shows an Iris tooltip explaining it. Hovering a section header shows what that section holds (the weapon section's tip also explains each column); the server sends that text with the section (`report:section(title, open, tip)`), so new sections get their own without changing the viewer. The viewer's `tip(widget, text)` helper draws it (`iris.Tooltip`, skipped if this Iris lacks it) and returns the widget, so it wraps a call without adding a line.
- **Refresh** asks the server for a fresh copy of that report.
- **Export** opens an "Export: ..." window with the whole report as text: its title, each section's title, and every table with columns separated by tabs, in the order you sorted them to. Click in the box, press Ctrl+A then Ctrl+C, and paste into Excel or Google Sheets: each value lands in its own cell, and numbers like `950` or `2.37` come out as numbers. The text is a snapshot, so press Export again after a Refresh or a new sort.
- The "Stat printer" window lists every report received. **Show** reopens a closed window and **Clear all** forgets them all.
- `shared.iris_viewer.show()` in the client console reopens every window. Pasting the file again does the same and also loads any changes to the viewer, keeping the reports it has.

The server sends each report to every human in the server; only players running the viewer see it. The Captures window updates without reopening if you close it; the other reports open their window each time they arrive.

### Settings

At the top of `iris_viewer.luau`:

| Setting | Default | What it does |
| --- | --- | --- |
| `PAGE_ROWS` | 50 | Table rows per page; longer tables also get Show all. Lower it if a big window costs frame rate. |
| `FILTER_ROWS` | 12 | Tables with more rows than this get a filter box. |
| `COLUMN_CHARS` | `{ 4, 40 }` | Iris before 2.4: each column is as wide as its longest text, counted in characters within these limits, as a share of the table. Raise the 40 to give long attachment names more room. |
| `WINDOW_SIZES` | per report kind | Initial window size in pixels, by the part of the report id before `:`. |
| `DEFAULT_SIZE` | 700 x 500 | Initial size for any other report. |
| `ONLY_FOR` | `{}` (everyone) | Player names the viewer runs for; for Client Autorun, so guests don't get it. |

### Theme: colors, spacing, font and text size

`iris_theme.luau` is a separate snippet for how the windows look. It styles only the stat printer's windows, not the Iris demo or any other mod's windows. Paste it into the client console after the viewer (or use `client_autorun.txt`, which has both). To change the look, edit the values at its top and paste it again.

| Setting | Default | Options |
| --- | --- | --- |
| `COLORS` | `"deadline"` | `"deadline"`: black and grey panels with white text and accents, like Deadline's menus (no Iris blue). `"dark"` / `"light"`: Iris's own sets, only if this console exposes them (Deadline's doesn't). `nil` leaves colors alone. |
| `CONSOLE_COLORS` | `true` | Also give the client console (every Iris window) the `"deadline"` colors. `false` = only the stat printer's windows. |
| `SPACING` | `nil` | `"clear"` (roomier, bigger padding) or `"default"` (compact). |
| `FONT` | `12187365977` (Rubik) | Font for the tables (`nil` for Iris's font, Code): a Roblox font name, e.g. `"RobotoMono"`, `"BuilderSans"`, `"Ubuntu"`, `"Arial"` (`"?"` prints every name), or a Creator Store font's asset id (the number in its store link), e.g. `12187365977` for [Rubik](https://create.roblox.com/store/asset/12187365977/Rubik), the font Deadline's own menus appear to use. |
| `FONT_WEIGHT` | `"Regular"` | Weight of the table text: `"Thin"`, `"ExtraLight"`, `"Light"`, `"Regular"`, `"Medium"`, `"SemiBold"`, `"Bold"`, `"ExtraBold"` or `"Heavy"`, for fonts that have that weight. |
| `HEADER_WEIGHT` | `"Bold"` | Weight of the table headers, in `FONT`; `nil` = same as `FONT_WEIGHT`. With a table font set, headers use this instead of the bold older Iris versions give them. Sortable headers (tables with 2+ rows) are buttons, so they use Iris's own font (`CONSOLE_FONT`) instead. |
| `TEXT_SIZE` | `14` | Text size in pixels, for everything. |
| `CONSOLE_FONT` | `"BuilderSansBold"` | Font of every Iris window: the client Luau console itself, plus the stat printer's titles, buttons and section headers. A built-in Roblox font name in quotes, with any weight in the name (`"BuilderSansBold"`, `"GothamBold"`, `"SourceSansBold"`); `nil` leaves it alone. Rubik can't be used here: it isn't built in, and loading it by asset id needs the `Font` type. |
| `NUMBER_FONT` | `"RobotoMono"` (`nil` = same as `FONT`) | A second font, by name or asset id like `FONT`, for table cells that are only a number: `12,345`, `3.721`, `61.28%`, `$1,234`, `2h 3m 20s`, `7,305 st`. |
| `NUMBER_WEIGHT` | `"Regular"` | Weight for `NUMBER_FONT`, like `FONT_WEIGHT`. |
| `EXTRA` | `{}` | Any other [Iris style key](https://github.com/SirMallard/Iris/blob/main/lib/config.lua), e.g. `WindowBgTransparency = 0.2`. Keys that need Roblox types (`Color3`, `Vector2`) only work if the console has them. |

The defaults pair Deadline's own font, Rubik, for text with a monospaced font for numbers, so numbers in each column line up. Font names and weights are text, so they need quotes (`"RobotoMono"`); without them Lua reads a variable that doesn't exist and the setting is silently off. Set everything to `nil` and paste it again to go back to Iris's normal look.

#### What the font reaches

Deadline's client console has **no `Font` type**, and Iris's own font setting only takes a `Font` object (Deadline's Iris is 2.1 or later, so it sets `FontFace`; an `Enum.Font` makes it fail with `Font expected, got EnumItem`). So the font is applied in two ways:

- **Table cells and table headers** (most of the text) get it through Roblox rich text: the viewer wraps each cell in `<font face="...">`, or `<font family="rbxassetid://...">` for an asset id, with `weight="500"` style weights. This needs no `Font` type, works for any font, and is cached when a report arrives, so it costs nothing per frame. `NUMBER_FONT` picks the tag for cells that are only a number; a cell mixing words and a number, like `SCAR-H (29045)`, uses `FONT`.
- **Window titles, buttons, section headers, the filter box and plain text lines** use Iris's own font, and so does the **client Luau console** window itself (it is an Iris window too). That setting only takes a real `Font` object. Without the `Font` type the snippet gets one two other ways: Iris's presets (Code and Ubuntu in `iris.TemplateConfig`, which Deadline's `iris` doesn't seem to expose), or by giving a hidden `TextLabel` (made with `create_instance`) the font by name and reading its `FontFace` back. It only uses a value that is a genuine `Font` (its `Family` is an `rbxasset://` path), since a bad global font would break every Iris window, the console included. `CONSOLE_FONT` sets this for every Iris window through `iris.UpdateGlobalConfig`; if neither way works it prints `CONSOLE_FONT not applied: could not get the ... font here (Iris's presets: ..., create_instance: ...)`. Weights and asset ids (Rubik) can't reach these parts without the `Font` type. The `[theme] applied` line says what each got (`titles and buttons: ...; console: ...`).

`CONSOLE_FONT` changes Iris's global setting for the rest of the session, so it also reaches any other Iris window, such as the Iris demo. Set it to `"Code"` and paste again to go back.

The `"deadline"` colors are grey levels, so they need no `Color3` type either: if the console lacks it, the snippet reads real black and white from a hidden `TextLabel`'s default colors and makes the greys between with `Color3:Lerp`. It only uses them after checking they are exactly black and white, since `CONSOLE_COLORS` changes every Iris window. If that fails it prints `COLORS "deadline" not applied` and leaves the colors alone.

The rich-text tags are not checked: a font name Roblox doesn't know just draws in the normal font, with no message. Asset ids in rich text (`rbxassetid://...`) are the least certain part; if Rubik doesn't show, use a font name.

The snippet stores the theme in `shared.iris_viewer_theme` (Iris style keys) and the table fonts in `shared.iris_viewer_fonts`. Each frame the viewer wraps its windows in `iris.PushConfig(theme)` / `iris.PopConfig()`, and Iris re-styles them when the theme changes. If Iris rejects a theme value, the viewer turns the theme off so the windows keep working. The snippet lives in its own file so it doesn't use up the viewer's [255 lines](#the-255-line-limit), and is split the same way: its fonts part (from "Table cells and headers get their font") is a second function with its own 255 lines.

On the server side, `SHOW_IN` at the top of `print_player_stats.luau` and `print_attachment_stats.luau` is `"iris"` (windows, and one status line in the console; the default), `"both"` (the full tables in the console too) or `"console"` (no windows). `cap_announcer.luau` has `SEND_TO_IRIS`.

## How it works

```
server console                                   client console
print_player_stats.luau                          iris_viewer.luau
  renderer:add_to_report(report, data)             on_server_event -> viewer.receive
  IrisBridge.publish(...) -- fire_client(text) -->   joins the parts, parses the report
                                                   iris:Connect -> viewer.draw, every frame
IrisBridge.serve("stats", build) <-- fire_server("dsp1|refresh|stats|...") -- Refresh button
                                 <-- fire_server("dsp1|hello") ----------- a viewer starting empty
```

- **Building a report.** `modules/iris_report.luau` is a small builder: `IrisReport.new(id, title, refresh)`, then `:section(title, open, tip)`, `:text(text)`, `:columns(names)`, `:row(cells)`. The renderers add to it (`Renderer:add_to_report`, `AttachmentRenderer:add_view`), from the same cells the console output uses, so the two never disagree.
- **Sending.** A report is encoded as text, one line per item with tab-separated fields (`report`, `section`, `text`, `columns`, `row`; backslash, tab and newline escaped). Text is used rather than tables because it survives whatever the game does to `fire_client` arguments. It goes out in parts of at most 4000 bytes, never splitting a UTF-8 character, each as `dsp1|<id>|<part>|<parts>|<text>`. The format is described at the top of `modules/iris_report.luau`.
- **Publishing.** `modules/iris_bridge.luau` is the server's side of the conversation: `IrisBridge.publish(console, report, recipients, what)` sends a report, keeps its latest copy, and prints the one status line (`[iris] sent ... to N of M players`). Console globals come in as `console = { players, shared, on_client_event }`, so the modules never read globals themselves.
- **Receiving.** The viewer keeps its state in `shared.iris_viewer`. It connects to `on_server_event` and `iris:Connect` only the first time it runs in a session; those connections call `viewer.receive` and `viewer.draw`, which a later paste replaces. That is why pasting again updates the viewer instead of drawing everything twice.
- **Starting late.** A report reaches only viewers already running when it is sent. So the server keeps its latest copy of each report (`IrisBridge.publish` keeps them in `shared.iris_report_bridge`), and a viewer that starts with no reports sends `dsp1|hello`, which gets all of them resent to that player. Reports from scripts run before you joined, or before Client Autorun started the viewer, still open.
- **Refresh.** A report's `refresh` field (e.g. `stats|Name|||KILLS`) is sent back with `fire_server`. `IrisBridge.serve` registers a builder per kind; its one `on_client_event` listener is connected once per server and finds builders through `shared.iris_report_bridge`, so re-running a server script replaces its handler. The answer goes only to the player who asked, and the same request from the same player is ignored for half a second.

## Iris under Fiu

The consoles run scripts in Fiu, a Luau interpreter written in Luau. Iris itself is the game's real, native module, but everything the viewer does is interpreted, which shapes the code:

- **Every widget needs an explicit id.** Iris normally identifies a widget by the source lines of the call stack that created it. From Fiu, every call comes from the same interpreter line, so Iris's automatic ids are just draw order. When the content changes (a report arrives, a page turns, a section opens), widgets swap identities: a pager showed up in the wrong window, and a row container was handed a text label, which failed with `UIListLayout is not a valid member of TextLabel`. So every widget call is preceded by `set_id(...)` (`iris.SetNextWidgetID`), with ids that start with `dsp:` and are built from the report id. The tests fail if any widget is drawn without one.
- **Two table APIs.** Iris 2.4 rewrote tables: from 2.4 you draw a cell and then call `NextColumn()`, and the header row is placed with `SetHeaderColumnIndex(1)`; before 2.4 you call `NextColumn()` before each cell, the first row is drawn as the header, and a column count may never change for the same table id. The viewer picks the style with `iris.NextHeaderColumn ~= nil` and reports it in its ready message ("2.4+" or "pre-2.4"). Table ids include the column count so a changed count gets a new table. Before 2.4 a table is really one vertical stack per column, so rows only line up while every cell is the same height: an empty cell is shorter and would push the rest of its column out of line, so the viewer shows `-` in empty cells (on screen only; sorting and Export still see an empty cell). The same tables make every column 1/n of the width and never resize their column frames, so the viewer sets each column's width once per report, in proportion to its longest text (`COLUMN_CHARS`). Iris 2.4+ sizes columns by content itself.
- **Cost per frame.** The draw function runs every frame through the interpreter. To keep that cheap, collapsed sections and closed windows are skipped, tables are paged (Show all is opt-in per table), cell arguments and widget ids are built once when a report arrives, and a filter result is cached until the filter text or report changes.
- **Errors.** Each window is drawn inside `pcall`. If one fails, the viewer closes whatever it left open (a broken open/`End()` balance would break every Iris window) and shows the error once in the "Stat printer" window.
- **Missing standard functions.** The client console has no `assert` (calling it fails with `attempt to call a nil value`), and other standard or Luau-only functions may be missing too. Client code sticks to plain `if` checks and loops (no `assert`, `error` or `table.find`), and the tests run the viewer and theme with `assert` removed.
- **No `require`, no `Vector2` guarantee.** The client console has no `require`, so the viewer is one file with no dependencies. Setting window size and position is wrapped in `pcall` in case `Vector2` is missing.

### The 255-line limit

The game's Fiu build fails to load any function spanning more than 255 source lines (see the main README's [Fiu section](README.md#the-fiu-255-line-limit)). A file's top level is a function that runs from its first line to its last, so the viewer is split in two:

- **The top level** (settings, `parse`, `viewer.receive`) ends at the line `return (function(drawing) drawing() end)(function() -- drawing ...`. The compiler puts that call, and the `return`, on the line where its argument list opens, and adds no hidden return after a chunk that ends in `return`, so the top level stops there.
- **The table part** (from `local depth = 0`: widgets, sorting, filtering, paging, `draw_table`) is the function passed to that call, with its own 255 lines. It ends the same way, at `return (function(windows) windows() end)(function() -- windows ...`.
- **The windows part** (Export, the report windows, the hub, `viewer.draw`) is the function passed to that second call, with its own 255 lines. The file ends with one `end)` per part.

Each part sees every local declared in the parts before it. About 120 lines are free in each (`python tools/check_fiu_compat.py -v iris_viewer.luau` prints each part's lines); when one fills up, split it again the same way.

The same works in `client_autorun.txt`, where the whole viewer becomes one function passed to `run(...)`. To keep room in each part:

- Put explanations here, not in the file. A comment at the end of a code line is free; a comment on its own line costs a line.
- No blank lines.
- Keep the split call's argument list opening on its own first line: a plain call such as `draw_part()` at the end of the file would move the top level's end back to the last line.
- Check with `python tools/check_fiu_compat.py -v iris_viewer.luau` (CI runs it too). It prints each function's lines, e.g. `main chunk (lines 1-81)`.

## Troubleshooting

| What you see | Meaning | What to do |
| --- | --- | --- |
| `Fiu VM Error ... Line: 1 ... CALL ... attempt to call a nil value` in the client console | `require` does not exist on the client | Paste the file instead, or put it in Client Autorun |
| Nothing happens after pasting, not even `[viewer] ready` | Your name is not in `ONLY_FOR` | Add it (exact spelling) or set `ONLY_FOR = {}` |
| `[viewer] iris, on_server_event or shared is missing` | Pasted into the server console | Use the client console |
| No window opens; server says `sent ... to 0 of N players (fire_client failed: ...)` | The server could not send | Send the error text along with a bug report |
| No window opens; the hub says `Messages received: 0` | Nothing reached the client | Run the stat script again. A viewer that starts with no reports asks the server for the ones it missed, but only from servers that ran a script since this update |
| The hub says `Messages received: N, last one not a report: ...` | Messages arrive in an unexpected shape | Report the text shown after "last one not a report" |
| `Error: ...` in the hub | A window failed to draw | Report the text; the other windows keep working |
| A table looks scrambled | Possibly the wrong table style for this Iris | Report the "Iris ... tables" part of the ready message |
| The table font changed but titles and buttons didn't | The console has no `Font` type, so only `"Code"` and `"Ubuntu"` reach them | Expected; see [What the font reaches](#what-the-font-reaches) |
| `[viewer] theme turned off, Iris rejected it: ...` (e.g. `Font expected, got EnumItem`) | A theme value this Iris can't use; the viewer dropped the theme so the windows keep working | Send the message; paste the theme again after a fix |
| Theme pasted but nothing changed | Pasted before the viewer, or the viewer is from before themes existed | Paste the current `iris_viewer.luau`, then the theme |
| Frame rate drops with a window open | Too many cells drawn per frame | Press **Pages** instead of Show all, lower `PAGE_ROWS`, or collapse sections you are not reading |

To check the connection without the stat scripts, run in the server console:

```lua
players.get("YourName").fire_client("dsp1|test|1|1|report\ttest\tIt works\t\t1\ntext\thello from the server")
```

An "It works" window should open on your client. To see every raw message the client receives:

```lua
on_server_event:Connect(function(...) print("[event]", select("#", ...), ...) end)
```

## Changing it

- `tests/test_viewer.py` runs the viewer under the `luau` CLI against a mock Iris that places table cells the way both table styles do, checks every frame ends with every widget closed and every widget has an explicit id, and routes `fire_client` / `fire_server` between the server scripts and the viewer. Run `python -m unittest discover -s tests`.
- New kinds of content go in both halves: a builder method in `modules/iris_report.luau` and a branch in the viewer's `parse` and `draw_blocks`.
- A new report only needs server code: build it with `IrisReport`, send it with `IrisBridge.publish(console, report, PlayerLookup.humans(players), what)`, and register a Refresh builder with `IrisBridge.serve`.
