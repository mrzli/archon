hl.env("GDK_SCALE", "1")
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.monitor({
  output = "desc:Dell Inc. DELL U3225QE H7DQ734",
  mode = "3840x2160@60",
  position = "auto",
  scale = 1,
})

hl.monitor({
  output = "desc:Dell Inc. DELL U3225QE 52XPC34",
  mode = "3840x2160@60",
  position = "auto",
  scale = 1,
})

for workspace = 1, 10 do
  hl.workspace_rule({
    workspace = tostring(workspace),
    persistent = true,
  })
end
