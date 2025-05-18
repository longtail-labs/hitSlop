import {
  Handle,
  Position,
  type NodeProps,
  useReactFlow,
} from '@xyflow/react';
import { useCallback, useRef, useEffect, useState, KeyboardEvent } from 'react';
import { processImageOperation } from '../services/imageGenerationService';
import { AppNode, ImageNodeData } from './types';
import { BaseNode } from '@/components/base-node';
import {
  NodeHeader,
  NodeHeaderTitle,
  NodeHeaderIcon,
  NodeHeaderActions,
  NodeHeaderDeleteAction,
} from '@/components/node-header';
import { ImageIcon, Upload, X, Lock } from 'lucide-react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Button } from '@/components/ui/button';

export function PromptNode({ data, id, selected }: NodeProps) {
  const reactFlowInstance = useReactFlow();
  const {
    deleteElements,
    addNodes,
    addEdges,
    setNodes,
    getNode,
    getIntersectingNodes,
    fitView,
  } = reactFlowInstance;
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [prompt, setPrompt] = useState<string>((data?.prompt as string) || '');
  const [size, setSize] = useState<string>(
    (data?.size as string) || '1024x1024',
  );
  const [n, setN] = useState<number>((data?.n as number) || 1);
  const [quality, setQuality] = useState<string>(
    (data?.quality as string) || 'low',
  );
  const [outputFormat] = useState<string>(
    (data?.outputFormat as string) || 'png',
  );
  const [moderation] = useState<string>(
    (data?.moderation as string) || 'auto',
  );
  const [background, setBackground] = useState<string>(
    (data?.background as string) || 'auto',
  );
  const [, setIsProcessing] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [sourceImages, setSourceImages] = useState<string[]>(
    (data?.sourceImages as string[]) || [],
  );
  const [nodesToFocus, setNodesToFocus] = useState<string[]>([]);

  // Node dimensions for collision detection
  const IMAGE_NODE_DIMENSIONS = { width: 300, height: 300 };

  // Focus on a node when it's created
  // We need to track the last created node and focus on it
  // This effect will run whenever nodesToFocus changes
  useEffect(() => {
    if (nodesToFocus.length > 0) {
      // Set up a timer to focus on the node
      // This gives time for the node to be added to the flow
      const timer = setTimeout(() => {
        nodesToFocus.forEach((nodeId) => {
          fitView({
            nodes: [{ id: nodeId }],
            duration: 500,
            padding: 1.8, // Increased padding to show more context around the node
            maxZoom: 0.8, // Limit max zoom to prevent excessive zooming
          });
        });
        // Clear the focus list after focusing
        setNodesToFocus([]);
      }, 100); // Small delay to ensure node is rendered

      return () => clearTimeout(timer);
    }
  }, [nodesToFocus, fitView]);

  // Find a non-overlapping position for new image nodes
  const findNonOverlappingPosition = useCallback(
    (initialPosition: { x: number; y: number }, index: number) => {
      // Create a temporary node to check for intersections
      const tempNode = {
        id: 'temp',
        position: initialPosition,
        width: IMAGE_NODE_DIMENSIONS.width,
        height: IMAGE_NODE_DIMENSIONS.height,
      };

      let position = { ...initialPosition };

      // Arrange nodes in a grid pattern with spacing
      const gridColumns = 2; // Number of columns in the grid
      const horizontalSpacing = IMAGE_NODE_DIMENSIONS.width + 50;
      const verticalSpacing = IMAGE_NODE_DIMENSIONS.height + 50;

      // Calculate row and column based on index
      const column = index % gridColumns;
      const row = Math.floor(index / gridColumns);

      // Calculate initial grid position
      position = {
        x: initialPosition.x + column * horizontalSpacing,
        y: initialPosition.y + row * verticalSpacing,
      };

      // Check if this position causes overlaps
      let tempNodeAtPosition = { ...tempNode, position };
      let intersections = getIntersectingNodes(tempNodeAtPosition);

      // If there are intersections, try to find a better position with a spiral pattern
      if (intersections.length > 0) {
        const spiralStep = 100;
        let attempts = 0;
        let angle = 0;
        let radius = spiralStep;

        while (intersections.length > 0 && attempts < 30) {
          angle += 0.5;
          radius = spiralStep * (1 + angle / 10);

          position = {
            x: initialPosition.x + radius * Math.cos(angle),
            y: initialPosition.y + radius * Math.sin(angle),
          };

          tempNodeAtPosition = { ...tempNode, position };
          intersections = getIntersectingNodes(tempNodeAtPosition);
          attempts++;
        }
      }

      return position;
    },
    [getIntersectingNodes],
  );

  const handlePromptChange = useCallback(
    (evt: React.ChangeEvent<HTMLTextAreaElement>) => {
      const newPrompt = evt.target.value;
      setPrompt(newPrompt);
    },
    [],
  );


  const handleKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleProcess();
    }
  };

  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    // GPT-4 Vision supports up to 16 images for editing
    const maxFiles = 16;
    const filesToProcess = Array.from(files).slice(0, maxFiles);

    // Process each file and add to existing images
    filesToProcess.forEach((file) => {
      const reader = new FileReader();
      reader.onloadend = () => {
        const base64String = reader.result as string;
        setSourceImages((prev) => [...prev, base64String]);
      };
      reader.readAsDataURL(file);
    });
  };

  const handleRemoveImage = (index: number) => {
    setSourceImages((prev) => prev.filter((_, i) => i !== index));
  };

  const clearImages = () => {
    setSourceImages([]);
  };

  const handleProcess = useCallback(async () => {
    if (!prompt.trim()) {
      setError('Please enter a prompt');
      return;
    }

    setIsProcessing(true);
    setError(null);

    try {
      // Get the position for the new node (below the current node)
      const currentNode = getNode(id);

      if (!currentNode) {
        throw new Error('Current node not found');
      }

      // Position for the first image node
      const basePosition = {
        x: currentNode.position.x,
        y: currentNode.position.y + 300, // Place it below with some spacing
      };

      // Create placeholder nodes for each image to be generated
      const loadingImageNodes: AppNode[] = [];
      const numImages = n;
      const newNodeIds: string[] = [];

      for (let i = 0; i < numImages; i++) {
        const imageNodeId = `image-node-${Date.now()}-${i}`;
        newNodeIds.push(imageNodeId);

        // Find a non-overlapping position for this image node
        const nonOverlappingPosition = findNonOverlappingPosition(
          basePosition,
          i,
        );

        const loadingImageNode: AppNode = {
          id: imageNodeId,
          type: 'image-node',
          position: nonOverlappingPosition,
          data: {
            isLoading: true,
            prompt: prompt,
          },
        };

        loadingImageNodes.push(loadingImageNode);

        // Add the loading node to the flow
        addNodes(loadingImageNode);

        // Create an edge connecting the prompt node to each image node
        addEdges({
          id: `edge-${id}-to-${imageNodeId}`,
          source: id,
          target: imageNodeId,
          sourceHandle: 'output',
          targetHandle: 'input',
        });
      }

      // Add the new nodes to the focus list
      setNodesToFocus(newNodeIds);

      // Determine if this is a generation or edit operation based on whether we have source images
      const isEditOperation = sourceImages.length > 0;

      const params = {
        prompt,
        sourceImages: sourceImages.length > 0 ? sourceImages : undefined,
        model: 'gpt-image-1' as const,
        size: size as any,
        n,
        quality: quality as any,
        outputFormat: outputFormat as any,
        moderation: moderation as any,
        background: background as any,
      };

      const result = await processImageOperation(params, basePosition);

      if (result.success && result.nodes && result.nodes.length > 0) {
        // Update each loading node with the corresponding generated image
        setNodes((nodes) =>
          nodes.map((node) => {
            // Find the corresponding result node for this loading node
            const resultNodeIndex = loadingImageNodes.findIndex(
              (loadingNode: AppNode) => loadingNode.id === node.id,
            );

            if (
              resultNodeIndex !== -1 &&
              result.nodes &&
              resultNodeIndex < result.nodes.length
            ) {
              // Replace loading node with the generated image node data
              const resultNode = result.nodes[resultNodeIndex];
              const imageData = resultNode.data as ImageNodeData;

              return {
                ...node,
                data: {
                  ...node.data,
                  isLoading: false,
                  imageUrl: imageData.imageUrl,
                  generationParams: {
                    prompt,
                    model: 'gpt-image-1',
                    size,
                    n,
                    quality,
                    outputFormat,
                    moderation,
                    background,
                    isEdited: isEditOperation,
                  },
                },
              };
            }
            return node;
          }),
        );
      } else if (result.error) {
        // Update all loading nodes to show the error
        setNodes((nodes) =>
          nodes.map((node) => {
            if (
              loadingImageNodes.some(
                (loadingNode: AppNode) => loadingNode.id === node.id,
              )
            ) {
              return {
                ...node,
                data: {
                  ...node.data,
                  isLoading: false,
                  error: result.error,
                },
              };
            }
            return node;
          }),
        );
        setError(result.error);
      }
    } catch (err) {
      console.error('Error during image operation:', err);
      const errorMessage =
        err instanceof Error ? err.message : 'Unknown error occurred';

      setError(errorMessage);
    } finally {
      setIsProcessing(false);
    }
  }, [
    prompt,
    size,
    n,
    quality,
    outputFormat,
    moderation,
    background,
    addNodes,
    addEdges,
    setNodes,
    getNode,
    id,
    sourceImages,
    findNonOverlappingPosition,
  ]);

  const isEditMode = sourceImages.length > 0;

  // Size options mapping for display
  const sizeOptions = {
    '1024x1024': '1024²',
    '1536x1024': '1536×1024',
    '1024x1536': '1024×1536',
  };

  // Dropdown label formatting helper
  const formatDropdownLabel = (value: string) => {
    return value.charAt(0).toUpperCase() + value.slice(1);
  };

  return (
    <div>
      <Handle type="target" position={Position.Top} id="input" />
      <BaseNode selected={selected} className="prompt-node p-0">
        <NodeHeader className="border-b">
          <NodeHeaderIcon>
            <ImageIcon size={18} />
          </NodeHeaderIcon>
          <NodeHeaderTitle>
            {isEditMode ? 'Edit Image' : 'Generate Image'}
          </NodeHeaderTitle>
          <NodeHeaderActions>
            <NodeHeaderDeleteAction />
          </NodeHeaderActions>
        </NodeHeader>

        <div className="p-3">
          {/* Options in a row */}
          <div className="flex gap-2 mb-2">
            {/* Size Dropdown */}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button
                  variant="outline"
                  size="sm"
                  className="h-8 text-xs px-2 py-1 bg-muted border border-border w-24"
                >
                  {sizeOptions[size as keyof typeof sizeOptions]}
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent>
                {Object.entries(sizeOptions).map(([value, label]) => (
                  <DropdownMenuItem
                    key={value}
                    onClick={() => setSize(value)}
                    className={size === value ? 'bg-accent' : ''}
                  >
                    {label}
                  </DropdownMenuItem>
                ))}
              </DropdownMenuContent>
            </DropdownMenu>

            {/* Quality Dropdown */}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button
                  variant="outline"
                  size="sm"
                  className="h-8 text-xs px-2 py-1 bg-muted border border-border w-24"
                >
                  {formatDropdownLabel(quality)}
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent>
                <DropdownMenuItem
                  onClick={() => setQuality('low')}
                  className={quality === 'low' ? 'bg-accent' : ''}
                >
                  Low
                </DropdownMenuItem>
                <DropdownMenuItem
                  onClick={() => setQuality('medium')}
                  className={quality === 'medium' ? 'bg-accent' : ''}
                >
                  Medium
                </DropdownMenuItem>
                <DropdownMenuItem
                  onClick={() => setQuality('high')}
                  className={quality === 'high' ? 'bg-accent' : ''}
                >
                  <div className="flex items-center gap-1">
                    High
                    <Lock size={14} />
                  </div>
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>

            {/* Number of Images Dropdown */}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button
                  variant="outline"
                  size="sm"
                  className="h-8 text-xs px-2 py-1 bg-muted border border-border w-24"
                >
                  {n} {n === 1 ? 'img' : 'imgs'}
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent>
                {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((num) => (
                  <DropdownMenuItem
                    key={num}
                    onClick={() => setN(num)}
                    className={n === num ? 'bg-accent' : ''}
                  >
                    {num} {num === 1 ? 'img' : 'imgs'}
                  </DropdownMenuItem>
                ))}
              </DropdownMenuContent>
            </DropdownMenu>

            {/* Background Dropdown */}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button
                  variant="outline"
                  size="sm"
                  className="h-8 text-xs px-2 py-1 bg-muted border border-border w-24"
                >
                  {formatDropdownLabel(background)}
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent>
                <DropdownMenuItem
                  onClick={() => setBackground('opaque')}
                  className={background === 'opaque' ? 'bg-accent' : ''}
                >
                  Opaque
                </DropdownMenuItem>
                <DropdownMenuItem
                  onClick={() => setBackground('transparent')}
                  className={background === 'transparent' ? 'bg-accent' : ''}
                >
                  Transparent
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>

          {/* Main Prompt Input with buttons inside */}
          <div className="relative mb-2">
            <textarea
              ref={textareaRef}
              value={prompt}
              onChange={handlePromptChange}
              onKeyDown={handleKeyDown}
              placeholder={
                isEditMode ? 'Edit this image...' : 'Create an image...'
              }
              className="nodrag w-full p-2 h-24 min-h-24 max-h-24 rounded border border-input bg-background resize-none"
              onClick={(e) => e.stopPropagation()}
              onWheelCapture={(e) => {
                e.stopPropagation();
              }}
            />

            {/* Upload Image Button */}
            <label
              htmlFor={`image-upload-${id}`}
              className="nodrag absolute right-2 top-2 cursor-pointer text-muted-foreground hover:text-foreground"
            >
              <Upload size={16} />
            </label>
            <input
              id={`image-upload-${id}`}
              ref={fileInputRef}
              type="file"
              accept="image/png,image/jpeg,image/webp"
              onChange={handleImageUpload}
              multiple
              className="nodrag hidden"
            />

            {/* Generate Button */}
            <button
              onClick={handleProcess}
              className="nodrag absolute right-2 bottom-2 w-7 h-7 flex items-center justify-center rounded bg-primary text-primary-foreground"
              title={isEditMode ? 'Edit image' : 'Generate image'}
            >
              ▶
            </button>
          </div>

          {/* Error Message */}
          {error && (
            <div className="text-sm text-destructive mb-2">{error}</div>
          )}

          {/* Source Images Display */}
          {sourceImages.length > 0 && (
            <div className="flex flex-wrap gap-1.5 bg-muted p-1.5 rounded">
              {sourceImages.map((img, index) => (
                <div key={index} className="relative w-12 h-12">
                  <img
                    src={img}
                    alt={`Selected ${index}`}
                    className="w-full h-full object-cover rounded"
                  />
                  <button
                    onClick={() => handleRemoveImage(index)}
                    className="nodrag absolute -top-1 -right-1 w-4 h-4 rounded-full bg-destructive text-destructive-foreground flex items-center justify-center text-xs"
                  >
                    <X size={10} />
                  </button>
                </div>
              ))}
              {sourceImages.length > 0 && (
                <button
                  onClick={clearImages}
                  className="nodrag bg-muted-foreground/20 border-none cursor-pointer text-muted-foreground px-1.5 py-0.5 rounded text-xs self-start"
                >
                  Clear
                </button>
              )}
            </div>
          )}
        </div>
      </BaseNode>
      <Handle type="source" position={Position.Bottom} id="output" />
    </div>
  );
}

// Make this node non-selectable
PromptNode.selectable = false;
