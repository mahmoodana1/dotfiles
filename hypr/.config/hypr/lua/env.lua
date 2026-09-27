-- Environment variables for everything Hyprland launches. Later lines win.
-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- Apps from defaults.lua, exported so scripts can use $TERMINAL etc.
local d = require("defaults")
hl.env("TERMINAL",    d.terminal)
hl.env("FILEMANAGER", d.fileManager)
hl.env("BROWSER",     d.browser)

-- Toolkit backends
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("CLUTTER_BACKEND", "wayland")

-- Run SDL2 applications on Wayland.
-- Remove or set to x11 if games shipping older SDL versions misbehave.
-- hl.env("SDL_VIDEODRIVER", "wayland")

-- xdg specifications
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

-- ~/.local/bin first, so wrappers there (blueman-manager -> island glass theme)
-- apply to everything the session launches, not just terminals
local localbin = os.getenv("HOME") .. "/.local/bin"
local path = os.getenv("PATH") or "/usr/local/bin:/usr/bin"
if not path:find(localbin, 1, true) then
    hl.env("PATH", localbin .. ":" .. path)
end

-- Qt
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_QUICK_CONTROLS_STYLE", "org.hyprland.style")

-- XWayland scale fix. Match this to your monitor scaling.
-- 1 is 100%, 1.5 is 150%. See https://wiki.hypr.land/Configuring/XWayland/
hl.env("GDK_SCALE", "1")
hl.env("QT_SCALE_FACTOR", "1")

-- Default editor
hl.env("EDITOR", "nvim")

-- Firefox
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- Electron >28 apps. "auto" selects Wayland when possible, X11 otherwise.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- GPUs: this laptop is Optimus. Both screens are wired to the Intel Iris Plus;
-- the NVIDIA MX250 has no display outputs. Apps render on the NVIDIA card
-- (PRIME render offload) and their frames are handed to Intel for display.
-- Hyprland itself composites on Intel (it has to: the screens are there).
-- The glass shells opt back out to Intel (hypr/scripts/bar.sh, startup.lua)
-- because they capture the screen, which lives on Intel.
-- One app back on Intel:  __NV_PRIME_RENDER_OFFLOAD=0 <app>
-- All apps back on Intel: delete the three lines below.
hl.env("__NV_PRIME_RENDER_OFFLOAD", "1")          -- OpenGL/EGL apps (Wayland and X11) -> NVIDIA
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")     -- X11 (XWayland) GLX apps -> NVIDIA
hl.env("__VK_LAYER_NV_optimus", "NVIDIA_only")    -- Vulkan apps and games -> NVIDIA
-- Video decoding stays on Intel's media engine: the MX250 has no video
-- decoder (nvidia-vaapi-driver loads but offers no profiles; nvidia-smi
-- shows Decoder N/A), so pointing VA-API at it meant CPU software decoding.
hl.env("LIBVA_DRIVER_NAME", "iHD")
hl.env("MOZ_DRM_DEVICE", "/dev/dri/by-path/pci-0000:00:02.0-render")   -- Firefox's VA-API device: Intel
hl.env("GSK_RENDERER", "ngl")

-- For VMs and possibly NVIDIA (software mesa rendering).
-- hl.env("LIBGL_ALWAYS_SOFTWARE", "1")     -- warning: may crash Hyprland
-- hl.env("WLR_RENDERER_ALLOW_SOFTWARE", "1")

-- Cursor theme
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
