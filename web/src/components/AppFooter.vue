<script setup>
defineProps({
  note: { type: String, default: "Generated from the live CAP ChatInteractive config" },
});
</script>

<template>
  <footer>
    {{ note }} ·
    <a href="https://github.com/AzraelGodKing/KatsRics">source</a> ·
    Powered by <a href="https://github.com/ekudram/-cap-RimworldInteractiveChatServices">RICS</a>
  </footer>
</template>
