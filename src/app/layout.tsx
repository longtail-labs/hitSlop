import React from 'react';
import './styles/index.css';
import './styles/styles.css';
import type { Metadata } from 'next';

// Import Recursive font from Google Fonts
import { Recursive } from 'next/font/google';

const recursive = Recursive({
  subsets: ['latin'],
  axes: ['MONO', 'CASL', 'slnt', 'CRSV'],
  variable: '--font-recursive',
});

export const metadata: Metadata = {
  title: 'hitSlop.com - Image Gen Playground',
  description:
    'hitSlop is an intuitive image generation playground powered by AI. Create, edit, and explore visual concepts through a flow-based canvas using OpenAI, Gemini, and FLUX models.',
  applicationName: 'hitSlop',
  keywords: [
    'AI Image Generation',
    'Image Gen Playground',
    'AI Art Creation',
    'Visual AI Studio',
    'Image Editing AI',
    'Creative Canvas',
    'AI Art Generator',
    'Image Creation Tool',
    'Visual AI Playground',
    'AI Image Editor',
    'Generative Art',
    'Creative AI Tools',
  ],
  authors: [{ name: 'hitSlop', url: 'https://hitslop.com' }],
  creator: 'hitSlop',
  publisher: 'hitSlop',
  metadataBase: new URL('https://hitslop.com'),
  openGraph: {
    title: 'hitSlop - Image Gen Playground',
    description:
      'Create and edit images with AI using OpenAI, Gemini, and FLUX. An intuitive flow-based canvas for visual creativity.',
    url: 'https://hitslop.com',
    siteName: 'hitSlop',
    images: [
      {
        url: '/logo.png',
        width: 1200,
        height: 630,
        alt: 'The hitSlop logo',
      },
    ],
    locale: 'en-US',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'hitSlop - Image Gen Playground',
    description:
      'Create and edit images with AI using OpenAI, Gemini, and FLUX. An intuitive flow-based canvas for visual creativity.',
    images: ['/logo.png'],
  },
  icons: {
    icon: '/favicon.ico',
    shortcut: '/favicon.ico',
    apple: '/apple-touch-icon.png',
  },
  manifest: '/site.webmanifest',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={recursive.variable}>
      <body className="font-recursive">
        <main className="min-h-screen">{children}</main>
      </body>
    </html>
  );
}
