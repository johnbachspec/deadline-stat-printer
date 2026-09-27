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

To skip step 1 for good, paste `iris_viewer.luau` into the **Client Autorun** tab of the console instead. Deadline runs the client autorun on each player's client ("the client autorun runs per-client"), so the viewer starts by itself when you join.

That means every player on your server gets the viewer. To keep it to yourself, list your name in `ONLY_FOR` at the top of the file before pasting it:

```lua
local ONLY_FOR = { "bachancuc123" } -- only these players get the viewer; {} = everyone
```

After you change `iris_viewer.luau`, paste the new version into Client Autorun again; the autorun keeps whatever was pasted last, not the file in this repo.

| Report | Sent by | Window |
| --- | --- | --- |
| Stat panel | `print_player_stats.luau` | "Stats: *name*": account recap, averages, weapon table |
| Attachment stats | `print_attachment_stats.luau` | "Attachments: *name*": every attachment by kills |
| Captures | `cap_announcer.luau` | "Captures": this match's standings and the latest captures, updated live |

In the windows:

- Sections collapse and expand; what you open or close is kept when the report refreshes.
- Tables with more than 12 rows get a filter box (matches any cell, case-insensitive). Tables with more than 50 rows get **< Prev** / **Next >** pages and a **Show all** button that puts every row on one page (**Pages** switches back). Show all on a very long table, like 1,000+ attachments, can cost frame rate, because every visible cell is drawn each frame.
- **Refresh** asks the server for a fresh copy of that report.
- The "Stat printer" window lists every report received. **Show** reopens a closed window and **Clear all** forgets them all.
- `shared.iris_viewer.show()` in the client console reopens every window. Pasting the file again does the same and also loads any changes to the viewer, keeping the reports it has.

The server sends each report to every human in the server; only players running the viewer see it. The Captures window updates without reopening if you close it; the other reports open their window each time they arrive.

### Settings

At the top of `iris_viewer.luau`:

| Setting | Default | What it does |
| --- | --- | --- |
| `PAGE_ROWS` | 50 | Table rows per page; longer tables also get Show all. Lower it if a big window costs frame rate. |
| `FILTER_ROWS` | 12 | Tables with more rows than this get a filter box. |
| `WINDOW_SIZES` | per report kind | Initial window size in pixels, by the part of the report id before `:`. |
| `DEFAULT_SIZE` | 700 x 500 | Initial size for any other report. |
| `ONLY_FOR` | `{}` (everyone) | Player names the viewer runs for; for Client Autorun, so guests don't get it. |

On the server side, `SHOW_IN` at the top of `print_player_stats.luau` and `print_attachment_stats.luau` is `"both"` (console text and windows), `"iris"` (windows only) or `"console"` (no windows). `cap_announcer.luau` has `SEND_TO_IRIS`.

## How it works

```
server console                                   client console
print_player_stats.luau                          iris_viewer.luau
  renderer:add_to_report(report, data)             on_server_event -> viewer.receive
  report:send(humans) --- fire_client(text) --->     joins the parts, parses the report
                                                   iris:Connect -> viewer.draw, every frame
IrisReport.serve("stats", build)  <-- fire_server("dsp1|refresh|stats|...") --- Refresh button
```

- **Building a report.** `modules/iris_report.luau` is a small builder: `IrisReport.new(id, title, refresh)`, then `:section(title, open)`, `:text(text)`, `:columns(names)`, `:row(cells)`. The renderers add to it (`Renderer:add_to_report`, `AttachmentRenderer:add_to_report`), from the same cells the console output uses, so the two never disagree.
- **Sending.** A report is encoded as text, one line per item with tab-separated fields (`report`, `section`, `text`, `columns`, `row`; backslash, tab and newline escaped). Text is used rather than tables because it survives whatever the game does to `fire_client` arguments. It goes out in parts of at most 4000 bytes, never splitting a UTF-8 character, each as `dsp1|<id>|<part>|<parts>|<text>`. The format is described at the top of `modules/iris_report.luau`.
- **Receiving.** The viewer keeps its state in `shared.iris_viewer`. It connects to `on_server_event` and `iris:Connect` only the first time it runs in a session; those connections call `viewer.receive` and `viewer.draw`, which a later paste replaces. That is why pasting again updates the viewer instead of drawing everything twice.
- **Refresh.** A report's `refresh` field (e.g. `stats|Name|||KILLS`) is sent back with `fire_server`. `IrisReport.serve` registers a builder per kind; its one `on_client_event` listener is connected once per server and finds builders through `shared.iris_report_bridge`, so re-running a server script replaces its handler. The answer goes only to the player who asked, and the same request from the same player is ignored for half a second.

