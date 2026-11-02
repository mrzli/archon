# VS Code Settings

In `home/.config/Code/User/settings.json`, order general top-level settings
alphabetically by setting key. Place language-specific blocks after all general
settings. Order these blocks alphabetically by language identifier, such as
`[markdown]` before `[typescript]`.

# Global Agent Instructions

Keep `home/.codex/AGENTS.md` independent of any skill collection or script.
Describe the activity or the kind of skill, such as "review the change" or "a
skill for writing text", not the name of a specific skill or script. That file
already tells agents to use a skill that matches the task, so naming a skill
adds nothing.
