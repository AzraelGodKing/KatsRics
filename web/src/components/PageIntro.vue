<script setup>
defineProps({
  kicker: { type: String, default: "Catalog" },
  title: String,
  lede: String,
  stats: { type: Array, default: () => [] },
});
</script>

<template>
  <section class="page-intro">
    <p class="kicker">{{ kicker }}</p>
    <h1>{{ title }}</h1>
    <p class="lede">{{ lede }}</p>
    <div class="meta-row">
      <span v-for="stat in stats" :key="stat.label" class="stat-card">
        <b>{{ stat.value }}</b>
        <em>{{ stat.label }}</em>
      </span>
    </div>
    <div class="hint">
      <span class="hint-label">Chat</span>
      <div class="hint-body">
        <slot />
      </div>
    </div>
  </section>
</template>
