import React from 'react';
import './styles/index.css';
import './styles/styles.css';
import { Inter } from 'next/font/google';
import type { Metadata } from 'next';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'hitSlop.com - Generative Playground',
  description:
    'hitSlop is a generative playground for visual AI models. A node-based editor to chain models together and create unique generative pipelines. Experiment, collaborate, and share your creations.',
  applicationName: 'hitSlop',
  keywords: [
    'Generative AI',
    'Playground',
    'AI Models',
    'Image Generation',
    'Machine Learning',
    'Node-based editor',
    'AI workflow',
  ],
  authors: [{ name: 'hitSlop', url: 'https://hitslop.com' }],
  creator: 'hitSlop',
  publisher: 'hitSlop',
  metadataBase: new URL('https://hitslop.com'),
  openGraph: {
    title: 'hitSlop - Generative Playground',
    description: 'A node-based generative playground for visual AI models.',
    url: 'https://hitslop.com',
    siteName: 'hitSlop',
    images: [
      {
        url: '/hitslop.png',
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
    title: 'hitSlop - Generative Playground',
    description: 'A node-based generative playground for visual AI models.',
    images: ['/hitslop.png'],
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
    <html lang="en">
      <body className={inter.className}>
        <main className="min-h-screen">{children}</main>
      </body>
    </html>
  );
}
