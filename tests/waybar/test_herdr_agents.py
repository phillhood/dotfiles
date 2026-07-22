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


def agent(status, ws="w1", title="t", tid="term_x"):
    return {
        "agent": "claude",
        "agent_status": status,
        "workspace_id": ws,
        "terminal_title_stripped": title,
        "terminal_id": tid,
    }


class TestPure(unittest.TestCase):
    def test_status_of_fallback(self):
        self.assertEqual(ha.status_of({"agent_status": "weird"}), "unknown")
        self.assertEqual(ha.status_of({}), "unknown")
        self.assertEqual(ha.status_of({"agent_status": "working"}), "working")

    def test_count_by_status(self):
        ags = [agent("working"), agent("working"), agent("idle")]
        self.assertEqual(ha.count_by_status(ags), {"working": 2, "idle": 1})

    def test_sort_by_urgency(self):
        ags = [agent("working"), agent("blocked"), agent("done"), agent("idle")]
        got = [ha.status_of(a) for a in ha.sort_by_urgency(ags)]
        self.assertEqual(got, ["blocked", "idle", "done", "working"])

    def test_render_text_order_and_nonzero(self):
        ags = [agent("blocked"), agent("working"), agent("working")]
        expected = (
            "<span color='#ed8796'>%s</span> 1"
            "%s"
            "<span color='#c6a0f6'>%s</span> 2"
        ) % (ha.ICONS["blocked"], ha.SEP, ha.ICONS["working"])
        self.assertEqual(ha.render_text(ags), expected)

    def test_render_text_empty(self):
        self.assertEqual(ha.render_text([]), "")

    def test_build_output_empty(self):
        out = ha.build_output([])
        self.assertEqual(out["text"], "")
        self.assertIn("empty", out["class"])

    def test_build_output_class_is_top_status(self):
        out = ha.build_output([agent("working"), agent("blocked")])
        self.assertEqual(out["class"], ["herdr-agents", "blocked"])

    def test_tooltip_escapes_pango(self):
        tip = ha.render_tooltip([agent("idle", title="a & b <x>")])
        self.assertIn("a &amp; b &lt;x&gt;", tip)

    def test_picker_lines(self):
        lines = ha.picker_lines([agent("working", ws="w5", title="Do thing")])
        self.assertEqual(len(lines), 1)
        self.assertTrue(lines[0].startswith(ha.ICONS["working"]))
        self.assertIn("w5", lines[0])
        self.assertIn("Do thing", lines[0])

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
