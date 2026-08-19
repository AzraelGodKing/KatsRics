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

const incidents = ref([]);
const weather = ref([]);
const tab = computed({
  get: () => (route.query.tab === "weather" ? "weather" : "incidents"),
  set: (v) => router.replace({ query: v === "weather" ? { tab: "weather" } : {} }),
});

const iq = ref("");
const icat = ref("");
const imod = ref("");
const ikarma = ref("");
const itype = ref("");
const iEnabled = ref(true);
const wq = ref("");
const wmod = ref("");
const wkarma = ref("");
const wEnabled = ref(true);

const iSort = useSort("label");
const wSort = useSort("label");

const incidentCols = [
  { key: "label", label: "Event" },
  { key: "category", label: "Category", thClass: "hide-sm" },
  { key: "cost", label: "Cost", align: "right" },
  { key: "karma", label: "Karma" },
  { key: "flags", label: "Flags" },
  { key: "mod", label: "Mod", thClass: "hide-sm" },
];

const weatherCols = [
  { key: "label", label: "Weather" },
  { key: "cost", label: "Cost", align: "right" },
  { key: "karma", label: "Karma" },
  { key: "cap", label: "Cap", thClass: "hide-sm", align: "right" },
  { key: "mod", label: "Mod", thClass: "hide-sm" },
];

onMounted(async () => {
  const [iRows, wRows] = await Promise.all([loadJson("incidents"), loadJson("weather")]);
  incidents.value = iRows.map((r) => ({
    label: r[0],
    defName: r[1],
    category: r[2],
    cost: r[3],
    karma: r[4],
    cap: r[5],
    enabled: !!r[6],
    mod: r[7],
    modActive: !!r[8],
    isRaid: !!r[9],
    isDisease: !!r[10],
    isQuest: !!r[11],
    isWeatherIncident: !!r[12],
    availableForCommands: !!r[13],
  }));
  weather.value = wRows.map((r) => ({
    label: r[0],
    defName: r[1],
    cost: r[2],
    karma: r[3],
    cap: r[4],
    enabled: !!r[5],
    mod: r[6],
    modActive: !!r[7],
  }));
});

watch(tab, () => sync());

const cats = computed(() => [...new Set(incidents.value.map((r) => r.category))].sort());
const iMods = computed(() => [...new Set(incidents.value.map((r) => r.mod))].sort());
const iKarmas = computed(() => [...new Set(incidents.value.map((r) => r.karma))].sort());
const wMods = computed(() => [...new Set(weather.value.map((r) => r.mod))].sort());
const wKarmas = computed(() => [...new Set(weather.value.map((r) => r.karma))].sort());
const iEnabledCount = computed(() => incidents.value.filter((r) => r.enabled).length);
const wEnabledCount = computed(() => weather.value.filter((r) => r.enabled).length);

const stats = computed(() => [
  { value: fmt(incidents.value.length), label: "incidents" },
  { value: fmt(iEnabledCount.value), label: "enabled" },
  { value: fmt(weather.value.length), label: "weather" },
  { value: fmt(wEnabledCount.value), label: "weather on" },
]);

function incidentFlags(r) {
  return [
    r.isRaid && "RAID",
    r.isDisease && "DISEASE",
    r.isQuest && "QUEST",
    r.isWeatherIncident && "WEATHER",
    r.availableForCommands && "CMD",
  ].filter(Boolean).join(" ") || "";
}

function matchesType(r) {
  if (!itype.value) return true;
  if (itype.value === "raid") return r.isRaid;
  if (itype.value === "disease") return r.isDisease;
  if (itype.value === "quest") return r.isQuest;
  if (itype.value === "weather") return r.isWeatherIncident;
  return true;
}

const filteredIncidents = computed(() => {
  const term = iq.value.trim().toLowerCase();
  let list = incidents.value.filter((r) =>
    (!iEnabled.value || r.enabled) &&
    (!icat.value || r.category === icat.value) &&
    (!imod.value || r.mod === imod.value) &&
    (!ikarma.value || r.karma === ikarma.value) &&
    matchesType(r) &&
    (!term || r.label.toLowerCase().includes(term) || r.defName.toLowerCase().includes(term)),
  );
  list = iSort.sorted(list, (r) => (iSort.sortKey.value === "flags" ? incidentFlags(r) || "~" : r[iSort.sortKey.value]));
  return list.map((r) => ({ ...r, _disabled: !r.enabled, _key: r.defName }));
});

const filteredWeather = computed(() => {
  const term = wq.value.trim().toLowerCase();
  let list = weather.value.filter((r) =>
    (!wEnabled.value || r.enabled) &&
    (!wmod.value || r.mod === wmod.value) &&
    (!wkarma.value || r.karma === wkarma.value) &&
    (!term || r.label.toLowerCase().includes(term) || r.defName.toLowerCase().includes(term)),
  );
  list = wSort.sorted(list, (r) => r[wSort.sortKey.value]);
  return list.map((r) => ({ ...r, _disabled: !r.enabled, _key: r.defName }));
});
</script>

