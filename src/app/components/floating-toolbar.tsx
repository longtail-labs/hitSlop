import { useReactFlow } from '@xyflow/react';
import { Image, Video, AudioWaveform } from 'lucide-react';
import { Button } from '@/app/components/ui/button';
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/app/components/ui/popover';
import { AppNode } from '@/app/nodes/types';
import { createNodeId } from '@/app/lib/utils';

interface FloatingToolbarProps {
  findNonOverlappingPosition: (
    _initialPosition: { x: number; y: number },
    _nodeType: string,
  ) => { x: number; y: number };
  setNodesToFocus: (_nodeId: string | null) => void;
}

export function FloatingToolbar({
  findNonOverlappingPosition,
  setNodesToFocus,
}: FloatingToolbarProps) {
  const { setNodes, screenToFlowPosition } = useReactFlow();

  const handleAddImageNode = () => {
    // Get the center of the current viewport
    const centerPosition = screenToFlowPosition({
      x: window.innerWidth / 2,
      y: window.innerHeight / 2,
    });

    // Find a non-overlapping position for the new node
    const nonOverlappingPosition = findNonOverlappingPosition(
      centerPosition,
      'prompt-node',
    );

    // Generate a unique ID using nanoid
    const newNodeId = createNodeId('prompt-node');

    // Create a new prompt node
    const newNode: AppNode = {
      id: newNodeId,
      type: 'prompt-node',
      position: nonOverlappingPosition,
      data: {
        prompt: '',
      },
      selectable: false,
    };

    // Add the new node to the flow
    setNodes((nds) => [...nds, newNode]);

    // Set the node to focus once it's initialized
    setNodesToFocus(newNodeId);
  };

  return (
    <div className="fixed bottom-6 left-1/2 transform -translate-x-1/2 z-50">
      <div className="bg-background/95 backdrop-blur-sm border border-border rounded-full px-4 py-2 shadow-lg">
        <div className="flex items-center gap-2">
          {/* Image Generation Button */}
          <Button
            variant="ghost"
            size="sm"
            onClick={handleAddImageNode}
            className="flex items-center gap-2 px-3 py-2 rounded-full hover:bg-accent font-recursive"
            style={{
              fontVariationSettings: '"MONO" 0.6, "wght" 500, "CASL" 0.4',
            }}
          >
            <Image size={18} />
            <span className="text-sm font-medium">Image</span>
          </Button>

          {/* Video Button with Coming Soon Popover */}
          <Popover>
            <PopoverTrigger asChild>
              <Button
                variant="ghost"
                size="sm"
                className="flex items-center gap-2 px-3 py-2 rounded-full hover:bg-accent cursor-default opacity-60 font-recursive"
                style={{
                  fontVariationSettings: '"MONO" 0.6, "wght" 500, "CASL" 0.4',
                }}
              >
                <Video size={18} />
                <span className="text-sm font-medium">Video</span>
              </Button>
            </PopoverTrigger>
            <PopoverContent className="w-48 p-3" side="top">
              <div className="text-center">
                <div
                  className="text-sm font-medium mb-1 font-recursive"
                  style={{
                    fontVariationSettings: '"MONO" 0.5, "wght" 600, "CASL" 0.3',
                  }}
                >
                  Coming Soon
                </div>
                <div
                  className="text-xs text-muted-foreground font-recursive"
                  style={{
                    fontVariationSettings: '"MONO" 0.3, "wght" 400, "CASL" 0.7',
                  }}
                >
                  Video generation will be available in a future update
                </div>
              </div>
            </PopoverContent>
          </Popover>

          {/* Audio Button with Coming Soon Popover */}
          <Popover>
            <PopoverTrigger asChild>
              <Button
                variant="ghost"
                size="sm"
                className="flex items-center gap-2 px-3 py-2 rounded-full hover:bg-accent cursor-default opacity-60 font-recursive"
                style={{
                  fontVariationSettings: '"MONO" 0.6, "wght" 500, "CASL" 0.4',
                }}
              >
                <AudioWaveform size={18} />
                <span className="text-sm font-medium">Audio</span>
              </Button>
            </PopoverTrigger>
            <PopoverContent className="w-48 p-3" side="top">
              <div className="text-center">
                <div
                  className="text-sm font-medium mb-1 font-recursive"
                  style={{
                    fontVariationSettings: '"MONO" 0.5, "wght" 600, "CASL" 0.3',
                  }}
                >
                  Coming Soon
                </div>
                <div
                  className="text-xs text-muted-foreground font-recursive"
                  style={{
                    fontVariationSettings: '"MONO" 0.3, "wght" 400, "CASL" 0.7',
                  }}
                >
                  Audio generation will be available in a future update
                </div>
              </div>
            </PopoverContent>
          </Popover>
        </div>
      </div>
    </div>
  );
}
