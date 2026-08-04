<script setup>
import { ref, computed } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { useAlert } from 'dashboard/composables';

const { t } = useI18n();
const route = useRoute();
const store = useStore();

const copied = ref(false);

const accountId = computed(() => route.params.accountId);
const currentUser = computed(() => store.getters.getCurrentUser);
const userToken = computed(() => currentUser.value?.access_token || '');

const feedUrl = computed(() => {
  if (!userToken.value) return '';
  const base = window.location.origin;
  return `${base}/api/v1/accounts/${accountId.value}/crm/calendar/feed.ics?user_token=${userToken.value}`;
});

const copyUrl = async () => {
  if (!feedUrl.value) return;
  try {
    await navigator.clipboard.writeText(feedUrl.value);
    copied.value = true;
    useAlert('URL copied to clipboard');
    setTimeout(() => { copied.value = false; }, 3000);
  } catch {
    // Fallback
    const input = document.createElement('input');
    input.value = feedUrl.value;
    document.body.appendChild(input);
    input.select();
    document.execCommand('copy');
    document.body.removeChild(input);
    copied.value = true;
    setTimeout(() => { copied.value = false; }, 3000);
  }
};
</script>

<template>
  <div class="flex flex-col h-full bg-n-surface-1 p-6 overflow-y-auto">
    <h1 class="text-lg font-semibold text-n-slate-12 mb-6">
      {{ t('CRM.INTEGRATIONS.TITLE') }}
    </h1>

    <!-- Calendar Feed Section -->
    <div class="bg-white dark:bg-n-slate-3 rounded-lg border border-n-weak p-6 max-w-2xl">
      <div class="flex items-center gap-3 mb-4">
        <span class="i-lucide-calendar w-5 h-5 text-n-brand" />
        <h2 class="text-base font-semibold text-n-slate-12">
          {{ t('CRM.INTEGRATIONS.CALENDAR.TITLE') }}
        </h2>
      </div>

      <p class="text-sm text-n-slate-11 mb-4">
        {{ t('CRM.INTEGRATIONS.CALENDAR.DESCRIPTION') }}
      </p>

      <!-- Feed URL -->
      <div v-if="feedUrl" class="mb-4">
        <label class="block mb-1 text-xs font-medium text-n-slate-10">
          {{ t('CRM.INTEGRATIONS.CALENDAR.YOUR_FEED_URL') }}
        </label>
        <div class="flex items-center gap-2">
          <input
            :value="feedUrl"
            type="text"
            readonly
            class="flex-1 h-10 px-3 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 font-mono text-xs"
            @click="$event.target.select()"
          />
          <NextButton
            :label="copied ? 'Copiado!' : 'Copiar'"
            :icon="copied ? 'i-lucide-check' : 'i-lucide-copy'"
            sm
            @click="copyUrl"
          />
        </div>
      </div>

      <div v-else class="mb-4 px-3 py-2 text-sm text-n-amber-11 bg-n-amber-3 border border-n-amber-6 rounded-lg">
        {{ t('CRM.INTEGRATIONS.CALENDAR.TOKEN_NOT_FOUND') }}
      </div>

      <!-- Instructions -->
      <div class="space-y-3 mt-6">
        <h3 class="text-sm font-medium text-n-slate-12">
          {{ t('CRM.INTEGRATIONS.CALENDAR.HOW_TO_USE') }}
        </h3>

        <div class="flex gap-3 p-3 bg-n-alpha-black2 rounded-lg">
          <span class="i-lucide-chrome w-5 h-5 text-n-slate-11 flex-shrink-0 mt-0.5" />
          <div>
            <p class="text-sm font-medium text-n-slate-12">Google Calendar</p>
            <ol class="text-xs text-n-slate-11 mt-1 list-decimal list-inside space-y-0.5">
              <li>Abra o Google Calendar</li>
              <li>No sidebar esquerdo, clique em "+" ao lado de "Outros calendários"</li>
              <li>Selecione "Por URL"</li>
              <li>Cole a URL acima e clique "Adicionar calendário"</li>
            </ol>
          </div>
        </div>

        <div class="flex gap-3 p-3 bg-n-alpha-black2 rounded-lg">
          <span class="i-lucide-mail w-5 h-5 text-n-slate-11 flex-shrink-0 mt-0.5" />
          <div>
            <p class="text-sm font-medium text-n-slate-12">Outlook / Microsoft 365</p>
            <ol class="text-xs text-n-slate-11 mt-1 list-decimal list-inside space-y-0.5">
              <li>Abra o Outlook Calendar</li>
              <li>Clique em "Adicionar calendário"</li>
              <li>Selecione "Da Internet"</li>
              <li>Cole a URL acima e clique "OK"</li>
            </ol>
          </div>
        </div>

        <p class="text-xs text-n-slate-10 mt-3">
          <span class="i-lucide-info w-3 h-3 inline-block align-middle mr-1" />
          {{ t('CRM.INTEGRATIONS.CALENDAR.SYNC_INFO') }}
        </p>
      </div>
    </div>
  </div>
</template>
