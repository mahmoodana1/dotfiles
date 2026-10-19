# Loaded only by nvim's python3 host (see ./host, set in core/options.lua).
#
# :MoltenImagePopup (<leader>jp) shows plots with PIL's Image.show(), which
# tries xdg-open first -- and xdg-open sends PNGs to the browser. Put Loupe in
# front instead; Hyprland already floats it (the "viewer" tag in windowrules).
import json
import os
import shutil
import subprocess
import threading
import time

os.environ.pop("PYTHONPATH", None)  # keep this out of kernels the host spawns

if shutil.which("loupe"):
    try:
        from PIL import ImageShow

        class LoupeViewer(ImageShow.UnixViewer):
            def get_command_ex(self, file, **options):
                return "loupe", "loupe"

            def show_file(self, path, **options):
                # Popen, not the base class's blocking os.system: molten waits on this
                subprocess.Popen(["loupe", path])
                if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
                    threading.Thread(target=_focus, args=(os.path.basename(path),), daemon=True).start()
                return 1

        def _focus(title, tries=30):
            # Hyprland has focus_on_activate = false and Loupe may reuse a running
            # window, so focus it explicitly once it shows up (titled by filename).
            # hyprctl dispatch takes Lua here -- see ~/dotfiles/docs/hyprland-lua.md
            for _ in range(tries):
                out = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True).stdout
                for c in json.loads(out or "[]"):
                    if c["class"] == "org.gnome.Loupe" and c["title"] == title:
                        subprocess.run(["hyprctl", "dispatch", f'hl.dsp.focus({{ window = "address:{c["address"]}" }})'],
                                       capture_output=True)
                        return
                time.sleep(0.1)

        ImageShow.register(LoupeViewer, 0)
    except ImportError:
        pass
