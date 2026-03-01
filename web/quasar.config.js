import { defineConfig } from '#q-app/wrappers'

export default defineConfig((ctx) => {
  return {
    boot: [
      'axios',
      'auth'
    ],

    css: ['app.scss'],

    extras: [
      'material-icons'
    ],

    build: {
      target: {
        browser: ['es2019', 'edge88', 'firefox78', 'chrome87', 'safari13.1'],
        node: 'node20'
      },
      vueRouterMode: 'history'
    },

    devServer: {
      open: false,
      port: 9000,
      proxy: {
        '/api': {
          target: 'http://localhost:3000',
          changeOrigin: true
        }
      }
    },

    framework: {
      config: {
        dark: 'auto'
      },
      plugins: [
        'Notify',
        'Dialog',
        'Loading'
      ]
    },

    animations: []
  }
})
