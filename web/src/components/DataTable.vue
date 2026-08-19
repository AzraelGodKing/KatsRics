<script setup>
defineProps({
  columns: { type: Array, required: true },
  rows: { type: Array, required: true },
  empty: { type: String, default: "No results." },
  sortKey: { type: [String, Number], default: null },
  sortDir: { type: Number, default: 1 },
});

const emit = defineEmits(["sort"]);
</script>

<template>
  <main>
    <div class="table-shell">
      <table>
        <thead>
          <tr>
            <th
              v-for="col in columns"
              :key="col.key"
              :class="col.thClass"
              :style="col.align === 'right' ? { textAlign: 'right' } : null"
              @click="emit('sort', col.key)"
            >
              {{ col.label }}
              <span class="arrow">{{ sortKey === col.key ? (sortDir === 1 ? "▲" : "▼") : "" }}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(row, i) in rows" :key="row._key ?? i" :class="{ disabled: row._disabled }">
            <slot name="row" :row="row" />
          </tr>
        </tbody>
      </table>
      <div v-if="!rows.length" class="empty">{{ empty }}</div>
    </div>
  </main>
</template>
