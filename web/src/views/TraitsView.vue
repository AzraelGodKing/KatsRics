<script setup>
import { computed, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import PageIntro from "../components/PageIntro.vue";
import DataTable from "../components/DataTable.vue";
import { loadJson, fmt } from "../lib/data";
import { useSort } from "../composables/useSort";
import { useStickyOffsets } from "../composables/useStickyOffsets";

const route = useRoute();
const router = useRouter();
const { sync } = useStickyOffsets();

const traits = ref([]);
const xenotypes = ref([]);
const tab = computed({
  get: () => (route.query.tab === "xenotypes" ? "xenotypes" : "traits"),
  set: (v) => router.replace({ query: v === "xenotypes" ? { tab: "xenotypes" } : {} }),
});

const tq = ref("");
const tmod = ref("");
const tAddable = ref(false);
const tRemovable = ref(false);
const tBypass = ref(false);
const xq = ref("");
const xrace = ref("");
const xEnabled = ref(true);

const tSort = useSort("name");
const xSort = useSort("xenotype");

const traitCols = [
  { key: "name", label: "Trait" },
  { key: "effects", label: "Effects", thClass: "hide-sm" },
  { key: "degree", label: "Degree", thClass: "hide-sm", align: "right" },
  { key: "addPrice", label: "Add $", align: "right" },
  { key: "removePrice", label: "Remove $", align: "right" },
  { key: "flags", label: "Flags" },
  { key: "mod", label: "Mod", thClass: "hide-sm" },
];

const xenoCols = [
  { key: "xenotype", label: "Xenotype" },
  { key: "race", label: "Race" },
  { key: "price", label: "Price", align: "right" },
  { key: "enabled", label: "Enabled" },
  { key: "modActive", label: "Mod active", thClass: "hide-sm" },
];

onMounted(async () => {
  const [tRows, xRows] = await Promise.all([loadJson("traits"), loadJson("xenotypes")]);
  traits.value = tRows.map((r) => ({
    name: r[0],
    defName: r[1],
    degree: r[2],
    addPrice: r[3],
    removePrice: r[4],
    canAdd: !!r[5],
    canRemove: !!r[6],
    bypassLimit: !!r[7],
    mod: r[8],
    modActive: !!r[9],
    effects: r[10] || "",
    description: r[11] || "",
  }));
  xenotypes.value = xRows.map((r) => ({
    race: r[0],
    raceDef: r[1],
    xenotype: r[2],
    price: r[3],
    xenotypeEnabled: !!r[4],
    raceEnabled: !!r[5],
    modActive: !!r[6],
  }));
});

watch(tab, () => sync());

const mods = computed(() => [...new Set(traits.value.map((r) => r.mod))].sort());
const races = computed(() => [...new Set(xenotypes.value.map((r) => r.race))].sort());
const addableCount = computed(() => traits.value.filter((r) => r.canAdd).length);
const enabledXenos = computed(() => xenotypes.value.filter((r) => r.xenotypeEnabled && r.raceEnabled).length);

const stats = computed(() => [
  { value: fmt(traits.value.length), label: "traits" },
  { value: fmt(addableCount.value), label: "addable" },
  { value: fmt(xenotypes.value.length), label: "xenotype prices" },
  { value: fmt(enabledXenos.value), label: "enabled" },
  { value: String(races.value.length), label: "races" },
]);

function traitFlags(r) {
  return [r.canAdd && "ADD", r.canRemove && "REMOVE", r.bypassLimit && "BYPASS"].filter(Boolean).join(" ") || "";
}

const filteredTraits = computed(() => {
  const term = tq.value.trim().toLowerCase();
  let list = traits.value.filter((r) =>
    (!tmod.value || r.mod === tmod.value) &&
    (!tAddable.value || r.canAdd) &&
    (!tRemovable.value || r.canRemove) &&
    (!tBypass.value || r.bypassLimit) &&
    (!term ||
      r.name.toLowerCase().includes(term) ||
      r.defName.toLowerCase().includes(term) ||
      r.effects.toLowerCase().includes(term) ||
      r.description.toLowerCase().includes(term)),
  );
  list = tSort.sorted(list, (r) => (tSort.sortKey.value === "flags" ? traitFlags(r) || "~" : r[tSort.sortKey.value]));
  return list.map((r, i) => ({ ...r, _key: `${r.defName}-${r.degree}-${i}` }));
});

const filteredXenos = computed(() => {
  const term = xq.value.trim().toLowerCase();
  let list = xenotypes.value.filter((r) =>
    (!xrace.value || r.race === xrace.value) &&
    (!xEnabled.value || (r.xenotypeEnabled && r.raceEnabled)) &&
    (!term ||
      r.race.toLowerCase().includes(term) ||
      r.raceDef.toLowerCase().includes(term) ||
      r.xenotype.toLowerCase().includes(term)),
  );
  list = xSort.sorted(list, (r) => {
    if (xSort.sortKey.value === "enabled") return r.xenotypeEnabled && r.raceEnabled ? 1 : 0;
    return r[xSort.sortKey.value];
  });
  return list.map((r) => ({
    ...r,
    ok: r.xenotypeEnabled && r.raceEnabled,
    _disabled: !(r.xenotypeEnabled && r.raceEnabled),
    _key: `${r.raceDef}-${r.xenotype}`,
  }));
});
</script>

<template>
  <div class="page-shell">
    <PageIntro
      kicker="Channel 02"
      title="Traits & Xenotypes"
      lede="Pawn traits and xenotype prices from the live CAP ChatInteractive config — including what each trait does."
      :stats="stats"
    >
      <template v-if="tab === 'traits'">
        Look up with <code>!trait &lt;name&gt;</code> or <code>!lookup trait &lt;name&gt;</code>.
        Add <code>!addtrait &lt;trait&gt;</code> · remove <code>!removetrait &lt;trait&gt;</code> ·
        replace <code>!replacetrait &lt;old&gt; &lt;new&gt;</code>.
      </template>
      <template v-else>
        List xenotypes for a race with <code>!xenotypes &lt;race&gt;</code>
        (e.g. <code>!xenotypes human</code>). Prices apply when buying a pawn via <code>!pawn</code> / <code>!buy</code>.
      </template>
    </PageIntro>

    <div class="tabs" role="tablist">
      <button type="button" :class="{ active: tab === 'traits' }" role="tab" @click="tab = 'traits'">Traits</button>
      <button type="button" :class="{ active: tab === 'xenotypes' }" role="tab" @click="tab = 'xenotypes'">Xenotypes</button>
    </div>

    <div :class="['panel', { active: tab === 'traits' }]">
      <div class="controls">
        <input v-model="tq" type="search" placeholder="Search traits… (name, effect, or description)" aria-label="Search traits">
        <select v-model="tmod" aria-label="Mod">
          <option value="">All mods</option>
          <option v-for="m in mods" :key="m" :value="m">{{ m }}</option>
        </select>
        <label class="toggle"><input v-model="tAddable" type="checkbox"> Addable only</label>
        <label class="toggle"><input v-model="tRemovable" type="checkbox"> Removable only</label>
        <label class="toggle"><input v-model="tBypass" type="checkbox"> Bypass limit only</label>
        <span class="count">{{ fmt(filteredTraits.length) }} trait{{ filteredTraits.length === 1 ? "" : "s" }}</span>
      </div>
      <DataTable
        :columns="traitCols"
        :rows="filteredTraits"
        empty="No traits match your search."
        :sort-key="tSort.sortKey"
        :sort-dir="tSort.sortDir"
        @sort="tSort.toggleSort"
      >
        <template #row="{ row }">
          <td class="trait-cell">
            <b>{{ row.name }}</b>
            <span class="def">{{ row.defName }}</span>
            <span v-if="row.description" class="desc">{{ row.description }}</span>
            <span v-if="row.effects" class="effects">{{ row.effects }}</span>
          </td>
          <td class="cat hide-sm">
            <template v-if="row.effects">{{ row.effects }}</template>
            <span v-else class="off">—</span>
          </td>
          <td class="num hide-sm">{{ row.degree }}</td>
          <td class="price">{{ fmt(row.addPrice) }}</td>
          <td class="price">{{ fmt(row.removePrice) }}</td>
          <td class="flags">
            <span v-if="row.canAdd" class="flag">ADD</span>
            <span v-if="row.canRemove" class="flag">REMOVE</span>
            <span v-if="row.bypassLimit" class="flag">BYPASS</span>
            <span v-if="!row.canAdd && !row.canRemove && !row.bypassLimit" class="off">—</span>
          </td>
          <td class="mod hide-sm">{{ row.mod }}</td>
        </template>
      </DataTable>
    </div>

    <div :class="['panel', { active: tab === 'xenotypes' }]">
      <div class="controls">
        <input v-model="xq" type="search" placeholder="Search xenotypes… (race or xenotype)" aria-label="Search xenotypes">
        <select v-model="xrace" aria-label="Race">
          <option value="">All races</option>
          <option v-for="r in races" :key="r" :value="r">{{ r }}</option>
        </select>
        <label class="toggle"><input v-model="xEnabled" type="checkbox"> Enabled only</label>
        <span class="count">{{ fmt(filteredXenos.length) }} xenotype{{ filteredXenos.length === 1 ? "" : "s" }}</span>
      </div>
      <DataTable
        :columns="xenoCols"
        :rows="filteredXenos"
        empty="No xenotypes match your search."
        :sort-key="xSort.sortKey"
        :sort-dir="xSort.sortDir"
        @sort="xSort.toggleSort"
      >
        <template #row="{ row }">
          <td><b>{{ row.xenotype }}</b></td>
          <td class="cat">{{ row.race }}</td>
          <td class="price">{{ fmt(row.price) }}</td>
          <td class="flags">
            <span v-if="row.ok" class="flag">YES</span>
            <span v-else class="off">NO</span>
          </td>
          <td class="mod hide-sm">
            <span v-if="row.modActive" class="flag">YES</span>
            <span v-else class="off">NO</span>
          </td>
        </template>
      </DataTable>
    </div>
  </div>
</template>
