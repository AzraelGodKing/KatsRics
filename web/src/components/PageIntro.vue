<script setup>
defineProps({
  title: String,
  lede: String,
  stats: { type: Array, default: () => [] },
});
</script>

<template>
  <section class="page-intro">
    <h1>{{ title }}</h1>
    <p class="lede">{{ lede }}</p>
    <div class="meta-row">
      <span v-for="stat in stats" :key="stat.label">
        <b>{{ stat.value }}</b> {{ stat.label }}
      </span>
    </div>
    <div class="hint">
      <span class="hint-label">Commands</span>
      <div class="hint-body">
        <slot />
      </div>
    </div>
  </section>
</template>
