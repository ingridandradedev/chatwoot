<script setup>
import { ref, computed, onMounted } from 'vue';
import { useCrmTasksStore } from 'dashboard/stores/crm/tasks';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TaskCard from './TaskCard.vue';
import TaskFormModal from './TaskFormModal.vue';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
});

const taskStore = useCrmTasksStore();
const showFormModal = ref(false);
const editingTask = ref(null);

const isLoading = computed(() => taskStore.getUIFlags.fetchingList);

// Sort tasks: overdue first, then by due_date ascending
const sortedTasks = computed(() => {
  const tasks = [...taskStore.getTasks];
  return tasks.sort((a, b) => {
    // Overdue tasks come first
    const aOverdue = a.status === 'overdue' ? 0 : 1;
    const bOverdue = b.status === 'overdue' ? 0 : 1;
    if (aOverdue !== bOverdue) return aOverdue - bOverdue;

    // Then sort by due_date ascending (earliest first)
    const aDate = a.due_date ? new Date(a.due_date).getTime() : Infinity;
    const bDate = b.due_date ? new Date(b.due_date).getTime() : Infinity;
    return aDate - bDate;
  });
});

onMounted(() => {
  taskStore.fetchForContact(props.contactId);
});

function openAddModal() {
  editingTask.value = null;
  showFormModal.value = true;
}

function closeModal() {
  showFormModal.value = false;
  editingTask.value = null;
}

async function handleSubmit(payload) {
  if (editingTask.value) {
    await taskStore.updateTask(editingTask.value.id, payload);
  } else {
    await taskStore.createForContact(props.contactId, payload);
  }
  closeModal();
}

async function handleComplete(taskId) {
  await taskStore.completeTask(taskId);
}

async function handleReopen(taskId) {
  await taskStore.reopenTask(taskId);
}
</script>

<template>
  <div class="flex flex-col gap-3">
    <!-- Header with Add button -->
    <div class="flex items-center justify-between">
      <h3 class="text-sm font-semibold text-n-slate-12">Tasks</h3>
      <NextButton
        sm
        label="Add Task"
        icon="i-lucide-plus"
        @click="openAddModal"
      />
    </div>

    <!-- Loading state -->
    <div v-if="isLoading" class="flex items-center justify-center py-6">
      <span class="text-sm text-n-slate-10">Loading tasks...</span>
    </div>

    <!-- Empty state -->
    <div
      v-else-if="sortedTasks.length === 0"
      class="flex flex-col items-center justify-center py-6 text-center"
    >
      <p class="text-sm text-n-slate-10">No tasks yet</p>
      <p class="mt-1 text-xs text-n-slate-9">
        Create a task to track follow-ups for this contact.
      </p>
    </div>

    <!-- Task list -->
    <div v-else class="flex flex-col gap-2">
      <TaskCard
        v-for="task in sortedTasks"
        :key="task.id"
        :task="task"
        @complete="handleComplete"
        @reopen="handleReopen"
      />
    </div>

    <!-- Task Form Modal -->
    <TaskFormModal
      :show="showFormModal"
      :contact-id="props.contactId"
      :task="editingTask"
      @submit="handleSubmit"
      @close="closeModal"
    />
  </div>
</template>