## Iris under Fiu

The consoles run scripts in Fiu, a Luau interpreter written in Luau. Iris itself is the game's real, native module, but everything the viewer does is interpreted, which shapes the code:

- **Every widget needs an explicit id.** Iris normally identifies a widget by the source lines of the call stack that created it. From Fiu, every call comes from the same interpreter line, so Iris's automatic ids are just draw order. When the content changes (a report arrives, a page turns, a section opens), widgets swap identities: a pager showed up in the wrong window, and a row container was handed a text label, which failed with `UIListLayout is not a valid member of TextLabel`. So every widget call is preceded by `set_id(...)` (`iris.SetNextWidgetID`), with ids that start with `dsp:` and are built from the report id. The tests fail if any widget is drawn without one.
- **Two table APIs.** Iris 2.4 rewrote tables: from 2.4 you draw a cell and then call `NextColumn()`, and the header row is placed with `SetHeaderColumnIndex(1)`; before 2.4 you call `NextColumn()` before each cell, the first row is drawn as the header, and a column count may never change for the same table id. The viewer picks the style with `iris.NextHeaderColumn ~= nil` and reports it in its ready message ("2.4+" or "pre-2.4"). Table ids include the column count so a changed count gets a new table.
- **Cost per frame.** The draw function runs every frame through the interpreter. To keep that cheap, collapsed sections and closed windows are skipped, tables are paged (Show all is opt-in per table), cell arguments and widget ids are built once when a report arrives, and a filter result is cached until the filter text or report changes.
- **Errors.** Each window is drawn inside `pcall`. If one fails, the viewer closes whatever it left open (a broken open/`End()` balance would break every Iris window) and shows the error once in the "Stat printer" window.
- **No `require`, no `Vector2` guarantee.** The client console has no `require`, so the viewer is one file with no dependencies. Setting window size and position is wrapped in `pcall` in case `Vector2` is missing.

### The 255-line limit

The game's Fiu build fails to load any function spanning more than 255 source lines (see the main README's [Fiu section](README.md#the-fiu-255-line-limit)). A file's top level is a function that runs from its first line to its last, and wrapping the code in another function does not help, so the whole pasted file must be **255 lines or fewer**. To keep room:

- Put explanations here, not in the file. A comment at the end of a code line is free; a comment on its own line costs a line.
- No blank lines.
- Check with `python tools/check_fiu_compat.py` (CI runs it too).

## Troubleshooting

| What you see | Meaning | What to do |
| --- | --- | --- |
| `Fiu VM Error ... Line: 1 ... CALL ... attempt to call a nil value` in the client console | `require` does not exist on the client | Paste the file instead, or put it in Client Autorun |
| Nothing happens after pasting, not even `[viewer] ready` | Your name is not in `ONLY_FOR` | Add it (exact spelling) or set `ONLY_FOR = {}` |
| `[viewer] iris, on_server_event or shared is missing` | Pasted into the server console | Use the client console |
| No window opens; server says `sent ... to 0 of N players (fire_client failed: ...)` | The server could not send | Send the error text along with a bug report |
| No window opens; the hub says `Messages received: 0` | Nothing reached the client | Paste the viewer **before** running the server script; reports are sent once |
| The hub says `Messages received: N, last one not a report: ...` | Messages arrive in an unexpected shape | Report the text shown after "last one not a report" |
| `Error: ...` in the hub | A window failed to draw | Report the text; the other windows keep working |
| A table looks scrambled | Possibly the wrong table style for this Iris | Report the "Iris ... tables" part of the ready message |
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

- `tests/test_luau.py` (`TestIrisViewer`) runs the viewer under the `luau` CLI against a mock Iris that places table cells the way both table styles do, checks every frame ends with every widget closed and every widget has an explicit id, and routes `fire_client` / `fire_server` between the server scripts and the viewer. Run `python -m unittest discover -s tests`.
- New kinds of content go in both halves: a builder method in `modules/iris_report.luau` and a branch in the viewer's `parse` and `draw_blocks`.
- A new report only needs server code: build it with `IrisReport`, send it with `:send(PlayerLookup.humans(players))`, and register a Refresh builder with `IrisReport.serve`.
