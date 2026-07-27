<script setup>
import { computed } from 'vue';

const props = defineProps({
  deal: {
    type: Object,
    required: true,
  },
});

const formattedValue = computed(() => {
  if (props.deal.value == null) return '';
  return new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: 'BRL',
  }).format(props.deal.value);
});
</script>

<template>
  <div
    class="deal-card p-3 bg-white dark:bg-n-slate-3 rounded-lg shadow-sm border border-n-weak cursor-grab"
    :data-deal-id="deal.id"
  >
    <p class="text-sm font-medium text-n-slate-12 truncate">
      {{ deal.contact?.name || deal.contact_name }}
    </p>
    <p v-if="deal.title" class="text-xs text-n-slate-11 mt-1 truncate">
      {{ deal.title }}
    </p>
    <p
      v-if="deal.value != null && deal.value > 0"
      class="text-xs font-semibold text-green-600 dark:text-green-400 mt-1"
    >
      {{ formattedValue }}
    </p>
  </div>
</template>
