import { useState } from 'react';
import {
  Music,
  Image as ImageIcon,
  Smartphone,
  Layers,
  Mic,
  Upload,
} from 'lucide-react';
import { Button } from '@/app/components/ui/button';
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from '@/app/components/ui/tooltip';
import { UnsplashSheet } from './unsplash-sheet';
import { useFilePicker } from 'use-file-picker';
import { createImageNode } from '@/app/lib/utils';
import { useReactFlow } from '@xyflow/react';
import { imageService } from '@/app/services/database';
import { useNodePlacement } from '@/app/lib/useNodePlacement';

interface FloatingSidebarProps {
  setNodesToFocus: (_nodeId: string | null) => void;
}

export function FloatingSidebar({ setNodesToFocus }: FloatingSidebarProps) {
  const [isUnsplashOpen, setIsUnsplashOpen] = useState(false);
  const { setNodes } = useReactFlow();
  const { findNonOverlappingPosition } = useNodePlacement();

  const { openFilePicker, loading, errors } = useFilePicker({
    readAs: 'DataURL',
    accept: 'image/*',
    multiple: true,
    onFilesSelected: async ({ plainFiles, filesContent }) => {
      if (!plainFiles || plainFiles.length === 0) return;

      // Get initial position for the first node
      const initialPosition = { x: 100, y: 100 };
      let lastPosition = initialPosition;

      // Process each file sequentially
      for (const file of filesContent) {
        if (!file.content) continue;

        // Get non-overlapping position for this node
        lastPosition = findNonOverlappingPosition(
          { x: lastPosition.x + 20, y: lastPosition.y + 20 },
          'image-node',
        );

        try {
          // First, store the image to get a persistent ID
          const imageId = await imageService.storeImage(
            file.content,
            'uploaded',
          );

          // Now create the node using the ID
          const newNode = createImageNode(imageId, {
            position: lastPosition,
            source: 'uploaded',
            prompt: `Uploaded: ${file.name}`,
          });

          // Add the node to the flow using setNodes like in App.tsx
          setNodes((nds) => [...nds, newNode]);

          // Focus on the newly created node
          setTimeout(() => {
            setNodesToFocus(newNode.id);
          }, 100);
        } catch (error) {
          console.error('Error processing uploaded image:', error);
        }
      }
    },
  });

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
                <p
                  className="font-recursive"
                  style={{
                    fontVariationSettings: '"MONO" 0.7, "wght" 500, "CASL" 0.3',
                  }}
                >
                  Unsplash
                </p>
              </TooltipContent>
            </Tooltip>

            {/* Upload Image Button */}
            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => openFilePicker()}
                  className="w-10 h-10 rounded-full p-0 hover:bg-accent"
                >
                  <Upload size={20} />
                </Button>
              </TooltipTrigger>
              <TooltipContent side="right">
                <p
                  className="font-recursive"
                  style={{
                    fontVariationSettings: '"MONO" 0.7, "wght" 500, "CASL" 0.3',
                  }}
                >
                  Upload Images
                </p>
              </TooltipContent>
            </Tooltip>

            {loading && (
              <div className="fixed inset-0 flex items-center justify-center bg-black/50 z-50">
                <div className="bg-background p-4 rounded-md shadow-lg">
                  <div className="flex items-center gap-2">
                    <div className="animate-spin h-5 w-5 border-2 border-primary border-t-transparent rounded-full"></div>
                    <p
                      className="font-recursive"
                      style={{
                        fontVariationSettings:
                          '"MONO" 0.5, "wght" 500, "CASL" 0.4',
                      }}
                    >
                      Loading images...
                    </p>
                  </div>
                </div>
              </div>
            )}

            {errors.length > 0 && (
              <div className="fixed inset-0 flex items-center justify-center bg-black/50 z-50">
                <div className="bg-background p-4 rounded-md shadow-lg">
                  <div className="flex flex-col gap-2">
                    <p
                      className="text-destructive font-medium font-recursive"
                      style={{
                        fontVariationSettings:
                          '"MONO" 0.6, "wght" 600, "CASL" 0.2',
                      }}
                    >
                      Error loading images:
                    </p>
                    <ul className="list-disc pl-5">
                      {errors.map((error, index) => (
                        <li
                          key={index}
                          className="text-sm font-recursive"
                          style={{
                            fontVariationSettings:
                              '"MONO" 0.4, "wght" 400, "CASL" 0.5',
                          }}
                        >
                          {error.name}: {(error as any).reason || 'File error'}
                        </li>
                      ))}
                    </ul>
                    <Button
                      className="mt-2 font-recursive"
                      variant="outline"
                      onClick={() => window.location.reload()}
                      style={{
                        fontVariationSettings:
                          '"MONO" 0.5, "wght" 500, "CASL" 0.3',
                      }}
                    >
                      Dismiss
                    </Button>
                  </div>
                </div>
              </div>
            )}

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
                <p
                  className="font-recursive"
                  style={{
                    fontVariationSettings: '"MONO" 0.4, "wght" 400, "CASL" 0.6',
                  }}
                >
                  App Store Screenshots - Coming Soon
                </p>
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
                <p
                  className="font-recursive"
                  style={{
                    fontVariationSettings: '"MONO" 0.4, "wght" 400, "CASL" 0.6',
                  }}
                >
                  Logos - Coming Soon
                </p>
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
                <p
                  className="font-recursive"
                  style={{
                    fontVariationSettings: '"MONO" 0.4, "wght" 400, "CASL" 0.6',
                  }}
                >
                  App Store Icons - Coming Soon
                </p>
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
                <p
                  className="font-recursive"
                  style={{
                    fontVariationSettings: '"MONO" 0.4, "wght" 400, "CASL" 0.6',
                  }}
                >
                  Voices - Coming Soon
                </p>
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
                <p
                  className="font-recursive"
                  style={{
                    fontVariationSettings: '"MONO" 0.4, "wght" 400, "CASL" 0.6',
                  }}
                >
                  Songs - Coming Soon
                </p>
              </TooltipContent>
            </Tooltip>
          </div>
        </div>
      </div>

      {/* Unsplash Sheet */}
      <UnsplashSheet
        isOpen={isUnsplashOpen}
        onOpenChange={setIsUnsplashOpen}
        setNodesToFocus={setNodesToFocus}
      />
    </>
  );
}
