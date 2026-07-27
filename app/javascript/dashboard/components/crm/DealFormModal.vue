<script setup>
import { ref, computed, watch } from 'vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ContactAPI from 'dashboard/api/contacts';

const props = defineProps({
  show: { type: Boolean, default: false },
  pipelineId: { type: [Number, String], required: true },
  stages: { type: Array, default: () => [] },
  deal: { type: Object, default: null },
});

const emit = defineEmits(['submit', 'close']);

// Form state
const contactId = ref(null);
const contactName = ref('');
const stageId = ref(null);
const title = ref('');
const value = ref(null);

// Contact search state
const contactSearch = ref('');
const contactResults = ref([]);
const isSearching = ref(false);
const showContactDropdown = ref(false);
let searchTimeout = null;

const isEditing = computed(() => !!props.deal);

const isValid = computed(() => {
  return !!contactId.value && !!stageId.value;
});

const headerTitle = computed(() => {
  return isEditing.value ? 'Edit Deal' : 'New Deal';
});

// Pre-fill form when editing
watch(
  () => props.deal,
  newDeal => {
    if (newDeal) {
      contactId.value = newDeal.contact_id || newDeal.contactId || null;
      contactName.value = newDeal.contact_name || newDeal.contactName || '';
      stageId.value = newDeal.stage_id || newDeal.stageId || null;
      title.value = newDeal.title || '';
      value.value = newDeal.value ?? null;
      contactSearch.value = contactName.value;
    }
  },
  { immediate: true }
);

// Pre-select first stage if not editing
watch(
  () => props.stages,
  newStages => {
    if (!isEditing.value && newStages.length && !stageId.value) {
      stageId.value = newStages[0].id;
    }
  },
  { immediate: true }
);

// Reset form when modal is shown
watch(
  () => props.show,
  newShow => {
    if (newShow && !isEditing.value) {
      resetForm();
    }
  }
);

function resetForm() {
  contactId.value = null;
  contactName.value = '';
  contactSearch.value = '';
  stageId.value = props.stages.length ? props.stages[0].id : null;
  title.value = '';
  value.value = null;
  contactResults.value = [];
  showContactDropdown.value = false;
}

async function searchContacts(query) {
  if (!query || query.length < 2) {
    contactResults.value = [];
    showContactDropdown.value = false;
    return;
  }

  isSearching.value = true;
  try {
    const response = await ContactAPI.search(query);
    contactResults.value = response.data.payload || response.data || [];
    showContactDropdown.value = contactResults.value.length > 0;
  } catch {
    contactResults.value = [];
    showContactDropdown.value = false;
  } finally {
    isSearching.value = false;
  }
}

function onContactSearchInput(event) {
  const query = event.target.value;
  contactSearch.value = query;

  // Clear selection if user modifies search after selecting
  if (contactId.value && query !== contactName.value) {
    contactId.value = null;
    contactName.value = '';
  }

  clearTimeout(searchTimeout);
  searchTimeout = setTimeout(() => searchContacts(query), 300);
}

function selectContact(contact) {
  contactId.value = contact.id;
  contactName.value = contact.name || contact.email || `Contact #${contact.id}`;
  contactSearch.value = contactName.value;
  showContactDropdown.value = false;
  contactResults.value = [];
}

function handleSubmit() {
  if (!isValid.value) return;

  emit('submit', {
    contact_id: contactId.value,
    stage_id: stageId.value,
    title: title.value || null,
    value: value.value ? Number(value.value) : null,
    pipeline_id: props.pipelineId,
  });
}

function closeModal() {
  showContactDropdown.value = false;
  emit('close');
}
</script>

<template>
  <woot-modal :show="show" :on-close="closeModal">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header :header-title="headerTitle" />

      <form class="flex flex-col w-full gap-4" @submit.prevent="handleSubmit">
        <!-- Contact selector -->
        <div class="relative w-full">
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            Contact <span class="text-n-ruby-9">*</span>
          </label>
          <input
            :value="contactSearch"
            type="text"
            class="w-full h-10 px-3 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:border-n-brand"
            placeholder="Search contacts by name..."
            :disabled="isEditing"
            @input="onContactSearchInput"
            @focus="
              showContactDropdown =
                contactResults.length > 0 && !contactId
            "
            @blur="
              setTimeout(() => {
                showContactDropdown = false;
              }, 200)
            "
          />
          <div v-if="isSearching" class="absolute text-xs right-3 top-9 text-n-slate-10">
            Searching...
          </div>
          <!-- Contact dropdown results -->
          <ul
            v-if="showContactDropdown"
            class="absolute z-10 w-full mt-1 overflow-y-auto bg-white border rounded-lg shadow-lg dark:bg-n-solid-2 border-n-weak max-h-48"
          >
            <li
              v-for="contact in contactResults"
              :key="contact.id"
              class="px-3 py-2 text-sm cursor-pointer text-n-slate-12 hover:bg-n-alpha-2"
              @mousedown.prevent="selectContact(contact)"
            >
              <span class="font-medium">{{ contact.name || 'Unnamed' }}</span>
              <span v-if="contact.email" class="ml-2 text-n-slate-10">
                {{ contact.email }}
              </span>
            </li>
          </ul>
          <p v-if="!contactId && contactSearch.length >= 2 && !isSearching && !showContactDropdown" class="mt-1 text-xs text-n-slate-10">
            No contacts found
          </p>
        </div>

        <!-- Stage selector -->
        <div class="w-full">
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            Stage <span class="text-n-ruby-9">*</span>
          </label>
          <select
            v-model="stageId"
            class="w-full h-10 px-3 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
          >
            <option v-for="stage in stages" :key="stage.id" :value="stage.id">
              {{ stage.name }}
            </option>
          </select>
        </div>

        <!-- Title input -->
        <div class="w-full">
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            Title
          </label>
          <input
            v-model="title"
            type="text"
            class="w-full h-10 px-3 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:border-n-brand"
            placeholder="Deal title (optional)"
          />
        </div>

        <!-- Value input -->
        <div class="w-full">
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            Value
          </label>
          <input
            v-model="value"
            type="number"
            step="0.01"
            min="0"
            max="999999999.99"
            class="w-full h-10 px-3 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:border-n-brand"
            placeholder="0.00"
          />
        </div>

        <!-- Actions -->
        <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
          <NextButton
            faded
            slate
            type="reset"
            label="Cancel"
            @click.prevent="closeModal"
          />
          <NextButton
            type="submit"
            :label="isEditing ? 'Update Deal' : 'Create Deal'"
            :disabled="!isValid"
          />
        </div>
      </form>
    </div>
  </woot-modal>
</template>
