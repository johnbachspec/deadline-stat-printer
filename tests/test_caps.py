"""cap_announcer.luau under the luau CLI: announcements, the chat command, and replacing a running copy."""
import unittest

from profiles import CAP_PRELUDE
from support import ROOT, needs_luau, run_script


@needs_luau
class TestCapAnnouncer(unittest.TestCase):
    def test_announces_captures_and_answers_the_chat_command(self):
        after = """
print("-- step: Alice caps")
__caps.Alice = 1; __tick()
print("-- step: both cap")
__caps.Alice = 2; __caps.Bob = 1; __tick()
print("-- step: chat")
__say("  !CAPS "); __say("hello")
shared.caps()
print("-- step: new match")
__caps.Alice = 0; __caps.Bob = 0; __tick()
__caps.Bob = 1; __tick()
print("-- step: stopped")
shared.stop_cap_announcer(); __caps.Bob = 5; __tick(); __say("!caps")
"""
        output = run_script("cap_announcer.luau", "nil", prelude=CAP_PRELUDE, after=after)
        steps = dict(part.split("\n", 1) for part in output.split("-- step: ")[1:])
        self.assertNotIn("ANNOUNCE", output.split("-- step: ")[0])  # the first check only records counts
        self.assertIn("ANNOUNCE: Alice captured a point (1 this match)", steps["Alice caps"])
        self.assertIn("ANNOUNCE: Alice and Bob captured a point", steps["both cap"])
        self.assertEqual(steps["chat"].count("ANNOUNCE: Captures this match: Alice 2, Bob 1"), 1)
        self.assertIn("[caps] Captures this match: Alice 2, Bob 1", steps["chat"])  # shared.caps() in the console
        self.assertEqual(steps["new match"].count("ANNOUNCE"), 1)  # the reset to 0 is not a capture
        self.assertIn("ANNOUNCE: Bob captured a point (1 this match)", steps["new match"])
        self.assertNotIn("ANNOUNCE", steps["stopped"])

    def test_running_it_again_replaces_the_running_copy(self):
        script = (ROOT / "cap_announcer.luau").read_text(encoding="utf-8")
        after = f";(function()\n{script}\nend)()\n__caps.Alice = 1; __tick(); __say('!caps')"
        output = run_script("cap_announcer.luau", "nil", prelude=CAP_PRELUDE, after=after)
        self.assertEqual(output.count("ANNOUNCE: Alice captured a point (1 this match)"), 1)
        self.assertEqual(output.count("ANNOUNCE: Captures this match: Alice 1"), 1)


# A mock of the client's Iris and both consoles' networking. Iris records what a
# frame draws: widgets in __drawn, table cells in __grids[table id][row][column],
# placed the way the real Table widget places them (2.4+ or older, __NEW_TABLES__).
# fire_client on the human "Tester" delivers straight to the viewer; fire_server
# delivers to the server's on_client_event handlers as that player.


if __name__ == "__main__":
    unittest.main()
