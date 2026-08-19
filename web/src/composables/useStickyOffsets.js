import { onMounted, onBeforeUnmount } from "vue";

export function useStickyOffsets() {
  let observer;

  function activeControls() {
    return document.querySelector(".panel.active .controls") || document.querySelector(".controls");
  }

  function sync() {
    const root = document.documentElement;
    const topbar = document.querySelector(".topbar");
    const controls = activeControls();
    if (topbar) {
      root.style.setProperty("--topbar-h", `${Math.ceil(topbar.getBoundingClientRect().height)}px`);
    }
    if (controls) {
      const h = controls.getBoundingClientRect().height;
      if (h > 0) root.style.setProperty("--controls-h", `${Math.ceil(h)}px`);
    }
  }

  onMounted(() => {
    sync();
    window.addEventListener("resize", sync);
    if (typeof ResizeObserver !== "undefined") {
      observer = new ResizeObserver(sync);
      const topbar = document.querySelector(".topbar");
      if (topbar) observer.observe(topbar);
      document.querySelectorAll(".controls").forEach((el) => observer.observe(el));
    }
  });

  onBeforeUnmount(() => {
    window.removeEventListener("resize", sync);
    observer?.disconnect();
  });

  return { sync };
}
