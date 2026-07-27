<script setup>
import { computed } from 'vue';

const props = defineProps({
  task: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['complete', 'reopen']);

const isOverdue = computed(() => props.task.status === 'overdue');
const isCompleted = computed(() => props.task.status === 'completed');

const priorityBadge = computed(() => {
  const map = {
    high: { label: 'High', classes: 'bg-red-100 text-red-700 dark:bg-red-900 dark:text-red-300' },
    medium: { label: 'Medium', classes: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900 dark:text-yellow-300' },
    low: { label: 'Low', classes: 'bg-green-100 text-green-700 dark:bg-green-900 dark:text-green-300' },
  };
  return map[props.task.priority] || map.low;
});

const assigneeName = computed(() => {
  if (props.task.assignee) {
    return props.task.assignee.name || props.task.assignee.email || 'Unassigned';
  }
  return props.task.assignee_name || 'Unassigned';
});

const formattedDueDate = computed(() => {
  if (!props.task.due_date) return '';
  const due = new Date(props.task.due_date);
  const now = new Date();
  const diffMs = due - now;
  const diffDays = Math.round(diffMs / (1000 * 60 * 60 * 24));

  if (diffDays === 0) return 'Today';
  if (diffDays === 1) return 'Tomorrow';
  if (diffDays === -1) return 'Yesterday';
  if (diffDays > 1 && diffDays <= 7) return `In ${diffDays} days`;
  if (diffDays < -1 && diffDays >= -7) return `${Math.abs(diffDays)} days ago`;

  return due.toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: due.getFullYear() !== now.getFullYear() ? 'numeric' : undefined,
  });
});

function onComplete() {
  emit('complete', props.task.id);
}

function onReopen() {
  emit('reopen', props.task.id);
}
</script>

<template>
  <div
    class="flex items-start gap-3 p-3 bg-white rounded-lg border dark:bg-n-slate-3 border-n-weak"
    :class="{ 'border-red-300 dark:border-red-700': isOverdue }"
  >
    <!-- Complete/Reopen action -->
    <div class="flex-shrink-0 pt-0.5">
      <button
        v-if="!isCompleted"
        class="flex items-center justify-center w-5 h-5 border-2 rounded-full border-n-slate-7 hover:border-green-500 hover:bg-green-50 dark:hover:bg-green-900 transition-colors"
        title="Mark as complete"
        @click="onComplete"
      >
        <svg
          class="w-3 h-3 text-transparent hover:text-green-500"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
        </svg>
      </button>
      <button
        v-else
        class="flex items-center justify-center w-5 h-5 bg-green-500 rounded-full hover:bg-yellow-500 transition-colors"
        title="Reopen task"
        @click="onReopen"
      >
        <svg
          class="w-3 h-3 text-white"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M9 15L3 9m0 0l6-6M3 9h12a6 6 0 010 12h-3" />
        </svg>
      </button>
    </div>

    <!-- Task content -->
    <div class="flex-1 min-w-0">
      <div class="flex items-center gap-2">
        <p
          class="text-sm font-medium truncate"
          :class="isCompleted ? 'line-through text-n-slate-10' : 'text-n-slate-12'"
        >
          {{ task.title }}
        </p>
        <span
          class="flex-shrink-0 px-1.5 py-0.5 text-xs font-medium rounded"
          :class="priorityBadge.classes"
        >
          {{ priorityBadge.label }}
        </span>
      </div>

      <div class="flex items-center gap-3 mt-1">
        <span class="text-xs text-n-slate-10">{{ assigneeName }}</span>
        <span
          v-if="formattedDueDate"
          class="text-xs"
          :class="isOverdue ? 'text-red-600 dark:text-red-400 font-medium' : 'text-n-slate-10'"
        >
          {{ formattedDueDate }}
        </span>
        <span
          v-if="isOverdue"
          class="px-1.5 py-0.5 text-xs font-medium text-red-700 bg-red-100 rounded dark:bg-red-900 dark:text-red-300"
        >
          Overdue
        </span>
      </div>
    </div>
  </div>
</template>
