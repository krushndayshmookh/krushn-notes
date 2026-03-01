import { route } from 'quasar/wrappers'
import { createRouter, createMemoryHistory, createWebHistory, createWebHashHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const routes = [
  {
    path: '/login',
    component: () => import('../pages/AuthPage.vue'),
    meta: { public: true }
  },
  {
    path: '/auth/callback',
    component: () => import('../pages/AuthCallbackPage.vue'),
    meta: { public: true }
  },
  {
    path: '/',
    component: () => import('../layouts/MainLayout.vue'),
    children: [
      {
        path: '',
        redirect: '/notes'
      },
      {
        path: 'notes',
        component: () => import('../pages/NotesPage.vue')
      },
      {
        path: 'notes/:id',
        component: () => import('../pages/NotesPage.vue')
      },
      {
        path: 'tasks',
        component: () => import('../pages/TasksPage.vue')
      },
      {
        path: 'tasks/:listId',
        component: () => import('../pages/TasksPage.vue')
      }
    ]
  },
  {
    path: '/:catchAll(.*)*',
    component: () => import('../pages/ErrorNotFound.vue')
  }
]

export default route(function () {
  const createHistory = process.env.SERVER
    ? createMemoryHistory
    : (process.env.VUE_ROUTER_MODE === 'history' ? createWebHistory : createWebHashHistory)

  const router = createRouter({
    scrollBehavior: () => ({ left: 0, top: 0 }),
    routes,
    history: createHistory(process.env.VUE_ROUTER_BASE)
  })

  router.beforeEach((to) => {
    if (to.meta.public) return true
    const auth = useAuthStore()
    if (!auth.token) return { path: '/login' }
  })

  return router
})
