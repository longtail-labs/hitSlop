import { Play } from 'lucide-react';
import { Button } from '@/app/components/ui/button';
import { EXTERNAL_LINKS } from '@/app/config/links';

interface MobileViewProps {
  onPlayClick: () => void;
}

export function MobileView({ onPlayClick }: MobileViewProps) {
  return (
    <div className="min-h-screen bg-white flex flex-col items-center justify-center p-6 text-center">
      {/* Logo and Title Section */}
      <div className="mb-8">
        <div className="flex items-center justify-center gap-3 mb-4">
          <img
            src="/logo.png"
            alt="hitSlop logo"
            className="w-12 h-12 border border-gray-300 rounded shadow-md"
          />
          <h1
            className="font-recursive text-3xl"
            style={{
              fontVariationSettings: '"MONO" 1, "wght" 700, "CASL" 0',
              fontWeight: 700,
              letterSpacing: '-0.02em',
            }}
          >
            hitSlop.com
          </h1>
        </div>

        <h2
          className="font-recursive text-xl mb-4"
          style={{
            fontWeight: 'bold',
            fontVariationSettings:
              '"MONO" 0.3, "wght" 600, "CASL" 0.8, "CRSV" 0.5',
          }}
        >
          Image Gen Playground
        </h2>

        <div
          className="font-recursive text-gray-600 space-y-1"
          style={{
            fontSize: '16px',
            lineHeight: '1.4',
            fontVariationSettings: '"MONO" 0.5, "wght" 400, "CASL" 0.6',
          }}
        >
          <p>Create and edit images with OpenAI, Gemini, and FLUX</p>
          <p>Flow-based canvas for AI-powered image generation</p>
        </div>
      </div>

      {/* Tutorial Section */}
      <div className="w-full max-w-sm mb-8">
        <div
          className="relative bg-gray-100 h-48 flex items-center justify-center cursor-pointer rounded-lg overflow-hidden shadow-md"
          onClick={onPlayClick}
        >
          {/* Background gradient */}
          <div className="absolute inset-0 bg-gradient-to-br from-blue-400 to-purple-600 opacity-20"></div>

          {/* Play button overlay */}
          <div className="relative z-10 bg-white bg-opacity-90 rounded-full p-4 hover:bg-opacity-100 transition-all duration-200 shadow-lg">
            <Play className="h-8 w-8 text-blue-600 ml-1" fill="currentColor" />
          </div>

          {/* Tutorial preview content */}
          <div className="absolute bottom-4 left-4 right-4 text-center">
            <div className="bg-black bg-opacity-50 text-white px-3 py-2 rounded text-sm">
              Quick Demo Preview
            </div>
          </div>
        </div>

        <div className="mt-4">
          <h3 className="font-bold text-lg mb-2">See how it works</h3>
          <p className="text-gray-600 text-sm mb-3">
            Watch a quick tutorial to learn how to create and edit images with
            hitSlop
          </p>
          <Button onClick={onPlayClick} className="w-full" size="sm">
            <Play className="h-4 w-4 mr-2" />
            Watch Tutorial
          </Button>
        </div>
      </div>

      {/* Desktop Only Notice */}
      <div className="w-full max-w-md bg-yellow-50 border border-yellow-200 rounded-lg p-4">
        <div className="flex items-center justify-center mb-2">
          <svg
            className="w-5 h-5 text-yellow-600 mr-2"
            fill="currentColor"
            viewBox="0 0 20 20"
          >
            <path
              fillRule="evenodd"
              d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
              clipRule="evenodd"
            />
          </svg>
          <h4 className="font-semibold text-yellow-800">Desktop Only</h4>
        </div>
        <p className="text-yellow-700 text-sm">
          hitSlop currently only works on desktop environments. Please visit us
          on a computer to start creating!
        </p>
      </div>

      {/* Footer links */}
      <div className="mt-8 flex gap-4 text-sm">
        <a
          href={EXTERNAL_LINKS.github}
          target="_blank"
          rel="noopener noreferrer"
          className="text-blue-600 hover:text-blue-800"
        >
          GitHub
        </a>
        <a
          href={EXTERNAL_LINKS.discord}
          target="_blank"
          rel="noopener noreferrer"
          className="text-blue-600 hover:text-blue-800"
        >
          Discord
        </a>
      </div>
    </div>
  );
}
