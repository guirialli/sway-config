#!/usr/bin/python3
import gi
import subprocess
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk

def get_brightness():
    cur = int(subprocess.check_output(["brightnessctl", "g"]))
    maxv = int(subprocess.check_output(["brightnessctl", "m"]))
    return int(cur * 100 / maxv)

class Popup(Gtk.Window):
    def __init__(self):
        super().__init__(type=Gtk.WindowType.POPUP)
        self.set_default_size(300, 50)
        self.set_decorated(False)
        self.set_position(Gtk.WindowPosition.CENTER_ALWAYS)

        # fundo transparente opcional
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual and self.is_composited():
            self.set_visual(visual)
        self.set_app_paintable(True)

        box = Gtk.Box(spacing=10)
        box.set_border_width(10)
        self.add(box)

        self.scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self.scale.set_value(get_brightness())
        self.scale.set_draw_value(False)
        self.scale.connect("value-changed", self.on_change)
        self.scale.connect("button-release-event", self.on_release)

        box.pack_start(self.scale, True, True, 0)

    def on_change(self, widget):
        val = int(widget.get_value())
        if val < 1:
            val = 1
        elif val > 100:
            val = 100
        subprocess.run(["brightnessctl", "set", f"{val}%"])

    def on_release(self, *args):
        Gtk.main_quit()

Popup().show_all()
Gtk.main()

