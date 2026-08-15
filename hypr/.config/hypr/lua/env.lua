-- Environment variables.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
--
-- Order is preserved from the old .conf load order (ENVariables.conf ->
-- 01-UserDefaults.conf -> UserSettings.conf -> hyprland.conf tail), because
-- later assignments win.

-- Current version of the JaKooLit dotfiles this config was derived from
hl.env("DOTS_VERSION", "2.3.18")

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

-- Qt
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct") -- qt5ct was set first then overridden by qt6ct
hl.env("QT_QUICK_CONTROLS_STYLE", "org.hyprland.style")

-- XWayland scale fix. Match this to your monitor scaling.
-- 1 is 100%, 1.5 is 150%. See https://wiki.hypr.land/Configuring/XWayland/
hl.env("GDK_SCALE", "1")
hl.env("QT_SCALE_FACTOR", "1")

-- Default editor (mirrors 01-UserDefaults.conf)
hl.env("EDITOR", "nvim")

-- Firefox
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- Electron >28 apps. "auto" selects Wayland when possible, X11 otherwise.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- NVIDIA. See https://wiki.hypr.land/Nvidia/#environment-variables
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct") -- also fixes flickering in Electron apps
hl.env("GSK_RENDERER", "ngl")
hl.env("GBM_BACKEND", "nvidia-drm")

-- Additional NVIDIA knobs. Activate with care.
-- hl.env("__GL_GSYNC_ALLOWED", "1")       -- adaptive vsync
-- hl.env("__NV_PRIME_RENDER_OFFLOAD", "1")
-- hl.env("__VK_LAYER_NV_optimus", "NVIDIA_only")
-- hl.env("WLR_DRM_NO_ATOMIC", "1")

-- For VMs and possibly NVIDIA (software mesa rendering).
-- hl.env("LIBGL_ALWAYS_SOFTWARE", "1")     -- warning: may crash Hyprland
-- hl.env("WLR_RENDERER_ALLOW_SOFTWARE", "1")

-- Cursor theme. Set last so it wins over the ENVariables.conf values.
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
