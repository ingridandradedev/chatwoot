import { defineConfig } from 'vite';
import ruby from 'vite-plugin-ruby';
import vue from '@vitejs/plugin-vue';
import { aliases, vueOptions } from './vite.shared';
import yaml from '@rollup/plugin-yaml';

export default defineConfig({
  plugins: [ruby(), vue(vueOptions), yaml()],
  css: {
    preprocessorOptions: {
      scss: {
        api: 'modern-compiler',
      },
    },
  },
  resolve: { alias: aliases },
  server: {
    proxy: {
      '/auth': {
        target: 'https://chatwoot-production-fc3f.up.railway.app',
        changeOrigin: true,
        secure: true,
      },
      '/api': {
        target: 'https://chatwoot-production-fc3f.up.railway.app',
        changeOrigin: true,
        secure: true,
      },
      '/cable': {
        target: 'wss://chatwoot-production-fc3f.up.railway.app',
        ws: true,
        changeOrigin: true,
      },
    },
  },
});
