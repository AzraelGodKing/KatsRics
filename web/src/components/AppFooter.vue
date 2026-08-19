<script setup>
defineProps({
  note: { type: String, default: "Synced from CAP ChatInteractive" },
});
</script>

<template>
  <footer>
    <span>{{ note }}</span>
    <span class="footer-links">
      <a href="https://github.com/AzraelGodKing/KatsRics">source</a>
      <a href="https://github.com/ekudram/-cap-RimworldInteractiveChatServices">RICS</a>
    </span>
  </footer>
</template>
