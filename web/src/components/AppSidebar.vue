<script setup>
import { computed, ref } from "vue";
import { useRoute } from "vue-router";
import { currentTheme, toggleTheme } from "../composables/useTheme";

const route = useRoute();
const theme = ref(currentTheme());

function onToggle() {
  toggleTheme();
  theme.value = currentTheme();
}

const links = [
  { to: "/", label: "Store", code: "01", match: "store" },
  { to: "/traits", label: "Traits", code: "02", match: "traits" },
  { to: "/backstories", label: "Lore", code: "03", match: "backstories" },
  { to: "/events", label: "Events", code: "04", match: "events" },
];

const isDark = computed(() => theme.value === "dark");
</script>

<template>
  <aside class="rail">
    <router-link class="brand" to="/">
      <span class="brand-mark">KAT</span>
      <span class="brand-word">RICS</span>
      <span class="brand-sub">Chat coin catalog</span>
    </router-link>

    <p class="rail-kicker">Broadcast index</p>
    <nav class="nav" aria-label="Primary">
      <router-link
        v-for="link in links"
        :key="link.to"
        :to="link.to"
        :class="{ active: route.name === link.match }"
      >
        <span class="nav-code">{{ link.code }}</span>
        <span class="nav-label">{{ link.label }}</span>
      </router-link>
    </nav>

    <div class="rail-end">
      <div class="live-pill" aria-hidden="true">
        <span class="live-dot"></span>
        Live colony feed
      </div>
      <button
        type="button"
        class="theme-toggle"
        :aria-pressed="isDark ? 'true' : 'false'"
        :aria-label="isDark ? 'Switch to light mode' : 'Switch to dark mode'"
        @click="onToggle"
      >
        {{ isDark ? "Day side" : "Night side" }}
      </button>
    </div>
  </aside>
</template>
