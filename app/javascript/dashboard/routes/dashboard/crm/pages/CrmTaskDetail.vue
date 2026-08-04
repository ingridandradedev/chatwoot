<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import TaskAPI from 'dashboard/api/crm/tasks';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const task = ref(null);
const isLoading = ref(false);
const isActioning = ref(false);

const taskId = computed(() => route.params.taskId);
const accountId = computed(() => route.params.accountId);

const statusBadge = computed(() => {
  if (!task.value) return {};
  const map = {
    pending: { label: 'Pendente', classes: 'bg-n-amber-3 text-n-amber-11 border-n-amber-6' },
    overdue: { label: 'Em Andamento', classes: 'bg-n-ruby-3 text-n-ruby-11 border-n-ruby-6' },
    completed: { label: 'Concluído', classes: 'bg-n-teal-3 text-n-teal-11 border-n-teal-6' },
  };
  return map[task.value.status] || map.pending;
});

const priorityBadge = computed(() => {
  if (!task.value) return {};
  const map = {
    high: { label: 'Alta', classes: 'bg-red-100 text-red-700 dark:bg-red-900 dark:text-red-300' },
    medium: { label: 'Média', classes: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900 dark:text-yellow-300' },
    low: { label: 'Baixa', classes: 'bg-green-100 text-green-700 dark:bg-green-900 dark:text-green-300' },
  };
  return map[task.value.priority] || map.low;
});

const isCompleted = computed(() => task.value?.status === 'completed');

const formatDate = ts => {
  if (!ts) return '—';
  const date = new Date(typeof ts === 'number' ? ts * 1000 : ts);
  return date.toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

const fetchTask = async () => {
  isLoading.value = true;
  try {
    const { data } = await TaskAPI.show(taskId.value);
    task.value = data.payload || data;
  } catch {
    task.value = null;
    useAlert('Failed to load task');
  } finally {
    isLoading.value = false;
  }
};

const goBack = () => {
  router.push({ name: 'crm_activities_board' });
};

const goToContact = () => {
  if (!task.value?.contact?.id && !task.value?.contact_id) return;
  const contactId = task.value.contact?.id || task.value.contact_id;
  router.push(`/app/accounts/${accountId.value}/contacts/${contactId}`);
};

const completeTask = async () => {
  if (isActioning.value) return;
  isActioning.value = true;
  try {
    await TaskAPI.complete(taskId.value);
    task.value.status = 'completed';
    useAlert('Task concluída');
  } catch (error) {
    useAlert(error?.response?.data?.message || 'Erro ao completar');
  } finally {
    isActioning.value = false;
  }
};

const reopenTask = async () => {
  if (isActioning.value) return;
  isActioning.value = true;
  try {
    await TaskAPI.reopen(taskId.value);
    task.value.status = 'pending';
    useAlert('Task reaberta');
  } catch (error) {
    useAlert(error?.response?.data?.message || 'Erro ao reabrir');
  } finally {
    isActioning.value = false;
  }
};

const deleteTask = async () => {
  if (!window.confirm('Tem certeza que deseja excluir esta task?')) return;
  isActioning.value = true;
  try {
    await TaskAPI.delete(taskId.value);
    useAlert('Task excluída');
    goBack();
  } catch (error) {
    useAlert(error?.response?.data?.message || 'Erro ao excluir');
  } finally {
    isActioning.value = false;
  }
};

onMounted(fetchTask);
</script>

<template>
  <div class="flex flex-col h-full bg-n-surface-1 overflow-y-auto">
    <!-- Loading -->
    <div v-if="isLoading" class="flex items-center justify-center py-10 text-n-slate-11">
      <Spinner />
    </div>

    <!-- Not found -->
    <div v-else-if="!task" class="flex flex-col items-center justify-center py-10 gap-2">
      <p class="text-sm text-n-slate-11">Task não encontrada</p>
      <NextButton label="Voltar" icon="i-lucide-arrow-left" faded slate @click="goBack" />
    </div>

    <!-- Task detail -->
    <template v-else>
      <!-- Header -->
      <header class="flex items-center justify-between px-6 py-4 border-b border-n-strong">
        <div class="flex items-center gap-3">
          <button
            class="p-1.5 rounded-md hover:bg-n-alpha-black2 text-n-slate-11"
            @click="goBack"
          >
            <span class="i-lucide-arrow-left w-5 h-5" />
          </button>
          <h1 class="text-lg font-semibold text-n-slate-12 truncate max-w-md">
            {{ task.title }}
          </h1>
        </div>
        <div class="flex items-center gap-2">
          <NextButton
            v-if="!isCompleted"
            label="Completar"
            icon="i-lucide-check"
            :disabled="isActioning"
            @click="completeTask"
          />
          <NextButton
            v-else
            label="Reabrir"
            icon="i-lucide-undo-2"
            faded
            slate
            :disabled="isActioning"
            @click="reopenTask"
          />
          <NextButton
            label="Excluir"
            icon="i-lucide-trash-2"
            faded
            slate
            :disabled="isActioning"
            @click="deleteTask"
          />
        </div>
      </header>

      <!-- Content -->
      <div class="flex-1 px-6 py-6 max-w-3xl">
        <!-- Status and priority badges -->
        <div class="flex items-center gap-2 mb-6">
          <span
            class="px-2.5 py-1 text-xs font-medium rounded-md border"
            :class="statusBadge.classes"
          >
            {{ statusBadge.label }}
          </span>
          <span
            class="px-2.5 py-1 text-xs font-medium rounded-md"
            :class="priorityBadge.classes"
          >
            Prioridade: {{ priorityBadge.label }}
          </span>
        </div>

        <!-- Details grid -->
        <div class="space-y-4">
          <!-- Description -->
          <div v-if="task.description" class="pb-4 border-b border-n-weak">
            <h3 class="text-xs font-medium text-n-slate-10 mb-1">Descrição</h3>
            <p class="text-sm text-n-slate-12 whitespace-pre-wrap">{{ task.description }}</p>
          </div>

          <!-- Info rows -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <!-- Assignee -->
            <div>
              <h3 class="text-xs font-medium text-n-slate-10 mb-0.5">Atribuído a</h3>
              <p class="text-sm text-n-slate-12 flex items-center gap-1">
                <span class="i-lucide-user w-3.5 h-3.5 text-n-slate-9" />
                {{ task.assignee?.name || 'Não atribuído' }}
              </p>
            </div>

            <!-- Contact -->
            <div>
              <h3 class="text-xs font-medium text-n-slate-10 mb-0.5">Contato</h3>
              <button
                class="text-sm text-n-blue-11 hover:underline flex items-center gap-1"
                @click="goToContact"
              >
                <span class="i-lucide-contact w-3.5 h-3.5" />
                {{ task.contact?.name || 'Sem contato' }}
              </button>
            </div>

            <!-- Due date -->
            <div>
              <h3 class="text-xs font-medium text-n-slate-10 mb-0.5">Data de Vencimento</h3>
              <p class="text-sm text-n-slate-12 flex items-center gap-1">
                <span class="i-lucide-calendar w-3.5 h-3.5 text-n-slate-9" />
                {{ formatDate(task.due_date) }}
              </p>
            </div>

            <!-- Reminder -->
            <div>
              <h3 class="text-xs font-medium text-n-slate-10 mb-0.5">Lembrete</h3>
              <p class="text-sm text-n-slate-12 flex items-center gap-1">
                <span class="i-lucide-bell w-3.5 h-3.5 text-n-slate-9" />
                {{ task.reminder_at ? formatDate(task.reminder_at) : 'Sem lembrete' }}
              </p>
            </div>

            <!-- Created by -->
            <div>
              <h3 class="text-xs font-medium text-n-slate-10 mb-0.5">Criado por</h3>
              <p class="text-sm text-n-slate-12 flex items-center gap-1">
                <span class="i-lucide-user-plus w-3.5 h-3.5 text-n-slate-9" />
                ID: {{ task.created_by_id }}
              </p>
            </div>

            <!-- Created at -->
            <div>
              <h3 class="text-xs font-medium text-n-slate-10 mb-0.5">Criado em</h3>
              <p class="text-sm text-n-slate-12 flex items-center gap-1">
                <span class="i-lucide-clock w-3.5 h-3.5 text-n-slate-9" />
                {{ formatDate(task.created_at) }}
              </p>
            </div>

            <!-- Completed at (if completed) -->
            <div v-if="task.completed_at">
              <h3 class="text-xs font-medium text-n-slate-10 mb-0.5">Concluído em</h3>
              <p class="text-sm text-n-slate-12 flex items-center gap-1">
                <span class="i-lucide-check-circle w-3.5 h-3.5 text-n-teal-9" />
                {{ formatDate(task.completed_at) }}
              </p>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
