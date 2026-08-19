<script setup>
import AppSidebar from "./components/AppSidebar.vue";
import AppFooter from "./components/AppFooter.vue";
import { useStickyOffsets } from "./composables/useStickyOffsets";

useStickyOffsets();
</script>

<template>
  <div class="app-frame">
    <AppSidebar />
    <div class="stage">
      <router-view />
      <AppFooter />
    </div>
  </div>
</template>
