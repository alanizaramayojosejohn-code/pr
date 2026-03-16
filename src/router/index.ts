import { supabase } from "@/supabase";
import { createRouter, createWebHashHistory } from "vue-router";

const router = createRouter({
  history: createWebHashHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: "/",
      name: "home",
      component: () => import("@/components/TheWelcome.vue"),
    },
    {
      path: "/login",
      name: "login",
      component: () => import("@/ui/public/pages/MyLogin.vue"),
    },
    {
      path: "/tareas",
      name: "tareas",
      component: () => import("@/ui/admin/pages/MyTasks.vue"),
      meta: { requiresAuth: true },
    },
    {
      path: "/ejercicios",
      name: "ejercicios",
      component: () => import("@/ui/admin/pages/MyExercise.vue"),
      meta: { requiresAuth: true },
    },
  ],
});
router.beforeEach(async (to) => {
  if (to.meta.requiresAuth) {
    const { data } = await supabase.auth.getSession();
    if (!data.session) {
      return { name: "login" };
    }
  }
});
export default router;
