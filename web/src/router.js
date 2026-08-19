import { createRouter, createWebHashHistory } from "vue-router";
import StoreView from "./views/StoreView.vue";
import TraitsView from "./views/TraitsView.vue";
import BackstoriesView from "./views/BackstoriesView.vue";
import EventsView from "./views/EventsView.vue";

const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: "/", name: "store", component: StoreView, meta: { title: "Store" } },
    { path: "/traits", name: "traits", component: TraitsView, meta: { title: "Traits" } },
    { path: "/backstories", name: "backstories", component: BackstoriesView, meta: { title: "Backstories" } },
    { path: "/events", name: "events", component: EventsView, meta: { title: "Events" } },
    { path: "/:pathMatch(.*)*", redirect: "/" },
  ],
  scrollBehavior() {
    return { top: 0 };
  },
});

router.afterEach((to) => {
  const page = to.meta.title ? ` — ${to.meta.title}` : "";
  document.title = `Kat's RICS${page}`;
});

export default router;
