<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import draggable from 'vuedraggable';
import { useCrmPipelinesStore } from 'dashboard/stores/crm/pipelines';
import { useAlert } from 'dashboard/composables';
import StageAPI from 'dashboard/api/crm/stages';

const { t } = useI18n();
const route = useRoute();
const pipelineStore = useCrmPipelinesStore();

// Pipeline state
const selectedPipelineId = ref(null);
const newPipelineName = ref('');
const isCreatingPipeline = ref(false);
const editingPipelineId = ref(null);
const editingPipelineName = ref('');
const deletingPipelineId = ref(null);

// Stage state
const stages = ref([]);
const isFetchingStages = ref(false);
const newStageName = ref('');
const isCreatingStage = ref(false);
const editingStageId = ref(null);
const editingStageName = ref('');
const deletingStageId = ref(null);
const deletingStageHasDeals = ref(false);

const pipelines = computed(() => pipelineStore.getRecords);
const isFetchingPipelines = computed(
  () => pipelineStore.getUIFlags.fetchingList
);

const selectedPipeline = computed(() =>
  pipelines.value.find(p => p.id === selectedPipelineId.value)
);

onMounted(async () => {
  await pipelineStore.get();
  await fetchCustomAttributes();
  if (pipelines.value.length) {
    selectedPipelineId.value = pipelines.value[0].id;
  }
});

watch(selectedPipelineId, async id => {
  if (id) {
    await fetchStages(id);
  } else {
    stages.value = [];
  }
});

// Pipeline operations
const selectPipeline = id => {
  selectedPipelineId.value = id;
  editingPipelineId.value = null;
};

const createPipeline = async () => {
  const name = newPipelineName.value.trim();
  if (!name) return;

  isCreatingPipeline.value = true;
  try {
    const result = await pipelineStore.create({ pipeline: { name } });
    newPipelineName.value = '';
    selectedPipelineId.value = result.id;
    useAlert(t('CRM.SETTINGS.PIPELINE.CREATE_SUCCESS'));
  } catch (error) {
    const message =
      error?.response?.data?.message || t('CRM.SETTINGS.PIPELINE.CREATE_ERROR');
    useAlert(message);
  } finally {
    isCreatingPipeline.value = false;
  }
};

const startRenamePipeline = pipeline => {
  editingPipelineId.value = pipeline.id;
  editingPipelineName.value = pipeline.name;
};

const saveRenamePipeline = async () => {
  const name = editingPipelineName.value.trim();
  if (!name || !editingPipelineId.value) return;

  try {
    await pipelineStore.update({
      id: editingPipelineId.value,
      pipeline: { name },
    });
    editingPipelineId.value = null;
    editingPipelineName.value = '';
    useAlert(t('CRM.SETTINGS.PIPELINE.RENAME_SUCCESS'));
  } catch (error) {
    const message =
      error?.response?.data?.message || t('CRM.SETTINGS.PIPELINE.RENAME_ERROR');
    useAlert(message);
  }
};

const cancelRenamePipeline = () => {
  editingPipelineId.value = null;
  editingPipelineName.value = '';
};

const confirmDeletePipeline = id => {
  deletingPipelineId.value = id;
};

const deletePipeline = async () => {
  if (!deletingPipelineId.value) return;

  try {
    await pipelineStore.delete(deletingPipelineId.value);
    if (selectedPipelineId.value === deletingPipelineId.value) {
      selectedPipelineId.value = pipelines.value.length
        ? pipelines.value[0].id
        : null;
    }
    useAlert(t('CRM.SETTINGS.PIPELINE.DELETE_SUCCESS'));
  } catch (error) {
    const message =
      error?.response?.data?.message || t('CRM.SETTINGS.PIPELINE.DELETE_ERROR');
    useAlert(message);
  } finally {
    deletingPipelineId.value = null;
  }
};

const cancelDeletePipeline = () => {
  deletingPipelineId.value = null;
};

const toggleAutoCreateDeals = async () => {
  if (!selectedPipeline.value) return;
  const newValue = !selectedPipeline.value.auto_create_deals;
  try {
    await pipelineStore.update({
      id: selectedPipelineId.value,
      pipeline: { auto_create_deals: newValue },
    });
    useAlert(
      newValue
        ? t('CRM.SETTINGS.PIPELINE.AUTO_DEALS_ENABLED')
        : t('CRM.SETTINGS.PIPELINE.AUTO_DEALS_DISABLED')
    );
    await pipelineStore.get();
  } catch (error) {
    const message =
      error?.response?.data?.message || 'Failed to update setting';
    useAlert(message);
  }
};

