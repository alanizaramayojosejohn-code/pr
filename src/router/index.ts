import { createRouter, createWebHashHistory } from "vue-router";
import { useAuth } from "@/composables/useAuth";

const router = createRouter({
  history: createWebHashHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: "/",
      redirect: "/dashboard",
    },
    {
      path: "/login",
      name: "login",
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
      path: "/rutinas",
      name: "rutinas",
      component: () => import("@/ui/admin/pages/MyRoutines.vue"),
      meta: { requiresAuth: true },
    },
    {
      path: "/medidas",
      name: "medidas",
      component: () => import("@/ui/admin/pages/MyMeasurements.vue"),
      meta: { requiresAuth: true },
    },
    {
      path: "/entrenar/:sessionId",
      name: "entrenar",
      component: () => import("@/ui/admin/pages/MyWorkout.vue"),
      meta: { requiresAuth: true },
    },
    {
      path: "/progreso",
      name: "progreso",
      component: () => import("@/ui/admin/pages/MyProgress.vue"),
      meta: { requiresAuth: true },
    },
    {
      path: "/historial",
      name: "historial",
      component: () => import("@/ui/admin/pages/MyHistory.vue"),
      meta: { requiresAuth: true },
    },
    {
      path: "/aprender",
      name: "aprender",
      component: () => import("@/ui/admin/pages/MyLearn.vue"),
      meta: { requiresAuth: true },
    },
    {
      path: "/aprender/categoria/:slug",
      name: "aprender-categoria",
      component: () => import("@/ui/admin/pages/MyLearnCategory.vue"),
      meta: { requiresAuth: true },
    },
    {
      path: "/aprender/:slug",
      name: "aprender-detalle",
      component: () => import("@/ui/admin/pages/MyArticle.vue"),
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
      meta: { requiresAuth: true, requiresAdmin: true },
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
      meta: { requiresAuth: true, requiresAdmin: true },
    },
    {
      path: "/cuenta",
      name: "cuenta",
      component: () => import("@/ui/admin/pages/MyAccount.vue"),
      meta: { requiresAuth: true },
    },
    {
      path: "/:pathMatch(.*)*",
      redirect: "/dashboard",
    },
  ],
});

router.beforeEach(async (to) => {
  const { initPromise, isLoggedIn, isAdmin } = useAuth();
  await initPromise;

  if (to.meta.onlyGuest && isLoggedIn.value) {
    return { name: "dashboard" };
  }
  if (to.meta.requiresAuth && !isLoggedIn.value) {
    return { name: "login", query: { redirect: to.fullPath } };
  }
  if (to.meta.requiresAdmin && !isAdmin.value) {
    return { name: "dashboard" };
  }
});

export default router;
