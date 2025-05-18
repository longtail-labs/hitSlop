import { Handle, Position, type NodeProps } from '@xyflow/react';
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
  DropdownMenuSeparator,
} from '@/components/ui/dropdown-menu';
import { Button } from '@/components/ui/button';
import useStore from '../store';
import { useShallow } from 'zustand/react/shallow';

export function PromptNode({ data, id, selected }: NodeProps) {
  const {
    findNonOverlappingPosition,
    setNodes,
    setEdges,
    rfInstance,
    setNodesToFocus,
    saveFlow,
    createImageNode,
  } = useStore(
    useShallow((state) => ({
      findNonOverlappingPosition: state.findNonOverlappingPosition,
      setNodes: state.setNodes,
      setEdges: state.setEdges,
      rfInstance: state.rfInstance,
      setNodesToFocus: state.setNodesToFocus,
      saveFlow: state.saveFlow,
      createImageNode: state.createImageNode,
    })),
  );

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
  const [outputFormat, setOutputFormat] = useState<string>(
    (data?.outputFormat as string) || 'png',
  );
  const [moderation, setModeration] = useState<string>(
    (data?.moderation as string) || 'auto',
  );
  const [background, setBackground] = useState<string>(
    (data?.background as string) || 'auto',
  );
  const [isProcessing, setIsProcessing] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [sourceImages, setSourceImages] = useState<string[]>(
    (data?.sourceImages as string[]) || [],
  );

  // Node dimensions for collision detection
  const IMAGE_NODE_DIMENSIONS = { width: 300, height: 300 };

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

    if (!rfInstance) {
      setError('Flow instance not initialized');
      return;
    }

    setIsProcessing(true);
    setError(null);

    try {
      // Get the position for the new node (below the current node)
      const currentNode = rfInstance.getNode(id);

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
        // Find a non-overlapping position for this image node
        const nonOverlappingPosition = findNonOverlappingPosition(
          {
            x: basePosition.x + i * 20, // Slight offset for multiple images
            y: basePosition.y + i * 20,
          },
          'image-node',
        );

        // Create a loading image node
        const loadingImageNode = createImageNode(nonOverlappingPosition, {
          isLoading: true,
          prompt: prompt,
        });

        newNodeIds.push(loadingImageNode.id);
        loadingImageNodes.push(loadingImageNode);

        // Add the loading node to the flow
        setNodes((nodes) => [...nodes, loadingImageNode] as AppNode[]);

        // Create an edge connecting the prompt node to each image node
        setEdges((edges) => [
          ...edges,
          {
            id: `edge-${id}-to-${loadingImageNode.id}`,
            source: id,
            target: loadingImageNode.id,
            sourceHandle: 'output',
            targetHandle: 'input',
          },
        ]);
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
        setNodes((nodes) => {
          return nodes.map((node) => {
            // Find the corresponding result node for this loading node
            const resultNodeIndex = loadingImageNodes.findIndex(
              (loadingNode) => loadingNode.id === node.id,
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
              } as AppNode;
            }
            return node;
          }) as AppNode[];
        });

        // Save flow after successful generation
        setTimeout(() => {
          saveFlow();
        }, 100);
      } else if (result.error) {
        // Update all loading nodes to show the error
        setNodes((nodes) => {
          return nodes.map((node) => {
            if (
              loadingImageNodes.some(
                (loadingNode) => loadingNode.id === node.id,
              )
            ) {
              return {
                ...node,
                data: {
                  ...node.data,
                  isLoading: false,
                  error: result.error,
                },
              } as AppNode;
            }
            return node;
          }) as AppNode[];
        });
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
    id,
    sourceImages,
    rfInstance,
    findNonOverlappingPosition,
    createImageNode,
    setNodes,
    setEdges,
    setNodesToFocus,
    saveFlow,
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
