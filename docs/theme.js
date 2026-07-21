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

  /** Keep sticky thead flush under the filter bar (height varies when controls wrap). */
  function activeControls() {
    return document.querySelector(".panel.active .controls") || document.querySelector(".controls");
  }

  function syncStickyOffsets() {
    const rootStyle = root.style;
    const topbar = document.querySelector(".topbar");
    const controls = activeControls();
    if (topbar) {
      rootStyle.setProperty("--topbar-h", Math.ceil(topbar.getBoundingClientRect().height) + "px");
    }
    if (controls) {
      const h = controls.getBoundingClientRect().height;
      if (h > 0) rootStyle.setProperty("--controls-h", Math.ceil(h) + "px");
    }
  }

  function initStickyOffsets() {
    syncStickyOffsets();
    window.addEventListener("resize", syncStickyOffsets);

    if (typeof ResizeObserver !== "undefined") {
      const ro = new ResizeObserver(syncStickyOffsets);
      const topbar = document.querySelector(".topbar");
      if (topbar) ro.observe(topbar);
      document.querySelectorAll(".controls").forEach((el) => ro.observe(el));
    }

    document.querySelectorAll(".panel").forEach((panel) => {
      new MutationObserver(syncStickyOffsets).observe(panel, {
        attributes: true,
        attributeFilter: ["class"],
      });
    });
  }

  function boot() {
    init();
    initStickyOffsets();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
