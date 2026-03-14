import './assets/main.css'

import { createApp } from 'vue'
import App from './App.vue'
import { registerSW } from 'virtual:pwa-register'
import router from './router'
registerSW({ immediate: true })
createApp(App).use(router).mount("#app");