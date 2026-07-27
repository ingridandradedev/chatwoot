<script setup>
import ActivityTimeline from 'dashboard/components/crm/ActivityTimeline.vue';
import ActivityForm from 'dashboard/components/crm/ActivityForm.vue';

defineProps({
  contactId: { type: [Number, String], required: true },
});
</script>

<template>
  <div class="flex flex-col gap-4 p-4">
    <ActivityForm :contact-id="contactId" />
    <ActivityTimeline :contact-id="contactId" />
  </div>
</template>