<template>
  <div class="page-shell">
    <PageIntro kicker="Channel 04" title="Events & Weather" lede="Incidents and weather you can trigger with chat coins." :stats="stats">
      <template v-if="tab === 'incidents'">
        Trigger with <code>!event &lt;event_name&gt;</code> (e.g. <code>!event ambush</code>).
        Look up prices with <code>!lookup event &lt;name&gt;</code>.
        Raids also use <code>!raid</code> / <code>!raidinfo</code>.
      </template>
      <template v-else>
        Set weather with <code>!weather &lt;type&gt;</code>
        (e.g. <code>!weather rain</code>, <code>!weather clear</code>).
        Look up costs with <code>!lookup weather &lt;name&gt;</code>.
      </template>
    </PageIntro>

    <div class="tabs" role="tablist">
      <button type="button" :class="{ active: tab === 'incidents' }" role="tab" @click="tab = 'incidents'">Incidents</button>
      <button type="button" :class="{ active: tab === 'weather' }" role="tab" @click="tab = 'weather'">Weather</button>
    </div>

    <div :class="['panel', { active: tab === 'incidents' }]">
      <div class="controls">
        <input v-model="iq" type="search" placeholder="Search incidents… (name or defName)" aria-label="Search incidents">
        <select v-model="icat" aria-label="Category">
          <option value="">All categories</option>
          <option v-for="c in cats" :key="c" :value="c">{{ c }}</option>
        </select>
        <select v-model="imod" aria-label="Mod">
          <option value="">All mods</option>
          <option v-for="m in iMods" :key="m" :value="m">{{ m }}</option>
        </select>
        <select v-model="ikarma" aria-label="Karma">
          <option value="">All karma</option>
          <option v-for="k in iKarmas" :key="k" :value="k">{{ k }}</option>
        </select>
        <select v-model="itype" aria-label="Type">
          <option value="">All types</option>
          <option value="raid">Raid</option>
          <option value="disease">Disease</option>
          <option value="quest">Quest</option>
          <option value="weather">Weather incident</option>
        </select>
        <label class="toggle"><input v-model="iEnabled" type="checkbox"> Enabled only</label>
        <span class="count">{{ fmt(filteredIncidents.length) }} incident{{ filteredIncidents.length === 1 ? "" : "s" }}</span>
      </div>
      <DataTable
        :columns="incidentCols"
        :rows="filteredIncidents"
        empty="No incidents match your search."
        :sort-key="iSort.sortKey"
        :sort-dir="iSort.sortDir"
        @sort="iSort.toggleSort"
      >
        <template #row="{ row }">
          <td>
            <b>{{ row.label }}</b>
            <div class="mod">{{ row.defName }}</div>
          </td>
          <td class="cat hide-sm">{{ row.category }}</td>
          <td class="price">{{ fmt(row.cost) }}</td>
          <td class="cat">{{ row.karma }}</td>
          <td class="flags">
            <span v-if="row.isRaid" class="flag">RAID</span>
            <span v-if="row.isDisease" class="flag">DISEASE</span>
            <span v-if="row.isQuest" class="flag">QUEST</span>
            <span v-if="row.isWeatherIncident" class="flag">WEATHER</span>
            <span v-if="row.availableForCommands" class="flag">CMD</span>
            <span v-if="!row.enabled" class="off">DISABLED</span>
          </td>
          <td class="mod hide-sm">{{ row.mod }}</td>
        </template>
      </DataTable>
    </div>

    <div :class="['panel', { active: tab === 'weather' }]">
      <div class="controls">
        <input v-model="wq" type="search" placeholder="Search weather… (name or defName)" aria-label="Search weather">
        <select v-model="wmod" aria-label="Mod">
          <option value="">All mods</option>
          <option v-for="m in wMods" :key="m" :value="m">{{ m }}</option>
        </select>
        <select v-model="wkarma" aria-label="Karma">
          <option value="">All karma</option>
          <option v-for="k in wKarmas" :key="k" :value="k">{{ k }}</option>
        </select>
        <label class="toggle"><input v-model="wEnabled" type="checkbox"> Enabled only</label>
        <span class="count">{{ fmt(filteredWeather.length) }} weather type{{ filteredWeather.length === 1 ? "" : "s" }}</span>
      </div>
      <DataTable
        :columns="weatherCols"
        :rows="filteredWeather"
        empty="No weather types match your search."
        :sort-key="wSort.sortKey"
        :sort-dir="wSort.sortDir"
        @sort="wSort.toggleSort"
      >
        <template #row="{ row }">
          <td>
            <b>{{ row.label }}</b>
            <div class="mod">{{ row.defName }}</div>
            <span v-if="!row.enabled" class="off">DISABLED</span>
          </td>
          <td class="price">{{ fmt(row.cost) }}</td>
          <td class="cat">{{ row.karma }}</td>
          <td class="num hide-sm">{{ row.cap }}</td>
          <td class="mod hide-sm">{{ row.mod }}</td>
        </template>
      </DataTable>
    </div>
  </div>
</template>
