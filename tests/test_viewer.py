"""iris_viewer.luau and iris_theme.luau against the mock Iris: tables, paging, sorting, Export,
Refresh, themes, and reports reaching the viewer from the server scripts."""
import re
import tempfile
import unittest
from pathlib import Path

from iris_support import drawn, grids, iris_mocks, only_table, viewer_prelude
from profiles import CAP_PRELUDE, STAT_PROFILE
from support import CONSOLE_TABLES, ROOT, needs_luau, players_lua, run_script

import build_client_autorun as client_autorun  # noqa: E402


@needs_luau
class TestIrisViewer(unittest.TestCase):
    def test_stat_panel_opens_in_the_viewer_with_both_table_apis(self):
        for new_tables in (True, False):
            with self.subTest(new_tables=new_tables):
                output = run_script("print_player_stats.luau", players_lua(STAT_PROFILE),
                                    prelude=viewer_prelude(new_tables), after="__frame(); __dump()")
                self.assertNotIn("DETAILED WEAPON STATS", output)  # SHOW_IN "iris": no table in the console,
                self.assertIn("[iris] sent Tester's stats to 1 of 1 players", output)  # just where it went
                self.assertIn("Window Stats: Tester", drawn(output))
                weapons = only_table(output, 13)
                self.assertEqual(weapons[0][:3], ["Weapon", "Kills", "Deaths w/"])
                vector = next(row for row in weapons if row[0] == "Vector")
                self.assertEqual((vector[1], vector[-1]), ("950", "SMG"))
                recap = only_table(output, 6)
                self.assertEqual(recap[1][:2], ["Kills:", "3,000"])
                self.assertNotIn("<b>weapon</b>", output)  # a sortable header is a button, not bold text

    def test_refresh_asks_the_server_for_a_new_copy(self):
        after = """__frame()
local before = __sent
__click("dsp:stats:Tester:refresh"); __frame()
__click("dsp:attachments:Tester:refresh"); __frame()
print("REFRESHED " .. (__sent - before))
__click("dsp:stats:Tester:refresh"); __frame()  -- within half a second: ignored
print("AGAIN " .. (__sent - before))"""
        output = run_script("print_player_stats.luau", players_lua(STAT_PROFILE), prelude=viewer_prelude(),
                            after=";(function()\n" + (ROOT / "print_attachment_stats.luau").read_text(encoding="utf-8")
                            + "\nend)()\n" + after)
        self.assertIn("REFRESHED 2", output)  # each report fits in one message
        self.assertIn("AGAIN 2", output)

    def test_tooltips_show_only_for_the_hovered_widget(self):
        after = """__frame(); print("-- idle"); __dump()
__hover("dsp:stats:Tester:refresh"); __frame(); print("-- hover"); __dump()
__hover("dsp:hub:clear"); __frame(); print("-- hub"); __dump()
__hover("dsp:stats:Tester:1"); __frame(); print("-- section"); __dump()"""
        output = run_script("print_player_stats.luau", players_lua(STAT_PROFILE), prelude=viewer_prelude(), after=after)
        steps = dict(part.split("\n", 1) for part in output.split("-- ")[1:])
        self.assertFalse([line for line in drawn(steps["idle"]) if line.startswith("Tooltip")])
        self.assertEqual([line for line in drawn(steps["hover"]) if line.startswith("Tooltip")],
                         ["Tooltip Ask the server for a fresh copy of this report"])
        self.assertIn("Tooltip Forget every report received so far", drawn(steps["hub"]))
        section_tips = [line for line in drawn(steps["section"]) if line.startswith("Tooltip")]
        self.assertEqual(len(section_tips), 1)  # each section header has its own text, sent by the server
        self.assertIn("Lifetime totals from this player's profile", section_tips[0])

    def test_long_reports_arrive_in_parts_and_page_and_filter(self):
        after = r"""
local R = require("x/modules/iris_report.luau")
local report = R.new("attachments:Big", "Big", nil)
report:section("All", true)
report:columns({ "Name", "Note" })
for i = 1, 120 do report:row({ "row " .. i, string.rep("é", 40) .. "\ttab\\slash\nline" }) end
local messages = report:messages()
for _, m in ipairs(messages) do __assert(utf8.len(m), "a part split a UTF-8 character") end
print("PARTS " .. #messages)
for _, m in ipairs(messages) do __deliver(m) end
__frame(); print("-- page 1"); __dump()
__click("dsp:attachments:Big:2:2:next"); __frame(); __frame(); print("-- page 2"); __dump()
__widgets["dsp:attachments:Big:2:2:filter"].state.text.value = "ROW 5"; __frame(); print("-- filtered"); __dump()
__widgets["dsp:attachments:Big:2:2:filter"].state.text.value = ""
__click("dsp:attachments:Big:2:2:all"); __frame(); __frame(); print("-- all"); __dump()
"""
        output = run_script("iris_viewer.luau", "nil", prelude=iris_mocks(), after=after)
        self.assertGreater(int(re.search(r"PARTS (\d+)", output).group(1)), 1)
        pages = dict(part.split("\n", 1) for part in output.split("-- ")[1:])
        page1 = only_table(pages["page 1"], 2)
        self.assertEqual([r[0] for r in page1], ["Name"] + [f"row {i}" for i in range(1, 51)])
        self.assertEqual(page1[1][1], "é" * 40 + "<TAB>tab\\slash<NL>line")
        self.assertIn("Text rows 51-100 of 120", drawn(pages["page 2"]))
        self.assertEqual([r[0] for r in only_table(pages["page 2"], 2)][1:], [f"row {i}" for i in range(51, 101)])
        filtered = [r[0] for r in only_table(pages["filtered"], 2)][1:]
        self.assertEqual(filtered, ["row 5"] + [f"row {i}" for i in range(50, 60)])
        self.assertEqual(len(only_table(pages["all"], 2)), 1 + 120)  # Show all: every row on one page
        self.assertIn("Text all 120 rows", drawn(pages["all"]))
        self.assertIn("SmallButton Pages", drawn(pages["all"]))
        self.assertNotIn("SmallButton Next >", drawn(pages["all"]))

    def test_clicking_a_header_sorts_the_table(self):
        after = r"""
local R = require("x/modules/iris_report.luau")
local function send(extra)
  local report = R.new("attachments:Sort", "Sort", nil)
  report:section("All", true)
  report:columns({ "Name", "Kills", "Time", "Walked" })
  report:row({ "bravo", "1,200", "1h  0m  0s", "7,305 st" })
  report:row({ "alpha", "1,200", "2m 30s", "12 st" })
  report:row({ "charlie", "95", "45s", "300 st" })
  report:row({ "delta", "N/A", "1h 30m  0s", "1 st" })
  if extra then report:row(extra) end
  for _, m in ipairs(report:messages()) do __deliver(m) end
end
local key = "dsp:attachments:Sort:2:4:0:"
send(); __frame(); print("-- start"); __dump()
__click(key .. "2"); __frame(); __frame(); print("-- kills"); __dump()
__click(key .. "2"); __frame(); __frame(); print("-- kills again"); __dump()
__click(key .. "2"); __frame(); __frame(); print("-- kills third"); __dump()
__click(key .. "1"); __frame(); __frame(); print("-- name"); __dump()
__click(key .. "3"); __frame(); __frame(); print("-- time"); __dump()
__click(key .. "4"); __frame(); __frame(); print("-- walked"); __dump()
send({ "echo", "1", "1s", "99,999 st" }); __frame(); print("-- refreshed"); __dump()
__hover(key .. "4"); __frame(); print("-- hover"); __dump()
"""
        output = run_script("iris_viewer.luau", "nil", prelude=iris_mocks(), after=after)
        steps = dict(part.split("\n", 1) for part in output.split("-- ")[1:])

        def names(step):
            return [row[0] for row in only_table(steps[step], 4)[1:]]

        self.assertEqual(names("start"), ["bravo", "alpha", "charlie", "delta"])
        self.assertEqual(names("kills"), ["bravo", "alpha", "charlie", "delta"])  # most first; ties keep order; text last
        self.assertEqual(only_table(steps["kills"], 4)[0][:2], ["Name", "Kills \u25bc"])
        self.assertEqual(names("kills again"), ["charlie", "bravo", "alpha", "delta"])  # text stays last
        self.assertEqual(only_table(steps["kills again"], 4)[0][1], "Kills \u25b2")
        self.assertEqual(names("kills third"), ["bravo", "alpha", "charlie", "delta"])  # back to the server's order
        self.assertEqual(names("name"), ["alpha", "bravo", "charlie", "delta"])  # text: A-Z first
        self.assertEqual(names("time"), ["delta", "bravo", "alpha", "charlie"])  # "1h 30m 0s" > "1h 0m 0s" > "2m 30s"
        self.assertEqual(names("walked"), ["bravo", "charlie", "alpha", "delta"])  # "st" is not seconds
        self.assertEqual(names("refreshed"), ["echo", "bravo", "charlie", "alpha", "delta"])  # a new copy keeps the sort
        self.assertIn("Tooltip Sort by this column. Click again to reverse, a third time for the original order",
                      drawn(steps["hover"]))

    def test_reports_sent_before_the_viewer_starts_arrive_when_it_does(self):
        # e.g. Client Autorun starts the viewer after the stat scripts already ran: its hello
        # gets the server's kept copies resent.
        viewer = (ROOT / "iris_viewer.luau").read_text(encoding="utf-8")
        after = ("print('VIEWER BEFORE: ' .. tostring(shared.iris_viewer))\n"
                 ";(function()\n" + viewer + "\nend)()\n__frame(); __dump()")
        output = run_script("print_player_stats.luau", players_lua(STAT_PROFILE),
                            prelude=iris_mocks(), after=after)
        self.assertIn("VIEWER BEFORE: nil", output)  # nobody was listening when the report was sent
        self.assertIn("Window Stats: Tester", drawn(output))
        vector = next(row for row in only_table(output, 13) if row[0] == "Vector")
        self.assertEqual(vector[1], "950")

    def test_export_shows_the_report_as_tab_separated_text(self):
        after = """__frame()
__click("dsp:stats:Tester:export"); __frame()
print("EXPORT<<" .. __widgets["dsp:stats:Tester:exportbox"].state.text.value .. ">>")
__dump()"""
        output = run_script("print_player_stats.luau", players_lua(STAT_PROFILE), prelude=viewer_prelude(), after=after)
        self.assertIn("Window Export: Stats: Tester", drawn(output))
        text = re.search(r"EXPORT<<(.*)>>", output, re.S).group(1)
        lines = text.split("\n")
        self.assertEqual(lines[0], "Stats: Tester")
        self.assertIn("Kills:\t3,000", text)  # the recap's label / value pairs
        header = next(line for line in lines if line.startswith("Weapon\t"))
        self.assertEqual(header.split("\t")[:3], ["Weapon", "Kills", "Deaths w/"])
        vector = next(line for line in lines if line.startswith("Vector\t"))
        self.assertEqual(vector.split("\t")[1], "950")
        self.assertEqual(len(vector.split("\t")), len(header.split("\t")))  # one cell per column
        self.assertTrue(any(line.startswith("Detailed weapon stats") for line in lines))  # section titles

    def test_export_follows_the_sort(self):
        after = r"""
local R = require("x/modules/iris_report.luau")
local report = R.new("attachments:Sort", "Sort", nil)
report:section("All", true)
report:columns({ "Name", "Kills" })
report:row({ "a", "5" }); report:row({ "b", "50" }); report:row({ "c", "7" })
for _, m in ipairs(report:messages()) do __deliver(m) end
__frame()
__click("dsp:attachments:Sort:2:2:0:2"); __frame()
__click("dsp:attachments:Sort:export"); __frame()
print("EXPORT<<" .. __widgets["dsp:attachments:Sort:exportbox"].state.text.value .. ">>")
"""
        output = run_script("iris_viewer.luau", "nil", prelude=iris_mocks(), after=after)
        text = re.search(r"EXPORT<<(.*)>>", output, re.S).group(1)
        self.assertEqual(text, "Sort\n\nAll\nName\tKills\nb\t50\nc\t7\na\t5")

    def test_sorting_works_with_paging_filter_and_old_tables(self):
        after = r"""
local R = require("x/modules/iris_report.luau")
local report = R.new("attachments:Big", "Big", nil)
report:section("All", true)
report:columns({ "Name", "Kills" })
for i = 1, 120 do report:row({ "row " .. i, tostring(i) }) end
for _, m in ipairs(report:messages()) do __deliver(m) end
__frame()
__click("dsp:attachments:Big:2:2:0:2"); __frame(); __frame(); print("-- sorted"); __dump()
__widgets["dsp:attachments:Big:2:2:filter"].state.text.value = "row 11"; __frame(); print("-- filtered"); __dump()
"""
        for new_tables in (True, False):
            with self.subTest(new_tables=new_tables):
                output = run_script("iris_viewer.luau", "nil",
                                    prelude=iris_mocks(new_tables),
                                    after=after)
                steps = dict(part.split("\n", 1) for part in output.split("-- ")[1:])
                sorted_rows = only_table(steps["sorted"], 2)
                self.assertEqual(sorted_rows[0], ["Name", "Kills \u25bc"])
                self.assertEqual([r[1] for r in sorted_rows[1:4]], ["120", "119", "118"])
                self.assertEqual(len(sorted_rows), 1 + 50)  # still paged
                filtered = [r[0] for r in only_table(steps["filtered"], 2)[1:]]
                self.assertEqual(filtered, ["row 119", "row 118", "row 117", "row 116", "row 115", "row 114",
                                            "row 113", "row 112", "row 111", "row 110", "row 11"])

    def test_only_for_limits_the_viewer_to_named_players(self):
        viewer = (ROOT / "iris_viewer.luau").read_text(encoding="utf-8")
        self.assertIn("local ONLY_FOR = {}", viewer)
        mocks = iris_mocks() + '\nlocal local_player = "Tester"\n'
        for names, runs in (('{ "Someone" }', False), ('{ "Someone", "Tester" }', True)):
            with self.subTest(names=names):
                source = viewer.replace("local ONLY_FOR = {}", f"local ONLY_FOR = {names}")
                with tempfile.TemporaryDirectory() as tmp:
                    script = Path(tmp) / "viewer.luau"
                    script.write_text(source, encoding="utf-8")
                    output = run_script(script, "nil", prelude=mocks)
                self.assertEqual("[viewer] ready" in output, runs)

    @staticmethod
    def theme_source(**settings):
        """iris_theme.luau with settings changed, as Luau values, e.g. FONT='"Ubuntu"' or FONT_WEIGHT='nil'."""
        source = (ROOT / "iris_theme.luau").read_text(encoding="utf-8")
        for name, value in settings.items():
            source, found = re.subn(rf"^local {name} = \S+", f"local {name} = {value}", source, count=1, flags=re.M)
            assert found, name
        return f";(function()\n{source}\nend)()\n"

    def test_theme_snippet_styles_only_the_viewer_windows(self):
        output = run_script("iris_viewer.luau", "nil", prelude=viewer_prelude(extra=self.theme_source()),
                            after="__frame(); __dump()")
        frame = drawn(output)
        self.assertEqual(frame[0], "PushConfig dsp:theme size=14 font=nil color=rgb(255,255,255)")  # no FONT: Iris's own
        self.assertEqual(frame[1], "Window Stat printer")  # the push wraps our windows only
        self.assertEqual(frame[-1], "PopConfig")

    def test_every_window_has_a_red_close_button(self):
        output = run_script("print_player_stats.luau", players_lua(STAT_PROFILE), prelude=viewer_prelude(),
                            after="__frame(); __click('dsp:stats:Tester:export'); __frame(); __dump()")
        frame = drawn(output)
        windows = [line for line in frame if line.startswith("Window ")]
        closes = [i for i, line in enumerate(frame) if line == "SmallButton Close"]
        self.assertEqual(len(closes), len(windows))  # the hub, the report and its Export window
        self.assertGreaterEqual(len(windows), 3)
        for i in closes:  # red for this button alone
            self.assertRegex(frame[i - 1], r"^PushConfig \S+:close:config button=rgb\(170,35,25\)$")
            self.assertEqual(frame[i + 1], "PopConfig")

    def test_export_box_is_as_wide_as_its_window(self):
        udim = "local UDim = { new = function(scale, offset) return 'udim(' .. scale .. ',' .. offset .. ')' end }\n"
        for extra, width in ((udim, "udim(1,0)"), ("", None)):  # no UDim type: Iris's own width
            with self.subTest(width=width):
                output = run_script("print_player_stats.luau", players_lua(STAT_PROFILE), prelude=viewer_prelude(extra=extra),
                                    after="__frame(); __click('dsp:stats:Tester:export'); __frame(); __dump()")
                frame = drawn(output)
                i = next(i for i, line in enumerate(frame) if line.startswith("InputText "))
                if width:
                    self.assertEqual(frame[i - 1], f"PushConfig dsp:stats:Tester:exportbox:config width={width}")
                    self.assertEqual(frame[i + 1], "PopConfig")
                else:
                    self.assertFalse(frame[i - 1].startswith("PushConfig"))

    def test_close_button_closes_its_window(self):
        output = run_script("iris_viewer.luau", "nil", prelude=viewer_prelude(),
                            after="__frame(); __click('dsp:hub:close'); __frame()\n"
                                  "print('HUB OPEN ' .. tostring(__widgets['dsp:hub'].state.isOpened.value))")
        self.assertIn("HUB OPEN false", output)

    def test_close_button_without_color3_is_plain(self):
        output = run_script("iris_viewer.luau", "nil", prelude=viewer_prelude(extra="local Color3 = nil\n"),
                            after="__frame(); __dump()")
        self.assertEqual(drawn(output)[:2], ["Window Stat printer", "SmallButton Close"])  # no red push

    def test_theme_defaults_are_rubik_with_robotomono_numbers(self):
        output = run_script("print_player_stats.luau", players_lua(STAT_PROFILE),
                            prelude=viewer_prelude(extra="local Font = nil\n" + self.theme_source()),
                            after="__frame(); __dump()")
        weapons = only_table(output, 13)
        vector = next(row for row in weapons if "Vector" in row[0])
        self.assertEqual(vector[:2], ['<font family="rbxassetid://12187365977" weight="400">Vector</font>',
                                      '<font face="RobotoMono" weight="400">950</font>'])  # content Regular
        self.assertEqual(weapons[0][0], "Weapon")  # a sortable header is a button, in Iris's own font
        self.assertNotIn("<b>", output)

    def test_console_font_sets_every_iris_window(self):
        # Iris's global font reaches the client console window too; without the Font type
        # only Iris's own Ubuntu and Code are possible.
        cases = (('"Ubuntu"', "GLOBAL font=Enum.Font.Ubuntu", True),
                 ('"Code"', "GLOBAL font=Enum.Font.Code", True),
                 ('"Arial"', "CONSOLE_FONT not applied: could not get the Arial font here", False),
                 ("nil", None, False))
        for font, expected_msg, has_global in cases:
            with self.subTest(font=font):
                extra = "local Font = nil\n" + self.theme_source(CONSOLE_FONT=font)
                output = run_script("iris_viewer.luau", "nil", prelude=viewer_prelude(extra=extra))
                if expected_msg:
                    self.assertIn(expected_msg, output)
                if has_global:
                    self.assertIn("GLOBAL font=", output)
                else:
                    self.assertNotIn("GLOBAL font=", output)

    def test_console_font_from_a_hidden_label_without_font_type(self):
        # Deadline's console has neither the Font type nor Iris's presets, so the theme reads a
        # Font object back from a TextLabel; anything that isn't a real Font is not used.
        label = """
local Font = nil
iris.TemplateConfig = nil
local function create_instance(class)
  local fields = {}
  return setmetatable({ destroy = function() end }, {
    __newindex = function(_, k, v) fields[k] = v end,
    __index = function(_, k)
      if k == "FontFace" then return __LABEL_FONT(fields.Font) end
    end })
end"""
        good = "local function __LABEL_FONT(item) return setmetatable({ Family = 'rbxasset://fonts/families/' .. item .. '.json' }, __font_mt) end"
        bad = "local function __LABEL_FONT(item) return item end  -- e.g. a wrapped value that is not a Font"
        cases = ((good, "GLOBAL font=Font(rbxasset://fonts/families/Enum.Font.Ubuntu.json)"),
                 (bad, None))
        for font_source, applied in cases:
            with self.subTest(applied=applied):
                extra = font_source + "\n" + label + "\n" + self.theme_source(CONSOLE_FONT='"Ubuntu"')
                output = run_script("iris_viewer.luau", "nil", prelude=viewer_prelude(extra=extra))
                if applied:
                    self.assertIn(applied, output)
                else:
                    self.assertNotIn("GLOBAL font=", output)
                    self.assertIn("Iris's presets: missing, create_instance: yes", output)

    def test_deadline_colors_reach_the_viewer_and_the_console(self):
        cases = (('true', "GLOBAL font="),
                 ('false', None))
        for console_colors, global_colors in cases:
            with self.subTest(console_colors=console_colors):
                label = """
local Font = nil
local function create_instance(class)
  return setmetatable({ destroy = function() end }, { __index = function(_, k)
    if k == "FontFace" then return setmetatable({ Family = "rbxasset://fonts/families/BuilderSans.json" }, __font_mt) end
  end })
end"""
                extra = label + "\n" + self.theme_source(CONSOLE_COLORS=console_colors)
                output = run_script("iris_viewer.luau", "nil", prelude=viewer_prelude(extra=extra),
                                    after="__frame(); __dump()")
                self.assertEqual(drawn(output)[0], "PushConfig dsp:theme size=14 font=nil color=rgb(255,255,255)")
                self.assertEqual("color=rgb(255,255,255)" in output.split("PushConfig")[0], global_colors is not None)

    def test_deadline_colors_without_color3_come_from_a_hidden_label(self):
        # No Color3 type: black and white are read from a TextLabel's default colors and the
        # greys made with Color3:Lerp; colors that aren't a checked black and white are not used.
        def label(black, white):
            return f"""
local Color3 = nil
local function __grey(level)
  return setmetatable({{ R = level / 255, G = level / 255, B = level / 255,
    Lerp = function(self, other, t) return __grey(math.floor(self.R * 255 + (other.R - self.R) * 255 * t + 0.5)) end }},
    {{ __tostring = function(c) return "grey" .. math.floor(c.R * 255 + 0.5) end }})
end
local function create_instance(class)
  return setmetatable({{ destroy = function() end }}, {{ __index = function(_, k)
    if k == "TextStrokeColor3" then return __grey({black}) end
    if k == "BackgroundColor3" then return __grey({white}) end
  end }})
end"""
        good = run_script("iris_viewer.luau", "nil", prelude=viewer_prelude(extra=label(0, 255) + self.theme_source()),
                          after="__frame(); __dump()")
        self.assertEqual(drawn(good)[0], "PushConfig dsp:theme size=14 font=nil color=grey255")
        self.assertIn("GLOBAL color=grey255", good)  # the console gets them too
        bad = run_script("iris_viewer.luau", "nil", prelude=viewer_prelude(extra=label(27, 163) + self.theme_source()),
                         after="__frame(); __dump()")
        self.assertIn('COLORS "deadline" not applied', bad)
        self.assertEqual(drawn(bad)[0], "PushConfig dsp:theme size=14 font=nil color=nil")
        self.assertNotIn("GLOBAL color", bad)

    def test_theme_fonts_in_a_console_without_font_type(self):
        # Deadline's client console has no Font type: tables get the fonts through rich text,
        # and Iris's own font (titles, buttons) is left alone.
        extra = "local Font = nil\n" + self.theme_source(FONT="12187365977", FONT_WEIGHT='"Medium"', HEADER_WEIGHT="nil",
                                                             NUMBER_FONT='"RobotoMono"', NUMBER_WEIGHT="nil",
                                                             CONSOLE_FONT="nil")
        text, number = '<font family="rbxassetid://12187365977" weight="500">', '<font face="RobotoMono">'
        for new_tables in (True, False):
            with self.subTest(new_tables=new_tables):
                output = run_script("print_player_stats.luau", players_lua(STAT_PROFILE),
                                    prelude=viewer_prelude(new_tables, extra=extra), after="__frame(); __dump()")
                self.assertEqual(drawn(output)[0], "PushConfig dsp:theme size=14 font=nil color=rgb(255,255,255)")
                weapons = only_table(output, 13)
                self.assertEqual(weapons[0][0], "Weapon")  # sortable header: a button in Iris's font
                vector = next(row for row in weapons if row[0] == f"{text}Vector</font>")
                self.assertEqual((vector[1], vector[12]), (f"{number}950</font>", f"{text}SMG</font>"))
                self.assertEqual(only_table(output, 6)[1][:2], [f"{text}Kills:</font>", f"{number}3,000</font>"])
                self.assertNotIn("<b>", output)  # with a font set, headers take its weight instead of bold

    def test_theme_code_or_ubuntu_also_change_titles_without_font_type(self):
        # Iris's presets hold Font objects for Code and Ubuntu, so those need no Font type.
        extra = "local Font = nil\n" + self.theme_source(FONT='"Ubuntu"', FONT_WEIGHT="nil")
        output = run_script("iris_viewer.luau", "nil", prelude=viewer_prelude(extra=extra), after="__frame(); __dump()")
        self.assertEqual(drawn(output)[0], "PushConfig dsp:theme size=14 font=Enum.Font.Ubuntu color=rgb(255,255,255)")

    def test_theme_fonts_by_asset_id_and_weight_with_font_type(self):
        # A console that has the Font type can set Iris's own font to any family and weight.
        font_objects = """
local typeof = nil
Enum.FontWeight = { Medium = "Medium", Bold = "Bold" }
local Font = {
  fromId = function(id, weight) return setmetatable({}, { __tostring = function() return "Font.fromId(" .. id .. "," .. tostring(weight) .. ")" end }) end,
  fromEnum = function(item) return { Family = item .. ".json", Style = "Normal" } end,
  new = function(family, weight, style) return setmetatable({}, { __tostring = function() return "Font.new(" .. family .. "," .. weight .. "," .. style .. ")" end }) end,
}"""
        cases = (('12187365977', '"Medium"', "Font.fromId(12187365977,Medium)"),
                 ('"Ubuntu"', '"Bold"', "Font.new(Enum.Font.Ubuntu.json,Bold,Normal)"))
        for font, weight, expected in cases:
            with self.subTest(font=font):
                extra = font_objects + "\n" + self.theme_source(FONT=font, FONT_WEIGHT=weight)
                output = run_script("iris_viewer.luau", "nil", prelude=viewer_prelude(extra=extra),
                                    after="__frame(); __dump()")
                self.assertEqual(drawn(output)[0], f"PushConfig dsp:theme size=14 font={expected} color=rgb(255,255,255)")

    def test_number_font_applies_to_number_cells_only(self):
        cases = (('"RobotoMono"', "nil", '<font face="RobotoMono">'),
                 ('12187365977', '"Medium"', '<font family="rbxassetid://12187365977" weight="500">'))
        for font, weight, tag in cases:
            with self.subTest(font=font):
                extra = self.theme_source(FONT="nil", FONT_WEIGHT="nil", NUMBER_FONT=font, NUMBER_WEIGHT=weight)
                output = run_script("print_player_stats.luau", players_lua(STAT_PROFILE),
                                    prelude=viewer_prelude(extra=extra), after="__frame(); __dump()")
                vector = next(row for row in only_table(output, 13) if row[0] == "Vector")
                self.assertEqual(vector[1], f"{tag}950</font>")       # kills
                self.assertEqual(vector[4], f"{tag}2.375</font>")     # w-KDR
                self.assertEqual(vector[5], f"{tag}31.67%</font>")    # % allK
                self.assertEqual(vector[10], f"{tag}1h 30m 0s</font>")  # time used
                self.assertEqual(vector[12], "SMG")                   # words keep the main font
                recap = only_table(output, 6)
                self.assertEqual(recap[1][:2], ["Kills:", f"{tag}3,000</font>"])
                self.assertEqual(only_table(output, 13)[0][1], "Kills")  # headers too

    def test_client_autorun_file_runs_theme_and_viewer(self):
        self.assertEqual((ROOT / "client_autorun.txt").read_text(encoding="utf-8"), client_autorun.build(),
                         "client_autorun.txt is out of date: run python tools/build_client_autorun.py")
        output = run_script("client_autorun.txt", "nil", prelude=iris_mocks(),
                            after="__frame(); __dump()")
        self.assertNotIn("[theme] applied", output)
        self.assertIn("[viewer] ready", output)
        self.assertEqual(drawn(output)[:2], ["PushConfig dsp:theme size=14 font=nil color=rgb(255,255,255)",
                                             "Window Stat printer"])

    def test_reports_from_an_older_viewer_still_draw(self):
        # Pasting a new viewer keeps the reports the old one parsed, which lack newer fields.
        after = """
for _, report in pairs(shared.iris_viewer.reports) do
  for _, section in ipairs(report.sections) do
    for _, block in ipairs(section.blocks) do
      block.head = nil
      for _, row in ipairs(block.rows or {}) do row.number = nil end
    end
  end
end
__frame(); __dump()"""
        extra = self.theme_source(FONT="12187365977", FONT_WEIGHT="nil", HEADER_WEIGHT="nil", NUMBER_FONT='"RobotoMono"',
                                  NUMBER_WEIGHT="nil")
        output = run_script("print_player_stats.luau", players_lua(STAT_PROFILE),
                            prelude=viewer_prelude(False, extra=extra), after=after)
        self.assertNotIn("[viewer] Fiu", output)
        self.assertFalse(any(line.startswith("Text Error") for line in drawn(output)))
        text = '<font family="rbxassetid://12187365977">'
        weapons = only_table(output, 13)
        self.assertEqual(weapons[0][0], "Weapon")
        self.assertIn([f"{text}Vector</font>", f"{text}950</font>"], [row[:2] for row in weapons])

    def test_header_rows_from_an_older_viewer_get_the_header_weight(self):
        # An older viewer built and styled header rows without the is_head marker; they must
        # switch to HEADER_WEIGHT instead of keeping the content weight they were cached with.
        # (Only a table with one row keeps a text header; longer ones get sort buttons.)
        after = """
local R = require("x/modules/iris_report.luau")
local one = R.new("one", "One", nil); one:section("S", true); one:columns({ "weapon", "kills" }); one:row({ "M4A1 Block", "5" })
for _, m in ipairs(one:messages()) do __deliver(m) end
local fonts = shared.iris_viewer_fonts
for _, report in pairs(shared.iris_viewer.reports) do
  for _, section in ipairs(report.sections) do
    for _, block in ipairs(section.blocks) do
      if block.header then
        block.head = { number = {}, bold = true, rich_for = fonts, rich = {} }
        for c, name in ipairs(block.columns) do
          block.head[c] = { name }
          block.head.rich[c] = { fonts.text .. name .. "</font>", nil, nil, true }
        end
      end
    end
  end
end
__frame(); __dump()"""
        output = run_script("iris_viewer.luau", "nil", prelude=viewer_prelude(False, extra=self.theme_source()), after=after)
        weapons = only_table(output, 2)
        self.assertEqual(weapons[0][0], '<font family="rbxassetid://12187365977" weight="700">weapon</font>')
        self.assertEqual(weapons[1][0][:57], '<font family="rbxassetid://12187365977" weight="400">M4A1')

    def test_a_theme_iris_rejects_is_turned_off(self):
        after = """shared.iris_viewer_theme = { reject = true }
__frame(); print("-- after " .. tostring(shared.iris_viewer_theme)); __frame(); __dump()"""
        output = run_script("iris_viewer.luau", "nil", prelude=iris_mocks(False), after=after)
        self.assertIn("[viewer] theme turned off, Iris rejected it: ", output)
        self.assertIn("-- after nil", output)
        frame = drawn(output.split("-- after nil")[1])
        self.assertEqual(frame[0], "Window Stat printer")  # next frame draws without the theme
        self.assertTrue(any(line.startswith("Text Error: theme turned off") for line in frame))

    def test_a_failing_window_is_closed_and_reported_once(self):
        after = r"""
local R = require("x/modules/iris_report.luau")
local bad = R.new("bad", "Bad", nil); bad:section("S", true); bad:columns({ "A" }); bad:row({ "boom" })
for _, m in ipairs(bad:messages()) do __deliver(m) end
local good = R.new("good", "Good", nil); good:text("fine")
for _, m in ipairs(good:messages()) do __deliver(m) end
__frame(); __frame(); __dump()"""
        output = run_script("iris_viewer.luau", "nil", prelude=iris_mocks(), after=after)
        self.assertEqual(output.count("[viewer] "), 2)  # the ready line and one error
        self.assertIn("Text fine", drawn(output))       # later windows still draw
        self.assertTrue(any(line.startswith("Text Error: ") for line in drawn(output)))

    def test_captures_window_follows_the_announcer(self):
        cap_players = CAP_PRELUDE.replace("is_bot = function() return false end,",
                                          "is_bot = function() return false end, fire_client = __deliver,")
        cap_players = cap_players.replace("assert(", "__assert(")  # a server-side mock, after the client's assert = nil
        after = """
__caps.Alice = 1; __tick(); __frame(); print("-- captured"); __dump()
__widgets["dsp:caps"].state.isOpened.value = false
__caps.Bob = 1; __tick(); __frame(); print("-- closed " .. tostring(__widgets["dsp:caps"].state.isOpened.value))"""
        output = run_script("cap_announcer.luau", "nil", prelude=viewer_prelude(extra=cap_players), after=after)
        captured = output.split("-- captured")[1].split("-- closed")[0]
        self.assertEqual(only_table(captured, 2), [["Player", "Captures"], ["Alice", "1"]])
        self.assertTrue(any(line.endswith("Alice captured a point (1 this match)") for line in drawn(captured)))
        self.assertIn("-- closed false", output)  # live updates do not reopen a closed window


if __name__ == "__main__":
    unittest.main()
