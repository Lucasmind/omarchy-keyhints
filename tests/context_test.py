"""bin/keyhints-context against fixture configs. Run: python3 -I tests/context_test.py"""
import importlib.machinery
import importlib.util
import os
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
FIXTURES = HERE / "fixtures"

# Point HOME at a temp dir holding the fixture herdr config before loading.
home = Path(tempfile.mkdtemp())
(home / ".config/herdr").mkdir(parents=True)
(home / ".config/herdr/config.toml").write_text((FIXTURES / "herdr-config.toml").read_text())
os.environ["HOME"] = str(home)
os.environ["XDG_CACHE_HOME"] = str(home / ".cache")

loader = importlib.machinery.SourceFileLoader("ctx", str(HERE.parent / "bin/keyhints-context"))
spec = importlib.util.spec_from_loader("ctx", loader)
ctx = importlib.util.module_from_spec(spec)
loader.exec_module(ctx)
ctx.ghostty_binds = lambda: (FIXTURES / "ghostty-keybinds.txt").read_text()

passed = 0


def test(fn):
    global passed
    fn()
    passed += 1
    print("ok -", fn.__name__.replace("_", " "))


@test
def key_labels():
    assert ctx.key_label("ctrl+shift+arrow_left") == "Ctrl Shift ←"
    assert ctx.key_label("alt+enter") == "Alt Enter"


@test
def families_collapse_to_the_largest_modifier_group():
    assert ctx.family_label(["ctrl+alt+arrow_up", "ctrl+alt+arrow_down", "super+ctrl+["]) == "Ctrl Alt ↑↓"
    assert ctx.family_label(["ctrl+=", "ctrl+-"]) == "Ctrl = / -"


@test
def ghostty_hints_from_live_keybinds():
    hints = {h["desc"]: h["keys"] for h in ctx.ghostty_hints(inside_herdr=False)}
    assert hints["New tab"] == "Ctrl Shift T"
    assert hints["Font size"] == "Ctrl = / -"
    inside = {h["desc"] for h in ctx.ghostty_hints(inside_herdr=True)}
    assert "New tab" not in inside and "Copy" in inside  # herdr owns tabs and splits


@test
def herdr_hints_prefer_direct_chords_over_prefix():
    hints = {h["desc"]: h["keys"] for h in ctx.herdr_hints()}
    assert hints["Split pane"] == "Alt Enter"
    assert hints["New tab"] == "Ctrl Space, C"
    assert hints["Prev / next tab"] == "Alt ←→"


@test
def packs_match_by_window_class():
    packs = ctx.load_packs()
    browser = next(p for p in packs if p["id"] == "browser")
    assert ctx.matches(browser, "chromium", "")
    assert not ctx.matches(browser, "com.mitchellh.ghostty", "")


print(f"{passed} passed")