// Card fields configuration
const MAX_CARD_FIELDS = 6;
const AVAILABLE_STANDARD_FIELDS = [
  { key: 'name', label: 'Name' },
  { key: 'email', label: 'Email' },
  { key: 'phone_number', label: 'Phone' },
  { key: 'company', label: 'Company' },
  { key: 'deal_value', label: 'Deal Value' },
  { key: 'deal_title', label: 'Deal Title' },
];

const currentCardFields = computed(() => selectedPipeline.value?.card_fields || ['name', 'email', 'phone_number']);

const customAttributeDefinitions = ref([]);

const fetchCustomAttributes = async () => {
  try {
    const accountId = route.params.accountId || 1;
    const response = await StageAPI.get ? null : null;
    // Use global axios (Chatwoot pattern)
    const { data } = await window.axios.get(`/api/v1/accounts/${accountId}/custom_attribute_definitions`);
    customAttributeDefinitions.value = (data.data || []).filter(a => a.attribute_model === 'contact_attribute');
  } catch {
    customAttributeDefinitions.value = [];
  }
};

const isFieldSelected = field => currentCardFields.value.includes(field);

const toggleCardField = async field => {
  let fields = [...currentCardFields.value];
  if (fields.includes(field)) {
    fields = fields.filter(f => f !== field);
  } else {
    if (fields.length >= MAX_CARD_FIELDS) {
      useAlert(`Maximum ${MAX_CARD_FIELDS} fields allowed on card`);
      return;
    }
    fields.push(field);
  }
  try {
    await pipelineStore.update({
      id: selectedPipelineId.value,
      pipeline: { card_fields: fields },
    });
    await pipelineStore.get();
  } catch (error) {
    useAlert(error?.response?.data?.message || 'Failed to update card fields');
  }
};

// Stage operations
const fetchStages = async pipelineId => {
  isFetchingStages.value = true;
  try {
    const response = await StageAPI.getStages(pipelineId);
    stages.value = response.data.payload || response.data || [];
  } catch {
    stages.value = [];
  } finally {
    isFetchingStages.value = false;
  }
};

const createStage = async () => {
  const name = newStageName.value.trim();
  if (!name || !selectedPipelineId.value) return;

  isCreatingStage.value = true;
  try {
    const position = stages.value.length;
    const response = await StageAPI.createStage(selectedPipelineId.value, {
      stage: { name, position },
    });
    stages.value.push(response.data);
    newStageName.value = '';
    useAlert(t('CRM.SETTINGS.STAGE.CREATE_SUCCESS'));
    // Refresh pipeline data to keep store in sync
    await pipelineStore.get();
  } catch (error) {
    const message =
      error?.response?.data?.message || t('CRM.SETTINGS.STAGE.CREATE_ERROR');
    useAlert(message);
  } finally {
    isCreatingStage.value = false;
  }
};

const startRenameStage = stage => {
  editingStageId.value = stage.id;
  editingStageName.value = stage.name;
};

const saveRenameStage = async () => {
  const name = editingStageName.value.trim();
  if (!name || !editingStageId.value) return;

  try {
    await StageAPI.updateStage(selectedPipelineId.value, editingStageId.value, {
      stage: { name },
    });
    const stage = stages.value.find(s => s.id === editingStageId.value);
    if (stage) stage.name = name;
    editingStageId.value = null;
    editingStageName.value = '';
    useAlert(t('CRM.SETTINGS.STAGE.RENAME_SUCCESS'));
    await pipelineStore.get();
  } catch (error) {
    const message =
      error?.response?.data?.message || t('CRM.SETTINGS.STAGE.RENAME_ERROR');
    useAlert(message);
  }
};

const cancelRenameStage = () => {
  editingStageId.value = null;
  editingStageName.value = '';
};

const confirmDeleteStage = stage => {
  deletingStageId.value = stage.id;
  deletingStageHasDeals.value = stage.deals_count > 0;
};

const deleteStage = async () => {
  if (!deletingStageId.value) return;

  try {
    await StageAPI.deleteStage(selectedPipelineId.value, deletingStageId.value);
    stages.value = stages.value.filter(s => s.id !== deletingStageId.value);
    useAlert(t('CRM.SETTINGS.STAGE.DELETE_SUCCESS'));
    await pipelineStore.get();
  } catch (error) {
    const message =
      error?.response?.data?.error ||
      error?.response?.data?.message ||
      t('CRM.SETTINGS.STAGE.DELETE_ERROR');
    useAlert(message);
  } finally {
    deletingStageId.value = null;
    deletingStageHasDeals.value = false;
  }
};

