# 💤 LazyVim

This configuration is focused on **Go** and **Python** for backend work with a conservative, professional setup.

## ✅ Supported languages (standard)
- Go: `gopls`, `goimports`, `gofumpt`, `golangci-lint`, `delve`
- Python: `pyright`, `ruff`, `debugpy`

## ✨ Why this is “standard & professional”
- Uses official language servers (`gopls`, `pyright`).
- Uses current, widely adopted backend tooling for formatting, linting, and import management.
- Keeps Python environment detection local and fast by preferring in-project virtual environments.
- Avoids expensive workspace scans during startup.

## 🐍 Python environment behavior
- Python environment switching is handled by `venv-selector.nvim` using a picker window.
- The picker supports standard local venvs and built-in searches for `pyenv`, `pipenv`, and `uv` workflows.
- The last selected environment is cached per project and re-activated automatically when you reopen that project.
- `:VenvSelect` opens the picker. `:VenvSelectCached` restores the cached environment manually if needed.
- `uv init` alone does not create a virtual environment. For `uv` projects, create the interpreter with `uv venv` or `uv sync` so `.venv/bin/python` exists.

Recommended practice for Django and FastAPI projects:
1. Create the environment inside the project root.
2. Use `.venv` as the default directory name.
3. Use `:VenvSelect` for nonstandard environments such as `pyenv` or `pipenv`.
4. Let `pyright`, `ruff`, and `debugpy` use the selected interpreter automatically.

System requirements for the picker workflow:
1. Install `fd` or `fdfind` so the selector can search efficiently.
2. Install `pyenv`, `pipenv`, or `uv` if you want those environment sources to appear in the picker.

## ➕ Add another language later (easy)
1) Add the LazyVim language extra in [lua/config/lazy.lua](lua/config/lazy.lua#L21):
	- Example: `{ import = "lazyvim.plugins.extras.lang.rust" }`
2) Add any tools you want installed in [lua/plugins/lsp.lua](lua/plugins/lsp.lua#L35).

Refer to the [LazyVim documentation](https://lazyvim.github.io/installation) for more details.
