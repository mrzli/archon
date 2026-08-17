local monitors = {
  desktop = {
    left = "desc:Dell Inc. DELL P2720DC 81WTK9CD05ES",
    right = "desc:Dell Inc. DELL P2720DC 81WTK9CD0U8S",
  },
  laptop = {
    primary_external = "desc:Dell Inc. DELL U3225QE H7DQ734",
    right_external = "desc:Dell Inc. DELL U3225QE 52XPC34",
  },
}

local function configure_monitor(output, mode, scale, position)
  hl.monitor({ output = output, mode = mode, position = position or "auto", scale = scale })
end

hl.env("GDK_SCALE", "1")
configure_monitor("", "preferred", 1)

configure_monitor(monitors.desktop.left, "preferred", 1, "0x0")
configure_monitor(monitors.desktop.right, "preferred", 1, "2560x0")

configure_monitor(monitors.laptop.primary_external, "3840x2160@60", 1.5)
configure_monitor(monitors.laptop.right_external, "3840x2160@60", 1.5)

for workspace = 1, 10 do
  hl.workspace_rule({
    workspace = tostring(workspace),
    persistent = true,
  })
end
