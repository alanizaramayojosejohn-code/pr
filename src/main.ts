import './assets/main.css'

import { createApp } from 'vue'
import { Capacitor } from '@capacitor/core'
import App from './App.vue'
import { registerSW } from 'virtual:pwa-register'
import router from './router'

if (!Capacitor.isNativePlatform()) {
  registerSW({ immediate: true })
}

createApp(App).use(router).mount("#app");