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

const commands = ref([]);
const addon = ref([]);
const tab = computed({
  get: () => (route.query.tab === "addon" ? "addon" : "rics"),
  set: (v) => router.replace({ query: v === "addon" ? { tab: "addon" } : {} }),
});

const rq = ref("");
const rperm = ref("");
const rEnabled = ref(true);
const aq = ref("");
const ainteg = ref("");
const aisekaiOnly = ref(false);

const rSort = useSort("key");
const aSort = useSort("usage");

const ricsCols = [
  { key: "key", label: "Command" },
  { key: "label", label: "Label", thClass: "hide-sm" },
  { key: "description", label: "Description" },
  { key: "permission", label: "Permission" },
  { key: "cost", label: "Cost", thClass: "hide-sm", align: "right" },
  { key: "enabled", label: "Status" },
];

const addonCols = [
  { key: "usage", label: "Usage" },
  { key: "description", label: "Description" },
  { key: "integration", label: "Integration" },
];

onMounted(async () => {
  const [cRows, aRows] = await Promise.all([loadJson("commands"), loadJson("addon-commands")]);
  commands.value = cRows.map((r) => ({
    key: r[0],
    label: r[1],
    description: r[2],
    permission: r[3],
    cost: r[4],
    cooldown: r[5],
    enabled: !!r[6],
    supportsCost: !!r[7],
    alias: r[8] || "",
  }));
  addon.value = aRows.map((r) => ({
    key: r[0],
    usage: r[1],
    description: r[2],
    integration: r[3],
  }));
});

watch(tab, () => sync());

const perms = computed(() => [...new Set(commands.value.map((r) => r.permission))].sort());
const integs = computed(() => [...new Set(addon.value.map((r) => r.integration))].sort());
const rEnabledCount = computed(() => commands.value.filter((r) => r.enabled).length);
const isekaiAddonCount = computed(() => addon.value.filter((r) => r.integration === "ISEKAI RPG LEVELING").length);

const stats = computed(() => [
  { value: fmt(commands.value.length), label: "RICS cmds" },
  { value: fmt(rEnabledCount.value), label: "enabled" },
  { value: fmt(addon.value.length), label: "addon cmds" },
  { value: fmt(isekaiAddonCount.value), label: "isekai cmds" },
]);

const filteredRics = computed(() => {
  const term = rq.value.trim().toLowerCase();
  let list = commands.value.filter((r) =>
    (!rEnabled.value || r.enabled) &&
    (!rperm.value || r.permission === rperm.value) &&
    (!term ||
      r.key.toLowerCase().includes(term) ||
      r.label.toLowerCase().includes(term) ||
      r.description.toLowerCase().includes(term) ||
      (r.alias && r.alias.toLowerCase().includes(term))),
  );
  list = rSort.sorted(list, (r) => {
    if (rSort.sortKey.value === "enabled") return r.enabled ? 1 : 0;
    return r[rSort.sortKey.value];
  });
  return list.map((r) => ({ ...r, _disabled: !r.enabled, _key: r.key }));
});

const filteredAddon = computed(() => {
  const term = aq.value.trim().toLowerCase();
  let list = addon.value.filter((r) =>
    (!aisekaiOnly.value || r.integration === "ISEKAI RPG LEVELING") &&
    (!ainteg.value || r.integration === ainteg.value) &&
    (!term ||
      r.key.toLowerCase().includes(term) ||
      r.usage.toLowerCase().includes(term) ||
      r.description.toLowerCase().includes(term) ||
      r.integration.toLowerCase().includes(term)),
  );
  list = aSort.sorted(list, (r) => r[aSort.sortKey.value]);
  return list.map((r) => ({ ...r, _key: r.key }));
});
</script>

<template>
  <div class="page-shell">
    <PageIntro
      kicker="Channel 05"
      title="Commands"
      lede="Every chat command from RICS core and the RICS Addon (including Isekai RPG Leveling)."
      :stats="stats"
    >
      <template v-if="tab === 'rics'">
        Core RICS commands from live <code>CommandSettings.json</code>.
        Cost/permission vary by colony config.
      </template>
      <template v-else>
        Addon commands from
        <a href="https://steamcommunity.com/sharedfiles/filedetails/?id=3760183125" target="_blank" rel="noopener">RICS Addon</a>.
        Isekai: <code>!isekai</code> / <code>!constellation unlock|path|learn</code>.
      </template>
    </PageIntro>

    <div class="tabs" role="tablist">
      <button type="button" :class="{ active: tab === 'rics' }" role="tab" @click="tab = 'rics'">RICS Core</button>
      <button type="button" :class="{ active: tab === 'addon' }" role="tab" @click="tab = 'addon'">Addon + Isekai</button>
    </div>

    <div :class="['panel', { active: tab === 'rics' }]">
      <div class="controls">
        <input v-model="rq" type="search" placeholder="Search commands… (name or description)" aria-label="Search RICS commands">
        <select v-model="rperm" aria-label="Permission">
          <option value="">All permissions</option>
          <option v-for="p in perms" :key="p" :value="p">{{ p }}</option>
        </select>
        <label class="toggle"><input v-model="rEnabled" type="checkbox"> Enabled only</label>
        <span class="count">{{ fmt(filteredRics.length) }} command{{ filteredRics.length === 1 ? "" : "s" }}</span>
      </div>
      <DataTable
        :columns="ricsCols"
        :rows="filteredRics"
        empty="No commands match your search."
        :sort-key="rSort.sortKey"
        :sort-dir="rSort.sortDir"
        @sort="rSort.toggleSort"
      >
        <template #row="{ row }">
          <td>
            <b>!{{ row.key }}</b>
            <div v-if="row.alias" class="mod">alias {{ row.alias }}</div>
          </td>
          <td class="cat hide-sm">{{ row.label }}</td>
          <td>{{ row.description }}</td>
          <td class="cat">{{ row.permission }}</td>
          <td class="price hide-sm">{{ row.supportsCost ? fmt(row.cost) : "—" }}</td>
          <td class="flags">
            <span v-if="row.enabled" class="flag">ON</span>
            <span v-else class="off">DISABLED</span>
          </td>
        </template>
      </DataTable>
    </div>

    <div :class="['panel', { active: tab === 'addon' }]">
      <div class="controls">
        <input v-model="aq" type="search" placeholder="Search addon commands…" aria-label="Search addon commands">
        <select v-model="ainteg" aria-label="Integration">
          <option value="">All integrations</option>
          <option v-for="i in integs" :key="i" :value="i">{{ i }}</option>
        </select>
        <label class="toggle"><input v-model="aisekaiOnly" type="checkbox"> Isekai only</label>
        <span class="count">{{ fmt(filteredAddon.length) }} command{{ filteredAddon.length === 1 ? "" : "s" }}</span>
      </div>
      <DataTable
        :columns="addonCols"
        :rows="filteredAddon"
        empty="No addon commands match your search."
        :sort-key="aSort.sortKey"
        :sort-dir="aSort.sortDir"
        @sort="aSort.toggleSort"
      >
        <template #row="{ row }">
          <td><b>{{ row.usage }}</b></td>
          <td>{{ row.description }}</td>
          <td class="cat">{{ row.integration }}</td>
        </template>
      </DataTable>
    </div>
  </div>
</template>
