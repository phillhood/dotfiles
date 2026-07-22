import importlib.machinery
import importlib.util
import pathlib
import unittest

_ROOT = pathlib.Path(__file__).resolve().parents[2]
_SCRIPT = _ROOT / "waybar" / ".config" / "waybar" / "herdr-agents"
# herdr-agents has no .py suffix (it's a waybar custom-module executable), so
# spec_from_file_location can't infer a loader from the extension alone and
# returns None; pass an explicit SourceFileLoader instead.
_loader = importlib.machinery.SourceFileLoader("herdr_agents", str(_SCRIPT))
_spec = importlib.util.spec_from_file_location("herdr_agents", _SCRIPT, loader=_loader)
ha = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ha)


def agent(status, ws="w1", title="t", tid="term_x", pane="w1:p1"):
    return {
        "agent": "claude",
        "agent_status": status,
        "workspace_id": ws,
        "terminal_title_stripped": title,
        "terminal_id": tid,
        "pane_id": pane,
    }


class TestPure(unittest.TestCase):
    def test_status_of_fallback(self):
        self.assertEqual(ha.status_of({"agent_status": "weird"}), "unknown")
        self.assertEqual(ha.status_of({}), "unknown")
        self.assertEqual(ha.status_of({"agent_status": "working"}), "working")

    def test_stable_sort_by_pane(self):
        a = agent("working", pane="w8:p1")
        b = agent("working", pane="w5:p1")
        got = [x["pane_id"] for x in ha.stable_sort([a, b])]
        self.assertEqual(got, ["w5:p1", "w8:p1"])

    def test_agent_line_escapes_and_shows_workspace(self):
        line = ha.agent_line(agent("idle", ws="w5", title="a & b <x>"))
        self.assertIn("w5", line)
        self.assertIn("a &amp; b &lt;x&gt;", line)

    def test_status_output_working_counts_only_matching(self):
        agents = [
            agent("working", pane="w5:p1"),
            agent("working", pane="w5:p9"),
            agent("blocked", pane="w6:p1"),
        ]
        out = ha.status_output("working", agents)
        self.assertEqual(out["text"], "<span color='#c6a0f6'>\U000F06A9</span> 2")
        self.assertEqual(out["class"], ["herdr-agents", "working"])
        self.assertEqual(len(out["tooltip"].split("\n")), 2)

    def test_status_output_blocked_single(self):
        out = ha.status_output("blocked", [agent("blocked", ws="w6", title="fix it")])
        self.assertEqual(out["text"], "<span color='#ed8796'>\U000F009A</span> 1")
        self.assertIn("fix it", out["tooltip"])

    def test_status_output_empty_is_hidden(self):
        out = ha.status_output("done", [agent("working", pane="w5:p1")])
        self.assertEqual(out["text"], "")
        self.assertIn("empty", out["class"])

    def test_state_signature_changes_with_status(self):
        working = [agent("working", pane="w5:p1")]
        blocked = [agent("blocked", pane="w5:p1")]
        self.assertNotEqual(ha.state_signature(working), ha.state_signature(blocked))

    def test_state_signature_is_order_independent(self):
        x = agent("working", pane="w5:p1")
        y = agent("idle", pane="w6:p1")
        self.assertEqual(ha.state_signature([x, y]), ha.state_signature([y, x]))

    def test_pick_herdr_window_prefers_title(self):
        clients = [
            {"title": "nvim", "class": "com.mitchellh.ghostty", "address": "0x1"},
            {"title": "herdr", "class": "com.mitchellh.ghostty", "address": "0x2"},
        ]
        self.assertEqual(ha.pick_herdr_window(clients)["address"], "0x2")

    def test_pick_herdr_window_falls_back_to_class(self):
        clients = [
            {"title": "nvim", "class": "com.mitchellh.ghostty", "address": "0x1"},
            {"title": "firefox", "class": "firefox", "address": "0x9"},
        ]
        self.assertEqual(ha.pick_herdr_window(clients)["address"], "0x1")

    def test_pick_herdr_window_none(self):
        self.assertIsNone(ha.pick_herdr_window([{"title": "x", "class": "y"}]))


if __name__ == "__main__":
    unittest.main()
