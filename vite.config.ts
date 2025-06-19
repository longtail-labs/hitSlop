import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import path from 'path'

const ReactCompilerConfig = {
  // React 19 is already being used
  target: '19'
};

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    react({
      babel: {
        plugins: [
          ["babel-plugin-react-compiler", ReactCompilerConfig],
        ],
      },
    }), 
    tailwindcss(),
  ],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src')
    }
  },
  build: {
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: true,
        drop_debugger: true,
      },
    },
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom', '@xyflow/react'],
          ui: [
            '@radix-ui/react-dialog',
            '@radix-ui/react-dropdown-menu',
            '@radix-ui/react-label',
            '@radix-ui/react-menubar',
            '@radix-ui/react-popover',
            '@radix-ui/react-slot',
            '@radix-ui/react-tooltip',
          ],
          flow: [
            '@xyflow/react/dist/style.css',
          ],
          images: [],
        }
      }
    },
    target: 'esnext',
    cssCodeSplit: true,
    modulePreload: {
      polyfill: false,
    },
    sourcemap: false,
    assetsInlineLimit: 4096,
  },
  optimizeDeps: {
    include: [
      'react', 
      'react-dom', 
      '@xyflow/react',
      '@radix-ui/react-dialog',
      '@radix-ui/react-dropdown-menu',
      '@radix-ui/react-label',
      '@radix-ui/react-menubar',
      '@radix-ui/react-popover',
      '@radix-ui/react-slot',
      '@radix-ui/react-tooltip',
    ],
  }
})
