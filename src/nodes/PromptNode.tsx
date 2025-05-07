import { Handle, Position, type NodeProps, useReactFlow } from '@xyflow/react';
import { useCallback, useRef, useEffect, useState, KeyboardEvent } from 'react';
import { processImageOperation } from '../services/imageGenerationService';
import { AppNode, ImageNodeData } from './types';

export function PromptNode({ data, id }: NodeProps) {
  const reactFlowInstance = useReactFlow();
  const {
    deleteElements,
    addNodes,
    addEdges,
    setNodes,
    getNode,
    getIntersectingNodes,
  } = reactFlowInstance;
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [prompt, setPrompt] = useState<string>((data?.prompt as string) || '');
  const [size, setSize] = useState<string>(
    (data?.size as string) || '1024x1024',
  );
  const [n, setN] = useState<number>((data?.n as number) || 1);
  const [quality, setQuality] = useState<string>(
    (data?.quality as string) || 'auto',
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

  const handleDelete = useCallback(() => {
    deleteElements({ nodes: [{ id }] });
  }, [deleteElements, id]);

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

      for (let i = 0; i < numImages; i++) {
        const imageNodeId = `image-node-${Date.now()}-${i}`;
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

  return (
    <div
      className="react-flow__node-default prompt-node"
      style={{
        width: '420px',
        borderRadius: '8px',
        boxShadow: '0 2px 6px rgba(0, 0, 0, 0.1)',
        backgroundColor: '#ffffff',
        border: '1px solid #e0e0e0',
        color: '#333333',
      }}
    >
      <div style={{ padding: '8px' }}>
        <Handle type="target" position={Position.Top} id="input" />

        {/* Top toolbar with options */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            marginBottom: '8px',
            gap: '6px',
          }}
        >
          {/* Left: Close button */}
          <button
            onClick={handleDelete}
            className="nodrag"
            style={{
              backgroundColor: 'transparent',
              border: 'none',
              cursor: 'pointer',
              color: '#f44336',
              padding: '0px 4px',
              fontSize: '14px',
              lineHeight: 1,
            }}
          >
            ✕
          </button>

          {/* Options in a row */}
          <div
            style={{
              display: 'flex',
              gap: '5px',
              flexGrow: 1,
              justifyContent: 'flex-start',
            }}
          >
            {/* Size Option */}
            <select
              value={size}
              onChange={(e) => setSize(e.target.value)}
              className="nodrag prompt-option-select"
              style={{
                padding: '3px 6px',
                fontSize: '13px',
                backgroundColor: '#f5f5f5',
                border: '1px solid #e0e0e0',
                borderRadius: '4px',
                color: '#333',
              }}
            >
              <option value="1024x1024">1024²</option>
              <option value="1536x1024">1536×1024</option>
              <option value="1024x1536">1024×1536</option>
            </select>

            {/* Quality Option */}
            <select
              value={quality}
              onChange={(e) => setQuality(e.target.value)}
              className="nodrag prompt-option-select"
              style={{
                padding: '3px 6px',
                fontSize: '13px',
                backgroundColor: '#f5f5f5',
                border: '1px solid #e0e0e0',
                borderRadius: '4px',
                color: '#333',
              }}
            >
              {/* <option value="auto">Quality</option> */}
              <option value="low">Low</option>
              <option value="medium">Medium</option>
              <option value="high">High</option>
            </select>

            {/* Number Option */}
            <select
              value={n}
              onChange={(e) => setN(parseInt(e.target.value))}
              className="nodrag prompt-option-select"
              style={{
                padding: '3px 6px',
                fontSize: '13px',
                backgroundColor: '#f5f5f5',
                border: '1px solid #e0e0e0',
                borderRadius: '4px',
                color: '#333',
              }}
            >
              <option value="1">1 img</option>
              <option value="2">2 imgs</option>
              <option value="4">4 imgs</option>
              <option value="9">9 imgs</option>
            </select>

            {/* Background Option */}
            <select
              value={background}
              onChange={(e) => setBackground(e.target.value)}
              className="nodrag prompt-option-select"
              style={{
                padding: '3px 6px',
                fontSize: '13px',
                backgroundColor: '#f5f5f5',
                border: '1px solid #e0e0e0',
                borderRadius: '4px',
                color: '#333',
              }}
            >
              <option value="opaque">Opaque</option>
              <option value="transparent">Transparent</option>
            </select>
          </div>
        </div>

        {/* Main Prompt Input with buttons inside */}
        <div
          style={{
            position: 'relative',
            marginBottom: sourceImages.length > 0 ? '8px' : '0',
          }}
        >
          <textarea
            ref={textareaRef}
            value={prompt}
            onChange={handlePromptChange}
            onKeyDown={handleKeyDown}
            placeholder={
              isEditMode ? 'Edit this image...' : 'Create an image...'
            }
            className="nodrag ai-prompt-input"
            style={{
              width: '100%',
              padding: '10px',
              height: '100px',
              maxHeight: '100px',
              minHeight: '100px',
              borderRadius: '6px',
              border: '1px solid #e0e0e0',
              backgroundColor: '#f5f5f5',
              fontSize: '14px',
              color: '#333',
              resize: 'none',
              overflowY: 'auto',
            }}
            onClick={(e) => e.stopPropagation()}
            onWheelCapture={(e) => {
              e.stopPropagation();
            }}
          />

          {/* Upload Image Button (Top Right Inside Input) */}
          <label
            htmlFor="image-upload"
            className="nodrag"
            style={{
              position: 'absolute',
              right: '10px',
              top: '10px',
              cursor: 'pointer',
              color: '#9e9e9e',
              fontSize: '16px',
            }}
          >
            📎
          </label>
          <input
            id="image-upload"
            ref={fileInputRef}
            type="file"
            accept="image/png,image/jpeg,image/webp"
            onChange={handleImageUpload}
            multiple
            className="nodrag"
            style={{ display: 'none' }}
          />

          {/* Generate Button (Bottom Right Inside Input) */}
          <button
            onClick={handleProcess}
            className="nodrag"
            disabled={isProcessing}
            title={
              isProcessing
                ? 'Processing...'
                : isEditMode
                ? 'Edit image'
                : 'Generate image'
            }
            style={{
              position: 'absolute',
              right: '10px',
              bottom: '10px',
              width: '28px',
              height: '28px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              borderRadius: '4px',
              backgroundColor: '#4285f4',
              color: 'white',
              border: 'none',
              cursor: 'pointer',
              fontSize: '14px',
              padding: 0,
            }}
          >
            {isProcessing ? '⏳' : '▶'}
          </button>
        </div>

        {/* Error Message */}
        {error && (
          <div
            style={{ color: '#f44336', fontSize: '12px', marginBottom: '8px' }}
          >
            {error}
          </div>
        )}

        {/* Source Images Display (Below Text Input) */}
        {sourceImages.length > 0 && (
          <div
            style={{
              display: 'flex',
              flexWrap: 'wrap',
              gap: '6px',
              backgroundColor: '#f5f5f5',
              padding: '6px',
              borderRadius: '4px',
            }}
          >
            {sourceImages.map((img, index) => (
              <div
                key={index}
                style={{
                  position: 'relative',
                  width: '50px',
                  height: '50px',
                }}
              >
                <img
                  src={img}
                  alt={`Selected ${index}`}
                  style={{
                    width: '100%',
                    height: '100%',
                    objectFit: 'cover',
                    borderRadius: '4px',
                  }}
                />
                <button
                  onClick={() => handleRemoveImage(index)}
                  className="nodrag"
                  style={{
                    position: 'absolute',
                    top: '-5px',
                    right: '-5px',
                    width: '16px',
                    height: '16px',
                    borderRadius: '50%',
                    backgroundColor: '#f44336',
                    color: 'white',
                    border: 'none',
                    fontSize: '8px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    cursor: 'pointer',
                    padding: 0,
                  }}
                >
                  ✕
                </button>
              </div>
            ))}
            {sourceImages.length > 0 && (
              <button
                onClick={clearImages}
                className="nodrag"
                style={{
                  backgroundColor: '#e0e0e0',
                  border: 'none',
                  cursor: 'pointer',
                  color: '#333',
                  padding: '1px 4px',
                  borderRadius: '3px',
                  fontSize: '10px',
                  alignSelf: 'flex-start',
                }}
              >
                Clear
              </button>
            )}
          </div>
        )}
      </div>
      <Handle type="source" position={Position.Bottom} id="output" />
    </div>
  );
}

// Make this node non-selectable
PromptNode.selectable = false;
