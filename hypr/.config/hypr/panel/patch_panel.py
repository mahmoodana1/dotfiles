with open("panel.py", "r") as f:
    text = f.read()

new_dim = """        dim = Gtk.Overlay()
        dim.add_css_class("panel-dim")
        dim.set_hexpand(True)
        dim.set_vexpand(True)

        self.rain_area = Gtk.DrawingArea()
        self.rain_area.set_draw_func(self._draw_rain)
        dim.set_child(self.rain_area)"""
text = text.replace('        dim = Gtk.Box()\n        dim.add_css_class("panel-dim")\n        dim.set_hexpand(True)\n        dim.set_vexpand(True)', new_dim)

text = text.replace('        dim.append(card)', '        dim.add_overlay(card)')

rain_funcs = """
    def _draw_rain(self, area, cr, width, height) -> None:
        import time
        mono = time.monotonic()
        cr.set_source_rgba(0.04, 0.075, 0.06, 1.0)
        cr.set_line_width(1.5)
        cr.set_line_cap(1)
        
        cols = int(width / 30)
        for c in range(cols):
            x = c * 30 + ((c * 17) % 30)
            seed = (c * 137) % 100
            speed = 400.0 + (seed * 3.0)
            cycle = height + 100
            for i in range(2):
                pos = (mono * speed + seed * 40 + i * (cycle / 2.0)) % cycle - 50
                cr.move_to(x, pos)
                cr.line_to(x, pos + 25)
        cr.stroke()

    def _animate_rain(self) -> bool:
        if self.window and self.window.get_visible():
            self.rain_area.queue_draw()
            return True
        self.rain_animating = False
        return False
"""
text = text.replace('    def alert_tick(self) -> bool:', rain_funcs.strip() + '\n\n    def alert_tick(self) -> bool:')

show_func = """
    def show(self) -> None:
        if not self.oneshot:
            self.kick_watchdog()
        if self.window.get_visible():
            return
        self._rebuild_content()
        target = self._target_monitor()
        if target is not None:
            LS.set_monitor(self.window, target)
        self._size_card(target)
        self.window.set_visible(True)
        
        if not getattr(self, "rain_animating", False):
            self.rain_animating = True
            GLib.timeout_add(33, self._animate_rain)
"""
text = text.replace('    def show(self) -> None:\n        # Kick first: a repeat heartbeat arriving while already visible must\n        # still keep the panel alive. Skipped in oneshot mode, which has no\n        # keybind feeding it heartbeats and is supposed to stay up on its own.\n        if not self.oneshot:\n            self.kick_watchdog()\n        if self.window.get_visible():\n            return\n        self._rebuild_content()\n        target = self._target_monitor()\n        if target is not None:\n            LS.set_monitor(self.window, target)\n        self._size_card(target)\n        self.window.set_visible(True)', show_func.strip())

with open("panel.py", "w") as f:
    f.write(text)
