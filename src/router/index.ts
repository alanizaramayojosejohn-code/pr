import { createRouter, createWebHashHistory } from "vue-router";
import { useAuth } from "@/composables/useAuth";

const router = createRouter({
  history: createWebHashHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: "/",
      name: "landing",
      component: () => import("@/ui/public/pages/MyLanding.vue"),
    },
    {
      path: "/admin",
      name: "login",
      alias: "/login",
      component: () => import("@/ui/public/pages/MyLogin.vue"),
      meta: { onlyGuest: true },
    },
    {
      path: "/dashboard",
      name: "dashboard",
      component: () => import("@/ui/admin/pages/MyHome.vue"),
      meta: { requiresAuth: true },
    },
    {
      path: "/ejercicios",
      name: "ejercicios",
      component: () => import("@/ui/admin/pages/MyCategories.vue"),
      meta: { requiresAuth: true },
    },
    {
      path: "/ejercicios/:categoryId",
      name: "category-exercises",
      component: () => import("@/ui/admin/pages/MyCategoryExercises.vue"),
      meta: { requiresAuth: true },
    },
    {
      path: "/ejercicio/:id/edit",
      name: "exercise-edit",
      component: () => import("@/ui/admin/pages/MyExerciseEdit.vue"),
      meta: { requiresAuth: true },
    },
    {
      path: "/ejercicio/:id",
      name: "exercise-detail",
      component: () => import("@/ui/admin/pages/MyExerciseDetail.vue"),
      meta: { requiresAuth: true },
    },
    {
      path: "/usuarios",
      name: "usuarios",
      component: () => import("@/ui/admin/pages/MyUsers.vue"),
      meta: { requiresAuth: true },
    },
    {
      path: "/cuenta",
      name: "cuenta",
      component: () => import("@/ui/admin/pages/MyAccount.vue"),
      meta: { requiresAuth: true },
    },
    {
      path: "/:pathMatch(.*)*",
      redirect: "/",
    },
  ],
});

router.beforeEach(async (to) => {
  const { initPromise, isLoggedIn, isAdmin } = useAuth();
  await initPromise;

  // Un único criterio para ambas ramas. Si `onlyGuest` mirara solo isLoggedIn,
  // una sesión sin rol admin rebotaría /admin → /dashboard → /admin sin fin.
  const authorized = isLoggedIn.value && isAdmin.value;

  if (to.meta.onlyGuest && authorized) {
    return { name: "dashboard" };
  }
  if (to.meta.requiresAuth && !authorized) {
    return { path: "/admin", query: { redirect: to.fullPath } };
  }
});

export default router;