const cancelDeleteStage = () => {
  deletingStageId.value = null;
  deletingStageHasDeals.value = false;
};

const onStageReorder = async () => {
  const positions = stages.value.map((stage, index) => ({
    id: stage.id,
    position: index,
  }));
  try {
    await StageAPI.reorderStages(selectedPipelineId.value, positions);
    await pipelineStore.get();
  } catch {
    useAlert(t('CRM.SETTINGS.STAGE.REORDER_ERROR'));
    await fetchStages(selectedPipelineId.value);
  }
};
</script>

<template>
  <div class="pipeline-settings flex h-full bg-n-surface-1">
    <!-- Loading state -->
    <div
      v-if="isFetchingPipelines"
      class="flex items-center justify-center flex-1"
    >
      <span class="text-n-slate-11">{{ t('CRM.LOADING') }}</span>
    </div>

    <template v-else>
      <!-- Sidebar: Pipeline List -->
      <aside
        class="w-64 border-r border-n-strong flex flex-col overflow-y-auto"
      >
        <div class="px-4 py-4 border-b border-n-strong">
          <h2 class="text-sm font-semibold text-n-slate-12 mb-3">
            {{ t('CRM.SETTINGS.PIPELINE.TITLE') }}
          </h2>
          <!-- Add pipeline form -->
          <form class="flex gap-2" @submit.prevent="createPipeline">
            <input
              v-model="newPipelineName"
              type="text"
              class="flex-1 px-2 py-1.5 text-sm border rounded-md border-n-weak bg-n-surface-2 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
              :placeholder="t('CRM.SETTINGS.PIPELINE.NAME_PLACEHOLDER')"
              :disabled="isCreatingPipeline"
            />
            <button
              type="submit"
              class="px-3 py-1.5 text-sm font-medium text-white rounded-md bg-n-brand hover:bg-n-brand-dark disabled:opacity-50"
              :disabled="!newPipelineName.trim() || isCreatingPipeline"
            >
              {{ t('CRM.SETTINGS.PIPELINE.ADD') }}
            </button>
          </form>
        </div>

        <!-- Pipeline list -->
        <nav class="flex-1 overflow-y-auto">
          <ul class="py-2">
            <li
              v-for="pipeline in pipelines"
              :key="pipeline.id"
              class="group flex items-center gap-1 px-4 py-2 cursor-pointer hover:bg-n-surface-2"
              :class="{
                'bg-n-surface-3 border-l-2 border-n-brand':
                  pipeline.id === selectedPipelineId,
              }"
              @click="selectPipeline(pipeline.id)"
            >
              <!-- Inline rename -->
              <template v-if="editingPipelineId === pipeline.id">
                <input
                  v-model="editingPipelineName"
                  type="text"
                  class="flex-1 px-2 py-1 text-sm border rounded border-n-weak bg-n-surface-2 text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-n-brand"
                  @keyup.enter="saveRenamePipeline"
                  @keyup.escape="cancelRenamePipeline"
                  @click.stop
                />
                <button
                  class="p-1 text-n-slate-11 hover:text-green-600"
                  :title="t('CRM.SETTINGS.SAVE')"
                  @click.stop="saveRenamePipeline"
                >
                  ✓
                </button>
                <button
                  class="p-1 text-n-slate-11 hover:text-red-600"
                  :title="t('CRM.SETTINGS.CANCEL')"
                  @click.stop="cancelRenamePipeline"
                >
                  ✕
                </button>
              </template>

              <template v-else>
                <span class="flex-1 text-sm text-n-slate-12 truncate">
                  {{ pipeline.name }}
                </span>
                <button
                  class="hidden group-hover:inline-flex p-1 text-n-slate-11 hover:text-n-slate-12"
                  :title="t('CRM.SETTINGS.PIPELINE.RENAME')"
                  @click.stop="startRenamePipeline(pipeline)"
                >
                  ✎
                </button>
                <button
                  class="hidden group-hover:inline-flex p-1 text-n-slate-11 hover:text-red-600"
                  :title="t('CRM.SETTINGS.PIPELINE.DELETE')"
                  @click.stop="confirmDeletePipeline(pipeline.id)"
                >
                  ✕
                </button>
              </template>
            </li>
          </ul>
        </nav>
      </aside>

      <!-- Main: Stage Management -->
      <main class="flex-1 flex flex-col overflow-hidden">
        <!-- No pipeline selected -->
        <div
          v-if="!selectedPipeline"
          class="flex items-center justify-center flex-1"
        >
          <p class="text-sm text-n-slate-11">
            {{ t('CRM.SETTINGS.STAGE.SELECT_PIPELINE') }}
          </p>
        </div>

        <template v-else>
          <!-- Header -->
          <header class="px-6 py-4 border-b border-n-strong">
            <h2 class="text-lg font-semibold text-n-slate-12">
              {{ selectedPipeline.name }}
            </h2>
            <p class="text-sm text-n-slate-11 mt-1">
              {{ t('CRM.SETTINGS.STAGE.DESCRIPTION') }}
            </p>
            <!-- Auto-create deals toggle -->
            <label class="flex items-center gap-2 mt-3 cursor-pointer">
              <input
                type="checkbox"
                :checked="selectedPipeline.auto_create_deals"
                class="w-4 h-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                @change="toggleAutoCreateDeals"
              />
              <span class="text-sm text-n-slate-12">
                {{ t('CRM.SETTINGS.PIPELINE.AUTO_DEALS_LABEL') }}
              </span>
            </label>
          </header>

          <!-- Card Fields Configuration -->
          <div class="px-6 py-4 border-b border-n-strong">
            <h3 class="text-sm font-semibold text-n-slate-12 mb-1">
              Card Fields
            </h3>
            <p class="text-xs text-n-slate-10 mb-3">
              Select which fields appear on deal cards (max {{ MAX_CARD_FIELDS }}).
              {{ currentCardFields.length }}/{{ MAX_CARD_FIELDS }} selected.
            </p>
            <div class="flex flex-wrap gap-2">
              <!-- Standard fields -->
              <label
                v-for="field in AVAILABLE_STANDARD_FIELDS"
                :key="field.key"
                class="inline-flex items-center gap-1.5 px-2.5 py-1.5 text-xs rounded-md cursor-pointer border transition-colors"
                :class="isFieldSelected(field.key)
                  ? 'bg-n-blue-3 border-n-blue-7 text-n-blue-11'
                  : 'bg-n-surface-2 border-n-weak text-n-slate-11 hover:border-n-slate-8'"
              >
                <input
                  type="checkbox"
                  :checked="isFieldSelected(field.key)"
                  class="sr-only"
                  @change="toggleCardField(field.key)"
                />
                {{ field.label }}
              </label>
              <!-- Custom attributes -->
              <label
                v-for="attr in customAttributeDefinitions"
                :key="attr.attribute_key"
                class="inline-flex items-center gap-1.5 px-2.5 py-1.5 text-xs rounded-md cursor-pointer border transition-colors"
                :class="isFieldSelected(attr.attribute_key)
                  ? 'bg-n-violet-3 border-n-violet-7 text-n-violet-11'
                  : 'bg-n-surface-2 border-n-weak text-n-slate-11 hover:border-n-slate-8'"
              >
                <input
                  type="checkbox"
                  :checked="isFieldSelected(attr.attribute_key)"
                  class="sr-only"
                  @change="toggleCardField(attr.attribute_key)"
                />
                {{ attr.attribute_display_name }}
              </label>
            </div>
          </div>

          <!-- Stage content -->
          <div class="flex-1 overflow-y-auto p-6">
            <!-- Loading stages -->
            <div
              v-if="isFetchingStages"
              class="flex items-center justify-center py-8"
            >
              <span class="text-n-slate-11">{{ t('CRM.LOADING') }}</span>
            </div>

            <template v-else>
              <!-- Draggable stage list -->
              <draggable
                v-model="stages"
                item-key="id"
                handle=".drag-handle"
                ghost-class="opacity-50"
                class="space-y-2"
                @end="onStageReorder"
              >
                <template #item="{ element: stage }">
                  <div
                    class="flex items-center gap-3 px-4 py-3 bg-n-surface-2 rounded-lg border border-n-weak group"
                  >
                    <!-- Drag handle -->
                    <span
                      class="drag-handle cursor-grab text-n-slate-9 hover:text-n-slate-12"
                      :title="t('CRM.SETTINGS.STAGE.DRAG')"
                    >
                      ⠿
                    </span>

                    <!-- Inline rename -->
                    <template v-if="editingStageId === stage.id">
                      <input
                        v-model="editingStageName"
                        type="text"
                        class="flex-1 px-2 py-1 text-sm border rounded border-n-weak bg-n-surface-1 text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-n-brand"
                        @keyup.enter="saveRenameStage"
                        @keyup.escape="cancelRenameStage"
                      />
                      <button
                        class="p-1 text-n-slate-11 hover:text-green-600"
                        :title="t('CRM.SETTINGS.SAVE')"
                        @click="saveRenameStage"
                      >
                        ✓
                      </button>
                      <button
                        class="p-1 text-n-slate-11 hover:text-red-600"
                        :title="t('CRM.SETTINGS.CANCEL')"
                        @click="cancelRenameStage"
                      >
                        ✕
                      </button>
                    </template>

                    <template v-else>
                      <span class="flex-1 text-sm text-n-slate-12">
                        {{ stage.name }}
                      </span>
                      <span
                        v-if="stage.deals_count"
                        class="text-xs text-n-slate-10 bg-n-surface-3 px-2 py-0.5 rounded-full"
                      >
                        {{
                          t('CRM.SETTINGS.STAGE.DEALS_COUNT', {
                            count: stage.deals_count,
                          })
                        }}
                      </span>
                      <button
                        class="hidden group-hover:inline-flex p-1 text-n-slate-11 hover:text-n-slate-12"
                        :title="t('CRM.SETTINGS.STAGE.RENAME')"
                        @click="startRenameStage(stage)"
                      >
                        ✎
                      </button>
                      <button
                        class="hidden group-hover:inline-flex p-1 text-n-slate-11 hover:text-red-600"
                        :title="t('CRM.SETTINGS.STAGE.DELETE')"
                        @click="confirmDeleteStage(stage)"
                      >
                        ✕
                      </button>
                    </template>
                  </div>
                </template>
              </draggable>

              <!-- Add stage form -->
              <form
                class="flex gap-2 mt-4"
                @submit.prevent="createStage"
              >
                <input
                  v-model="newStageName"
                  type="text"
                  class="flex-1 px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-surface-2 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
                  :placeholder="t('CRM.SETTINGS.STAGE.NAME_PLACEHOLDER')"
                  :disabled="isCreatingStage"
                />
                <button
                  type="submit"
                  class="px-4 py-2 text-sm font-medium text-white rounded-lg bg-n-brand hover:bg-n-brand-dark disabled:opacity-50"
                  :disabled="!newStageName.trim() || isCreatingStage"
                >
                  {{ t('CRM.SETTINGS.STAGE.ADD') }}
                </button>
              </form>
            </template>
          </div>
        </template>
      </main>
    </template>

    <!-- Delete Pipeline Confirmation Modal -->
    <teleport to="body">
      <div
        v-if="deletingPipelineId"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      >
        <div class="bg-n-surface-1 rounded-xl shadow-lg p-6 w-96 max-w-full">
          <h3 class="text-base font-semibold text-n-slate-12 mb-2">
            {{ t('CRM.SETTINGS.PIPELINE.DELETE_CONFIRM_TITLE') }}
          </h3>
          <p class="text-sm text-n-slate-11 mb-4">
            {{ t('CRM.SETTINGS.PIPELINE.DELETE_CONFIRM_MESSAGE') }}
          </p>
          <div class="flex justify-end gap-2">
            <button
              class="px-4 py-2 text-sm font-medium text-n-slate-12 bg-n-surface-2 rounded-lg hover:bg-n-surface-3"
              @click="cancelDeletePipeline"
            >
              {{ t('CRM.SETTINGS.CANCEL') }}
            </button>
            <button
              class="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-lg hover:bg-red-700"
              @click="deletePipeline"
            >
              {{ t('CRM.SETTINGS.DELETE') }}
            </button>
          </div>
        </div>
      </div>
    </teleport>

    <!-- Delete Stage Confirmation Modal -->
    <teleport to="body">
      <div
        v-if="deletingStageId"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      >
        <div class="bg-n-surface-1 rounded-xl shadow-lg p-6 w-96 max-w-full">
          <h3 class="text-base font-semibold text-n-slate-12 mb-2">
            {{ t('CRM.SETTINGS.STAGE.DELETE_CONFIRM_TITLE') }}
          </h3>
          <p class="text-sm text-n-slate-11 mb-4">
            <template v-if="deletingStageHasDeals">
              {{ t('CRM.SETTINGS.STAGE.DELETE_CONFIRM_HAS_DEALS') }}
            </template>
            <template v-else>
              {{ t('CRM.SETTINGS.STAGE.DELETE_CONFIRM_MESSAGE') }}
            </template>
          </p>
          <div class="flex justify-end gap-2">
            <button
              class="px-4 py-2 text-sm font-medium text-n-slate-12 bg-n-surface-2 rounded-lg hover:bg-n-surface-3"
              @click="cancelDeleteStage"
            >
              {{ t('CRM.SETTINGS.CANCEL') }}
            </button>
            <button
              class="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-lg hover:bg-red-700"
              :disabled="deletingStageHasDeals"
              @click="deleteStage"
            >
              {{ t('CRM.SETTINGS.DELETE') }}
            </button>
          </div>
        </div>
      </div>
    </teleport>
  </div>
</template>
