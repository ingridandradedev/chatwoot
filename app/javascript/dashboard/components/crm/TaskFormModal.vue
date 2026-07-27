<script setup>
import { ref, computed, watch } from 'vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import AgentsAPI from 'dashboard/api/agents';

const props = defineProps({
  show: { type: Boolean, default: false },
  contactId: { type: [Number, String], required: true },
  task: { type: Object, default: null },
});

const emit = defineEmits(['submit', 'close']);

// Form state
const title = ref('');
const description = ref('');
const assigneeId = ref(null);
const dueDate = ref('');
const reminderAt = ref('');
const priority = ref('low');

// Agent list for assignee selector
const agents = ref([]);
const isLoadingAgents = ref(false);

const isEditing = computed(() => !!props.task);

const isValid = computed(() => {
  return !!title.value.trim() && !!dueDate.value;
});

const headerTitle = computed(() => {
  return isEditing.value ? 'Edit Task' : 'New Task';
});

// Pre-fill form when editing
watch(
  () => props.task,
  newTask => {
    if (newTask) {
      title.value = newTask.title || '';
      description.value = newTask.description || '';
      assigneeId.value = newTask.assignee_id || newTask.assigneeId || null;
      dueDate.value = formatDateForInput(newTask.due_date);
      reminderAt.value = formatDateForInput(newTask.reminder_at);
      priority.value = newTask.priority || 'low';
    }
  },
  { immediate: true }
);

// Reset form when modal is shown
watch(
  () => props.show,
  async newShow => {
    if (newShow) {
      await fetchAgents();
      if (!isEditing.value) {
        resetForm();
      }
    }
  }
);

function formatDateForInput(dateStr) {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return '';
  // Format as local datetime-local value: YYYY-MM-DDTHH:mm
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  const hours = String(d.getHours()).padStart(2, '0');
  const minutes = String(d.getMinutes()).padStart(2, '0');
  return `${year}-${month}-${day}T${hours}:${minutes}`;
}

async function fetchAgents() {
  if (agents.value.length > 0) return;
  isLoadingAgents.value = true;
  try {
    const response = await AgentsAPI.get();
    agents.value = response.data || [];
  } catch {
    agents.value = [];
  } finally {
    isLoadingAgents.value = false;
  }
}

function resetForm() {
  title.value = '';
  description.value = '';
  assigneeId.value = null;
  dueDate.value = '';
  reminderAt.value = '';
  priority.value = 'low';
}

function handleSubmit() {
  if (!isValid.value) return;

  const payload = {
    title: title.value.trim(),
    description: description.value.trim() || null,
    assignee_id: assigneeId.value ? Number(assigneeId.value) : null,
    due_date: dueDate.value ? new Date(dueDate.value).toISOString() : null,
    reminder_at: reminderAt.value ? new Date(reminderAt.value).toISOString() : null,
    priority: priority.value,
    contact_id: props.contactId,
  };

  emit('submit', payload);
}

function closeModal() {
  emit('close');
}
</script>

<template>
  <woot-modal :show="show" :on-close="closeModal">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header :header-title="headerTitle" />

      <form class="flex flex-col w-full gap-4 px-6 pb-6" @submit.prevent="handleSubmit">
        <!-- Title input -->
        <div class="w-full">
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            Title <span class="text-n-ruby-9">*</span>
          </label>
          <input
            v-model="title"
            type="text"
            class="w-full h-10 px-3 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:border-n-brand"
            placeholder="Task title"
          />
        </div>

        <!-- Description textarea -->
        <div class="w-full">
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            Description
          </label>
          <textarea
            v-model="description"
            rows="3"
            class="w-full px-3 py-2 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:border-n-brand resize-none"
            placeholder="Task description (optional)"
          />
        </div>

        <!-- Assignee selector -->
        <div class="w-full">
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            Assignee
          </label>
          <select
            v-model="assigneeId"
            class="w-full h-10 px-3 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
          >
            <option :value="null">Unassigned</option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name || agent.email }}
            </option>
          </select>
          <p v-if="isLoadingAgents" class="mt-1 text-xs text-n-slate-10">
            Loading agents...
          </p>
        </div>

        <!-- Due date -->
        <div class="w-full">
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            Due Date <span class="text-n-ruby-9">*</span>
          </label>
          <input
            v-model="dueDate"
            type="datetime-local"
            class="w-full h-10 px-3 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
          />
        </div>

        <!-- Reminder at -->
        <div class="w-full">
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            Reminder At
          </label>
          <input
            v-model="reminderAt"
            type="datetime-local"
            class="w-full h-10 px-3 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
          />
        </div>

        <!-- Priority selector -->
        <div class="w-full">
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            Priority
          </label>
          <select
            v-model="priority"
            class="w-full h-10 px-3 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
          >
            <option value="low">Low</option>
            <option value="medium">Medium</option>
            <option value="high">High</option>
          </select>
        </div>

        <!-- Actions -->
        <div class="flex flex-row justify-end w-full gap-2 py-2">
          <NextButton
            faded
            slate
            type="reset"
            label="Cancel"
            @click.prevent="closeModal"
          />
          <NextButton
            type="submit"
            :label="isEditing ? 'Update Task' : 'Create Task'"
            :disabled="!isValid"
          />
        </div>
      </form>
    </div>
  </woot-modal>
</template>
