-- OmaUX freeform desktop policy.
-- Keep normal application toplevels in Hyprland's floating layer so newly
-- opened apps cannot be visually buried under older floating windows.
-- Workspace ownership remains native: new apps open on the active workspace,
-- while existing windows stay on their own workspace.
o.window(".*", { float = true })
