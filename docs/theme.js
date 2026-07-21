(function () {
  const KEY = "katsrics-theme";
  const root = document.documentElement;

  function current() {
    return root.getAttribute("data-theme") === "light" ? "light" : "dark";
  }

  function apply(theme) {
    const next = theme === "light" ? "light" : "dark";
    root.setAttribute("data-theme", next);
    try { localStorage.setItem(KEY, next); } catch (_) {}
    syncButton();
  }

  function syncButton() {
    const btn = document.getElementById("themeToggle");
    if (!btn) return;
    const dark = current() === "dark";
    btn.setAttribute("aria-pressed", dark ? "true" : "false");
    btn.setAttribute("aria-label", dark ? "Switch to light mode" : "Switch to dark mode");
    const label = btn.querySelector(".theme-label");
    if (label) label.textContent = dark ? "Light" : "Dark";
  }

  function init() {
    const btn = document.getElementById("themeToggle");
    if (!btn) return;
    syncButton();
    btn.addEventListener("click", () => {
      apply(current() === "dark" ? "light" : "dark");
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
