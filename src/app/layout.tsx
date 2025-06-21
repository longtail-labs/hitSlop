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
  title: 'hitSlop.com - Gen AI Vibing Playground',
  description:
    'hitSlop is a creative vibe playground where ideas come to life through Gen AI. Effortlessly create, morph, and imagine visual concepts through an intuitive flow-based canvas. Currently focused on image generation, with more creative tools coming soon.',
  applicationName: 'hitSlop',
  keywords: [
    'AI Creativity',
    'Visual Playground',
    'Creative Flow',
    'AI Dreams',
    'Image Generation',
    'Creative Canvas',
    'Visual Imagination',
    'AI Art Studio',
    'Creative Workflows',
    'Generative Creativity',
    'Visual AI Playground',
    'Creative Expression',
  ],
  authors: [{ name: 'hitSlop', url: 'https://hitslop.com' }],
  creator: 'hitSlop',
  publisher: 'hitSlop',
  metadataBase: new URL('https://hitslop.com'),
  openGraph: {
    title: 'hitSlop - Creative Gen AI Vibing Playground',
    description:
      'Bring your ideas to life through Gen AI. Create, morph, and explore visual concepts with an intuitive creative playground.',
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
    title: 'hitSlop - Creative Gen AI Vibing Playground',
    description:
      'Bring your ideas to life through Gen AI. Create, morph, and explore visual concepts with an intuitive creative playground.',
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
