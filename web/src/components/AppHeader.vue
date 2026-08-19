<script setup>
import { computed } from "vue";
import { useRoute } from "vue-router";
import { currentTheme, toggleTheme } from "../composables/useTheme";
import { ref } from "vue";

const route = useRoute();
const theme = ref(currentTheme());

function onToggle() {
  toggleTheme();
  theme.value = currentTheme();
}

const links = [
  { to: "/", label: "Store", match: "store" },
  { to: "/traits", label: "Traits", match: "traits" },
  { to: "/backstories", label: "Backstories", match: "backstories" },
  { to: "/events", label: "Events", match: "events" },
];

const isDark = computed(() => theme.value === "dark");
</script>

<template>
  <header class="topbar" ref="topbar">
    <router-link class="brand" to="/">
      <span class="brand-mark">Kat's <span>RICS</span></span>
      <span class="brand-sub">Chat coin catalog</span>
    </router-link>
    <div class="topbar-end">
      <nav class="nav" aria-label="Primary">
        <router-link
          v-for="link in links"
          :key="link.to"
          :to="link.to"
          :class="{ active: route.name === link.match }"
        >{{ link.label }}</router-link>
      </nav>
      <button
        type="button"
        class="theme-toggle"
        :aria-pressed="isDark ? 'true' : 'false'"
        :aria-label="isDark ? 'Switch to light mode' : 'Switch to dark mode'"
        @click="onToggle"
      >
        <span class="theme-label">{{ isDark ? "Light" : "Dark" }}</span>
      </button>
    </div>
  </header>
</template>
