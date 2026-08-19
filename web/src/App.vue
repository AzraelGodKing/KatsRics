<script setup>
import AppHeader from "./components/AppHeader.vue";
import AppFooter from "./components/AppFooter.vue";
import { useStickyOffsets } from "./composables/useStickyOffsets";

useStickyOffsets();
</script>

<template>
  <AppHeader />
  <router-view />
  <AppFooter />
</template>
