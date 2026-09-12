<script setup>
import { computed, onMounted, ref } from "vue";
import PageIntro from "../components/PageIntro.vue";
import DataTable from "../components/DataTable.vue";
import { loadJson, fmt } from "../lib/data";
import { useSort } from "../composables/useSort";

const rows = ref([]);
const q = ref("");
const category = ref("");
const mod = ref("");
const architeOnly = ref(false);
const { sortKey, sortDir, toggleSort, sorted } = useSort("label");

const columns = [
  { key: "label", label: "Gene" },
  { key: "category", label: "Category" },
  { key: "biostatCpx", label: "Cpx", align: "right" },
  { key: "biostatMet", label: "Met", align: "right" },
  { key: "biostatArc", label: "Arc", align: "right" },
  { key: "estCost", label: "Est. $", align: "right" },
  { key: "mod", label: "Source", thClass: "hide-sm" },
];

function estimateCost(cpx, met, arc) {
  return Math.abs(cpx) * 100 + Math.abs(met) * 250 + Math.abs(arc) * 1000;
}

onMounted(async () => {
  const data = await loadJson("genes");
  rows.value = data.map((r) => ({
    label: r[0],
    defName: r[1],
    category: r[2] || "Unknown",
    categoryKey: r[3] || "",
    biostatCpx: r[4] || 0,
    biostatMet: r[5] || 0,
    biostatArc: r[6] || 0,
    marketFactor: r[7] ?? 1,
    fromTemplate: !!r[8],
    mod: r[9],
    description: r[10] || "",
    estCost: estimateCost(r[4] || 0, r[5] || 0, r[6] || 0),
  }));
});

const mods = computed(() => [...new Set(rows.value.map((r) => r.mod))].sort());
const categories = computed(() => [...new Set(rows.value.map((r) => r.category))].sort());
const architeCount = computed(() => rows.value.filter((r) => r.biostatArc > 0).length);

const stats = computed(() => [
  { value: fmt(rows.value.length), label: "genes" },
  { value: fmt(architeCount.value), label: "archite" },
  { value: String(categories.value.length), label: "categories" },
  { value: String(mods.value.length), label: "sources" },
]);

const filtered = computed(() => {
  const term = q.value.trim().toLowerCase();
  let list = rows.value.filter(
    (r) =>
      (!category.value || r.category === category.value) &&
      (!mod.value || r.mod === mod.value) &&
      (!architeOnly.value || r.biostatArc > 0) &&
      (!term ||
        r.label.toLowerCase().includes(term) ||
        r.defName.toLowerCase().includes(term) ||
        r.description.toLowerCase().includes(term) ||
        r.category.toLowerCase().includes(term)),
  );
  list = sorted(list, (r) => r[sortKey.value]);
  return list.map((r) => ({ ...r, _key: r.defName }));
});
</script>

<template>
  <div class="page-shell">
    <PageIntro
      kicker="Channel 07"
      title="Genes"
      lede="Read-only catalog of Biotech (and mod) genes from RimWorld defs. Chat uses !geneedit — not buy-by-name."
      :stats="stats"
    >
      Geneedit rates (from live settings):
      <code>100</code> / complexity,
      <code>250</code> / metabolism,
      <code>1000</code> / archite.
      Est. $ is abs(cpx)×100 + abs(met)×250 + abs(arc)×1000.
    </PageIntro>

    <div class="controls">
      <input v-model="q" type="search" placeholder="Search label, defName, or description…" aria-label="Search genes">
      <select v-model="category" aria-label="Category">
        <option value="">All categories</option>
        <option v-for="c in categories" :key="c" :value="c">{{ c }}</option>
      </select>
      <select v-model="mod" aria-label="Source">
        <option value="">All sources</option>
        <option v-for="m in mods" :key="m" :value="m">{{ m }}</option>
      </select>
      <label class="toggle"><input v-model="architeOnly" type="checkbox"> Archite only</label>
      <span class="count">{{ fmt(filtered.length) }} gene{{ filtered.length === 1 ? "" : "s" }}</span>
    </div>

    <DataTable
      :columns="columns"
      :rows="filtered"
      empty="No genes match your search."
      :sort-key="sortKey"
      :sort-dir="sortDir"
      @sort="toggleSort"
    >
      <template #row="{ row }">
        <td class="title-cell">
          <b>{{ row.label }}</b>
          <span class="def">{{ row.defName }}</span>
          <span v-if="row.description" class="desc">{{ row.description }}</span>
        </td>
        <td>
          <span class="slot-pill" :class="{ adult: row.biostatArc > 0 }">{{ row.category }}</span>
        </td>
        <td class="num">{{ row.biostatCpx }}</td>
        <td class="num">{{ row.biostatMet }}</td>
        <td class="num">{{ row.biostatArc }}</td>
        <td class="num">{{ fmt(row.estCost) }}</td>
        <td class="mod hide-sm">{{ row.mod }}</td>
      </template>
    </DataTable>
  </div>
</template>
