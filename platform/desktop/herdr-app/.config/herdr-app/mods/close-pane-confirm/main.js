import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { run, props, closeOverlay, focused, panes, theme } from "herdr";

export default class ClosePaneConfirm extends View {
  init(_props, cx) {
    const f = focused();
    this.pane = f?.pane ?? null;
    this.info = panes().find((p) => p.pane === this.pane) ?? null;
    this.handle = cx.focus_handle();
    this.handle.focus();
    if (!this.pane) this.close();
  }

  close() {
    const id = props()?.overlay;
    if (id) closeOverlay(id);
  }

  yes() {
    const pane = this.pane;
    this.close();
    run("pane.close", { pane });
  }

  render(cx) {
    const t = theme();
    const p = this.info;
    const name = p?.title || p?.cwd || "this pane";
    return v_flex()
      .id("close-pane-confirm")
      .track_focus(this.handle)
      .on_key_down((e, cx) => {
        const k = e.key;
        if (k === "y" || k === "enter") this.yes();
        else this.close();
        cx.stop_propagation();
      })
      .size_full()
      .p(18)
      .gap(10)
      .rounded(8)
      .bg(t.popover)
      .text_size(13)
      .child(div().text_size(15).font_semibold().text_color(t.foreground).child("Close pane?"))
      .child(div().flex_1().min_h(0).overflow_hidden().text_color(t.muted).child(name))
      .child(
        h_flex()
          .justify_end()
          .gap(6)
          .text_size(12)
          .text_color(t.dim)
          .child(div().text_color(t.accent).child("y / enter"))
          .child("close")
          .child(div().pl(10).text_color(t.accent).child("any key"))
          .child("cancel"),
      );
  }
}
