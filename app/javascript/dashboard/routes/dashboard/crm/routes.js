import { frontendURL } from '../../../helper/URLHelper';
import { FEATURE_FLAGS } from '../../../featureFlags';

const CrmIndex = () => import('./pages/CrmIndex.vue');
const CrmActivitiesBoard = () => import('./pages/CrmActivitiesBoard.vue');
const PipelineSettings = () => import('./pages/PipelineSettings.vue');
const CrmIntegrations = () => import('./pages/CrmIntegrations.vue');

const commonMeta = {
  featureFlag: FEATURE_FLAGS.CRM,
  permissions: ['administrator', 'agent'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/crm'),
    name: 'crm_index',
    component: CrmIndex,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/crm/activities'),
    name: 'crm_activities_board',
    component: CrmActivitiesBoard,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/crm/integrations'),
    name: 'crm_integrations',
    component: CrmIntegrations,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/crm/settings'),
    name: 'crm_pipeline_settings',
    component: PipelineSettings,
    meta: {
      featureFlag: FEATURE_FLAGS.CRM,
      permissions: ['administrator'],
    },
  },
];
