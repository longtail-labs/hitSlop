import { useState } from 'react';
import { Music, Image as ImageIcon, Smartphone, Layers, Mic } from 'lucide-react';
import { Button } from '@/app/components/ui/button';
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from '@/app/components/ui/tooltip';
import { UnsplashSheet } from './unsplash-sheet';

interface FloatingSidebarProps {
  findNonOverlappingPosition: (
    _initialPosition: { x: number; y: number },
    _nodeType: string,
  ) => { x: number; y: number };
  setNodesToFocus: (_nodeId: string | null) => void;
}

export function FloatingSidebar({
  findNonOverlappingPosition,
  setNodesToFocus,
}: FloatingSidebarProps) {
  const [isUnsplashOpen, setIsUnsplashOpen] = useState(false);

  return (
    <>
      <div className="fixed left-6 top-1/2 transform -translate-y-1/2 z-40">
        <div className="bg-background/95 backdrop-blur-sm border border-border rounded-full py-3 px-2 shadow-lg">
          <div className="flex flex-col items-center gap-2">
            {/* Unsplash Button */}
            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setIsUnsplashOpen(true)}
                  className="w-10 h-10 rounded-full p-0 hover:bg-accent"
                >
                  <svg 
                    xmlns="http://www.w3.org/2000/svg" 
                    viewBox="0 0 32 32" 
                    className="w-6 h-6"
                    fill="currentColor"
                  >
                    <path d="M10 9V0h12v9H10zm12 5h10v18H0V14h10v9h12v-9z" />
                  </svg>
                </Button>
              </TooltipTrigger>
              <TooltipContent side="right">
                <p>Unsplash</p>
              </TooltipContent>
            </Tooltip>

            {/* App Store Screenshots Button */}
            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  variant="ghost"
                  size="sm"
                  className="w-10 h-10 rounded-full p-0 opacity-60 cursor-default hover:bg-accent"
                >
                  <Smartphone size={20} />
                </Button>
              </TooltipTrigger>
              <TooltipContent side="right">
                <p>App Store Screenshots - Coming Soon</p>
              </TooltipContent>
            </Tooltip>

            {/* Logos Button */}
            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  variant="ghost"
                  size="sm"
                  className="w-10 h-10 rounded-full p-0 opacity-60 cursor-default hover:bg-accent"
                >
                  <Layers size={20} />
                </Button>
              </TooltipTrigger>
              <TooltipContent side="right">
                <p>Logos - Coming Soon</p>
              </TooltipContent>
            </Tooltip>

            {/* App Store Icons Button */}
            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  variant="ghost"
                  size="sm"
                  className="w-10 h-10 rounded-full p-0 opacity-60 cursor-default hover:bg-accent"
                >
                  <ImageIcon size={20} />
                </Button>
              </TooltipTrigger>
              <TooltipContent side="right">
                <p>App Store Icons - Coming Soon</p>
              </TooltipContent>
            </Tooltip>

            {/* Voices Button */}
            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  variant="ghost"
                  size="sm"
                  className="w-10 h-10 rounded-full p-0 opacity-60 cursor-default hover:bg-accent"
                >
                  <Mic size={20} />
                </Button>
              </TooltipTrigger>
              <TooltipContent side="right">
                <p>Voices - Coming Soon</p>
              </TooltipContent>
            </Tooltip>

            {/* Songs Button */}
            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  variant="ghost"
                  size="sm"
                  className="w-10 h-10 rounded-full p-0 opacity-60 cursor-default hover:bg-accent"
                >
                  <Music size={20} />
                </Button>
              </TooltipTrigger>
              <TooltipContent side="right">
                <p>Songs - Coming Soon</p>
              </TooltipContent>
            </Tooltip>
          </div>
        </div>
      </div>

      {/* Unsplash Sheet */}
      <UnsplashSheet
        isOpen={isUnsplashOpen}
        onOpenChange={setIsUnsplashOpen}
        findNonOverlappingPosition={findNonOverlappingPosition}
        setNodesToFocus={setNodesToFocus}
      />
    </>
  );
}