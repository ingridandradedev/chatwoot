<script setup>
import TaskList from 'dashboard/components/crm/TaskList.vue';

defineProps({
  contactId: { type: [Number, String], required: true },
});
</script>

<template>
  <div class="p-4">
    <TaskList :contact-id="contactId" />
  </div>
</template>
