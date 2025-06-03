import React from 'react';
import { Handle, Position, type NodeProps, useReactFlow } from '@xyflow/react';
import { useCallback, useRef, useState, KeyboardEvent, useEffect } from 'react';
import {
  processImageOperation,
  getModelConfig,
  ModelId,
} from '../services/imageGenerationService';
import { AppNode, ImageNodeData, SerializableGenerationParams } from './types';
import { BaseNode } from '@/components/base-node';
import {
  NodeHeader,
  NodeHeaderTitle,
  NodeHeaderIcon,
  NodeHeaderActions,
  NodeHeaderDeleteAction,
} from '@/components/node-header';
import { ImageIcon, Upload, X } from 'lucide-react';
import { ModelParameterControls } from '../components/ModelParameterControls';

export function PromptNode({ data, id, selected }: NodeProps) {
  const reactFlowInstance = useReactFlow();
  const {
    addNodes,
    addEdges,
    setNodes,
    getNode,
    getIntersectingNodes,
    fitView,
  } = reactFlowInstance;
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Main state
  const [prompt, setPrompt] = useState<string>((data?.prompt as string) || '');
  const [model, setModel] = useState<ModelId>(
    (data?.model as ModelId) || 'gpt-image-1',
  );
  const [sourceImages, setSourceImages] = useState<string[]>(
    (data?.sourceImages as string[]) || [],
  );
  const [error, setError] = useState<string | null>(null);

  // Dynamic model parameters
  const [modelParams, setModelParams] = useState<Record<string, any>>(() => {
    const config = getModelConfig(model);
    const initialParams: Record<string, any> = {
      size: config?.defaultSize || '1024x1024',
      n: 1,
    };

    // Set default values from model config
    config?.parameters.forEach((param) => {
      if (param.default !== undefined) {
        initialParams[param.name] = param.default;
      }
    });

    return initialParams;
  });

  // Update model parameters when model changes
  useEffect(() => {
    const config = getModelConfig(model);
    if (config) {
      setModelParams((prevParams) => {
        const newParams: Record<string, any> = {
          size: config.defaultSize,
          n: Math.min(prevParams.n || 1, config.maxImages),
        };

        // Set default values from model config
        config.parameters.forEach((param) => {
          if (param.default !== undefined) {
            newParams[param.name] = param.default;
          }
        });
        return newParams;
      });
    }
  }, [model]);

  // Node dimensions for collision detection
  const IMAGE_NODE_DIMENSIONS = { width: 300, height: 300 };

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

  const handleParameterChange = useCallback((paramName: string, value: any) => {
    setModelParams((prev) => ({
      ...prev,
      [paramName]: value,
    }));
  }, []);

  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    // Process each file and add to existing images
    const filesToProcess = Array.from(files).slice(0, 16); // Max 16 images
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

    setError(null);

    try {
      const currentNode = getNode(id);
      if (!currentNode) {
        throw new Error('Current node not found');
      }

      const basePosition = {
        x: currentNode.position.x,
        y: currentNode.position.y + 300,
      };

      // Create placeholder nodes for each image to be generated
      const loadingImageNodes: AppNode[] = [];
      const numImages = modelParams.n || 1;
      const newNodeIds: string[] = [];

      for (let i = 0; i < numImages; i++) {
        const imageNodeId = `image-node-${Date.now()}-${i}`;
        newNodeIds.push(imageNodeId);

        const nonOverlappingPosition = findNonOverlappingPosition(
          basePosition,
          i,
        );

        const loadingImageNode: AppNode = {
          id: imageNodeId,
          type: 'image-node',
          position: nonOverlappingPosition,
          data: {
            isLoading: model !== 'gpt-image-1', // No loading state for GPT Image 1 (has streaming)
            isStreaming: model === 'gpt-image-1', // Auto-enable streaming for GPT Image 1
            prompt: prompt,
          },
        };

        loadingImageNodes.push(loadingImageNode);
        addNodes(loadingImageNode);

        addEdges({
          id: `edge-${id}-to-${imageNodeId}`,
          source: id,
          target: imageNodeId,
          sourceHandle: 'output',
          targetHandle: 'input',
        });
      }

      const params = {
        prompt,
        model,
        sourceImages: sourceImages.length > 0 ? sourceImages : undefined,
        ...modelParams,
        // Streaming callbacks
        onPartialImageUpdate: (nodeId: string, partialImageUrl: string) => {
          setNodes((nodes) =>
            nodes.map((node) => {
              if (node.id === nodeId) {
                return {
                  ...node,
                  data: {
                    ...node.data,
                    partialImageUrl,
                    isStreaming: true,
                  },
                };
              }
              return node;
            }),
          );
        },
        onProgressUpdate: (nodeId: string, status: string) => {
          setNodes((nodes) =>
            nodes.map((node) => {
              if (node.id === nodeId) {
                return {
                  ...node,
                  data: {
                    ...node.data,
                    streamingProgress: status,
                  },
                };
              }
              return node;
            }),
          );
        },
      };

      // Create a serializable version of params without callback functions
      const loggedParams: Partial<SerializableGenerationParams> = {
        prompt,
        model,
        sourceImages: sourceImages.length > 0 ? sourceImages : undefined,
        ...modelParams,
      };
      console.log('Processing image with params (for logging):', loggedParams);

      const result = await processImageOperation(
        params,
        basePosition,
        newNodeIds[0],
      );

      if (result.success && result.nodes && result.nodes.length > 0) {
        // Update each loading node with the corresponding generated image
        setNodes((nodes) =>
          nodes.map((node) => {
            const resultNodeIndex = loadingImageNodes.findIndex(
              (loadingNode: AppNode) => loadingNode.id === node.id,
            );

            if (
              resultNodeIndex !== -1 &&
              result.nodes &&
              resultNodeIndex < result.nodes.length
            ) {
              const resultNode = result.nodes[resultNodeIndex];
              const finalImageData = resultNode.data as ImageNodeData;

              return {
                ...node,
                data: {
                  ...finalImageData,
                  isLoading: false,
                  isStreaming: false,
                  partialImageUrl:
                    finalImageData.partialImageUrl === undefined
                      ? undefined
                      : finalImageData.partialImageUrl,
                  streamingProgress:
                    finalImageData.streamingProgress === undefined
                      ? undefined
                      : finalImageData.streamingProgress,
                },
              };
            }
            return node;
          }),
        );

        if (newNodeIds.length > 0) {
          fitView({
            nodes: [{ id: newNodeIds[0] }],
            duration: 500,
            padding: 1.8,
            maxZoom: 0.8,
          });
        }
      } else if (result.error) {
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
    }
  }, [
    prompt,
    model,
    modelParams,
    sourceImages,
    addNodes,
    addEdges,
    setNodes,
    getNode,
    id,
    findNonOverlappingPosition,
    fitView,
  ]);

  const isEditMode = sourceImages.length > 0;

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

        <div className="p-2">
          {/* Dynamic Model Parameters with Model Selection */}
          <ModelParameterControls
            modelId={model}
            currentParams={modelParams}
            onParameterChange={handleParameterChange}
            className="mb-2"
            showModelSelector={true}
            selectedModel={model}
            onModelChange={setModel}
          />

          {/* Main Prompt Input with buttons inside */}
          <div className="relative">
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
              className="nodrag absolute right-2 bottom-2 w-7 h-7 flex items-center justify-center rounded bg-primary text-primary-foreground disabled:opacity-50"
              title={isEditMode ? 'Edit image' : 'Generate image'}
            >
              {'▶'}
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
