<script setup>
import { computed, onMounted, ref, watch } from "vue";
import PageIntro from "../components/PageIntro.vue";
import DataTable from "../components/DataTable.vue";
import { loadJson, fmt } from "../lib/data";
import { useSort } from "../composables/useSort";
import { useStickyOffsets } from "../composables/useStickyOffsets";

const { sync } = useStickyOffsets();
const items = ref([]);
const q = ref("");
const cat = ref("");
const mod = ref("");
const cmd = ref("");
const enabledOnly = ref(true);
const { sortKey, sortDir, toggleSort, sorted } = useSort("name");

const columns = [
  { key: "name", label: "Item" },
  { key: "category", label: "Category", thClass: "hide-sm" },
  { key: "price", label: "Price", align: "right" },
  { key: "qty", label: "Max Qty", thClass: "hide-sm", align: "right" },
  { key: "commands", label: "Commands" },
  { key: "mod", label: "Mod", thClass: "hide-sm" },
];

onMounted(async () => {
  const rows = await loadJson("items");
  items.value = rows.map((r) => ({
    category: r[0],
    name: r[1],
    defName: r[2],
    price: r[3],
    qty: r[4],
    usable: !!r[5],
    equippable: !!r[6],
    wearable: !!r[7],
    mod: r[8],
    enabled: !!r[9],
  }));
});

watch([q, cat, mod, cmd, enabledOnly], () => sync());

const cats = computed(() => [...new Set(items.value.map((r) => r.category))].sort());
const mods = computed(() => [...new Set(items.value.map((r) => r.mod))].sort());
const purchasable = computed(() => items.value.filter((r) => r.enabled).length);

const stats = computed(() => [
  { value: fmt(items.value.length), label: "items" },
  { value: fmt(purchasable.value), label: "purchasable" },
  { value: String(cats.value.length), label: "categories" },
  { value: String(mods.value.length), label: "mods" },
]);

function cmdLabel(r) {
  return [r.usable && "USE", r.equippable && "EQUIP", r.wearable && "WEAR"].filter(Boolean).join(" ") || "";
}

function matchesCmd(r) {
  if (!cmd.value) return true;
  if (cmd.value === "use") return r.usable;
  if (cmd.value === "equip") return r.equippable;
  if (cmd.value === "wear") return r.wearable;
  if (cmd.value === "any") return r.usable || r.equippable || r.wearable;
  if (cmd.value === "none") return !(r.usable || r.equippable || r.wearable);
  return true;
}

const filtered = computed(() => {
  const term = q.value.trim().toLowerCase();
  let list = items.value.filter((r) =>
    (!enabledOnly.value || r.enabled) &&
    (!cat.value || r.category === cat.value) &&
    (!mod.value || r.mod === mod.value) &&
    matchesCmd(r) &&
    (!term || r.name.toLowerCase().includes(term) || r.defName.toLowerCase().includes(term)),
  );
  list = sorted(list, (r) => (sortKey.value === "commands" ? cmdLabel(r) || "~" : r[sortKey.value]));
  return list.map((r) => ({ ...r, _disabled: !r.enabled, _key: r.defName }));
});
</script>

<template>
  <div class="page-shell">
    <PageIntro title="Store" lede="Everything you can buy with chat coins — search, filter, and sort the live catalog." :stats="stats">
      Buy with <code>!buy &lt;item&gt;</code> (e.g. <code>!buy thrumbo</code>).
      <span class="flag">USE</span> → <code>!use</code>,
      <span class="flag">EQUIP</span> → <code>!equip</code>,
      <span class="flag">WEAR</span> → <code>!wear</code>.
      Balance <code>!bal</code> · price <code>!pricecheck &lt;item&gt;</code> ·
      <code>!lookup item &lt;name&gt;</code>.
    </PageIntro>

    <div class="controls">
      <input v-model="q" type="search" placeholder="Search items… (name or defName)" aria-label="Search items">
      <select v-model="cat" aria-label="Category">
        <option value="">All categories</option>
        <option v-for="c in cats" :key="c" :value="c">{{ c }}</option>
      </select>
      <select v-model="mod" aria-label="Mod">
        <option value="">All mods</option>
        <option v-for="m in mods" :key="m" :value="m">{{ m }}</option>
      </select>
      <select v-model="cmd" aria-label="Command type">
        <option value="">All commands</option>
        <option value="use">USE</option>
        <option value="equip">EQUIP</option>
        <option value="wear">WEAR</option>
        <option value="any">Any command</option>
        <option value="none">No commands</option>
      </select>
      <label class="toggle"><input v-model="enabledOnly" type="checkbox"> Purchasable only</label>
      <span class="count">{{ fmt(filtered.length) }} item{{ filtered.length === 1 ? "" : "s" }}</span>
    </div>

    <DataTable
      :columns="columns"
      :rows="filtered"
      empty="No items match your search."
      :sort-key="sortKey"
      :sort-dir="sortDir"
      @sort="toggleSort"
    >
      <template #row="{ row }">
        <td><b>{{ row.name }}</b></td>
        <td class="cat hide-sm">{{ row.category }}</td>
        <td class="price">{{ fmt(row.price) }}</td>
        <td class="qty hide-sm">{{ fmt(row.qty) }}</td>
        <td class="flags">
          <span v-if="row.usable" class="flag">USE</span>
          <span v-if="row.equippable" class="flag">EQUIP</span>
          <span v-if="row.wearable" class="flag">WEAR</span>
          <span v-if="!row.enabled" class="off">DISABLED</span>
        </td>
        <td class="mod hide-sm">{{ row.mod }}</td>
      </template>
    </DataTable>
  </div>
</template>
