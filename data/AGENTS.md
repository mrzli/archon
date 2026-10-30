# VS Code Settings

In `home/.config/Code/User/settings.json`, order general top-level settings
alphabetically by setting key. Place language-specific blocks after all general
settings. Order these blocks alphabetically by language identifier, such as
`[markdown]` before `[typescript]`.

# Global Agent Instructions

Keep `home/.codex/AGENTS.md` independent of any skill collection. Describe the
activity, such as reviewing a change or writing a handoff, not the name of a
skill that performs it. That file already tells agents to use a skill that
matches the task, so naming one adds nothing.
