import { Handle, Position, type NodeProps, useReactFlow } from '@xyflow/react';
import { useCallback, useRef, useEffect, useState, KeyboardEvent } from 'react';
import { processImageOperation } from '../services/imageGenerationService';
import { AppNode, ImageNodeData } from './types';

export function PromptNode({ data, id }: NodeProps) {
  const reactFlowInstance = useReactFlow();
  const { deleteElements, addNodes, addEdges, setNodes, getNode } =
    reactFlowInstance;
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
  const [showOptions, setShowOptions] = useState<boolean>(false);
  const [isProcessing, setIsProcessing] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [sourceImages, setSourceImages] = useState<string[]>(
    (data?.sourceImages as string[]) || [],
  );
  const [maskImage, setMaskImage] = useState<string | null>(
    (data?.maskImage as string) || null,
  );

  const handlePromptChange = useCallback(
    (evt: React.ChangeEvent<HTMLTextAreaElement>) => {
      const newPrompt = evt.target.value;
      setPrompt(newPrompt);
      console.log('Prompt updated:', newPrompt);
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

  const handleMaskUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onloadend = () => {
      const base64String = reader.result as string;
      setMaskImage(base64String);
    };
    reader.readAsDataURL(file);
  };

  const handleRemoveImage = (index: number) => {
    setSourceImages((prev) => prev.filter((_, i) => i !== index));
  };

  const handleRemoveMask = () => {
    setMaskImage(null);
  };

  const clearImages = () => {
    setSourceImages([]);
    setMaskImage(null);
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

      // Position the new node below the current one
      const newNodePosition = {
        x: currentNode.position.x,
        y: currentNode.position.y + 300, // Place it below with some spacing
      };

      // Create placeholder nodes for each image to be generated
      const loadingImageNodes: AppNode[] = [];
      const numImages = n;

      for (let i = 0; i < numImages; i++) {
        const imageNodeId = `image-node-${Date.now()}-${i}`;
        const offsetPosition = {
          x: newNodePosition.x + i * 50, // Stagger horizontally
          y: newNodePosition.y + i * 50, // Stagger vertically
        };

        const loadingImageNode: AppNode = {
          id: imageNodeId,
          type: 'image-node',
          position: offsetPosition,
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
        maskImage: maskImage || undefined,
        model: 'gpt-image-1' as const,
        size: size as any,
        n,
        quality: quality as any,
        outputFormat: outputFormat as any,
        moderation: moderation as any,
        background: background as any,
      };

      console.log(
        `Processing image ${
          isEditOperation ? 'edit' : 'generation'
        } with parameters:`,
        params,
      );
      const result = await processImageOperation(params, newNodePosition);

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
    maskImage,
  ]);

  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
      textareaRef.current.style.height = `${textareaRef.current.scrollHeight}px`;
    }
  }, [prompt]);

  const isEditMode = sourceImages.length > 0;

  return (
    <div
      className="react-flow__node-default prompt-node"
      style={{
        width: '300px',
        borderRadius: '8px',
        boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)',
        backgroundColor: 'white',
        border: '1px solid #e2e8f0',
      }}
    >
      <div style={{ padding: '16px' }}>
        <Handle type="target" position={Position.Top} id="input" />

        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            marginBottom: '12px',
          }}
        >
          <button
            onClick={handleDelete}
            className="nodrag"
            style={{
              backgroundColor: 'transparent',
              border: 'none',
              cursor: 'pointer',
              color: '#e53e3e',
              padding: '2px',
              borderRadius: '4px',
              marginRight: '8px',
            }}
          >
            ✕
          </button>
          <div
            style={{
              fontWeight: 'bold',
              fontSize: '14px',
              color: '#333',
              flexGrow: 1,
              textAlign: 'center',
            }}
          >
            {isEditMode ? 'AI Image Editor' : 'AI Image Generator'}
          </div>
          {isEditMode && (
            <button
              onClick={clearImages}
              className="nodrag"
              style={{
                backgroundColor: 'transparent',
                border: 'none',
                cursor: 'pointer',
                color: '#4a5568',
                padding: '2px',
                borderRadius: '4px',
                marginLeft: '8px',
                fontSize: '12px',
              }}
            >
              Clear Images
            </button>
          )}
        </div>

        <div>
          <textarea
            ref={textareaRef}
            value={prompt}
            onChange={handlePromptChange}
            onKeyDown={handleKeyDown}
            placeholder={
              isEditMode
                ? 'Enter a prompt to edit the image(s)...'
                : 'Enter a prompt to generate an image...'
            }
            className="nodrag"
            style={{
              width: '100%',
              minHeight: '80px',
              padding: '8px',
              borderRadius: '4px',
              border: '1px solid #e2e8f0',
              resize: 'none',
              fontSize: '13px',
              lineHeight: '1.5',
              fontFamily: 'inherit',
            }}
          />

          <div style={{ marginTop: '12px' }}>
            <div style={{ marginBottom: '8px' }}>
              <label
                htmlFor="image-upload"
                style={{
                  display: 'block',
                  marginBottom: '4px',
                  fontSize: '13px',
                  fontWeight: 'bold',
                }}
              >
                Source Images (optional, up to 16):
              </label>
              <input
                id="image-upload"
                ref={fileInputRef}
                type="file"
                accept="image/png,image/jpeg,image/webp"
                onChange={handleImageUpload}
                multiple
                className="nodrag"
                style={{
                  width: '100%',
                  padding: '4px',
                  fontSize: '12px',
                }}
              />
            </div>

            {sourceImages.length > 0 && (
              <div
                style={{
                  display: 'flex',
                  flexWrap: 'wrap',
                  gap: '8px',
                  marginBottom: '8px',
                }}
              >
                {sourceImages.map((img, index) => (
                  <div
                    key={index}
                    style={{
                      position: 'relative',
                      width: '60px',
                      height: '60px',
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
                        top: '-6px',
                        right: '-6px',
                        width: '18px',
                        height: '18px',
                        borderRadius: '50%',
                        backgroundColor: '#e53e3e',
                        color: 'white',
                        border: 'none',
                        fontSize: '10px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        cursor: 'pointer',
                      }}
                    >
                      ✕
                    </button>
                  </div>
                ))}
              </div>
            )}

            {sourceImages.length > 0 && (
              <div style={{ marginBottom: '8px' }}>
                <label
                  htmlFor="mask-upload"
                  style={{
                    display: 'block',
                    marginBottom: '4px',
                    fontSize: '13px',
                    fontWeight: 'bold',
                  }}
                >
                  Mask Image (optional):
                </label>
                <input
                  id="mask-upload"
                  type="file"
                  accept="image/png"
                  onChange={handleMaskUpload}
                  className="nodrag"
                  style={{
                    width: '100%',
                    padding: '4px',
                    fontSize: '12px',
                  }}
                />
              </div>
            )}

            {maskImage && (
              <div
                style={{
                  position: 'relative',
                  width: '80px',
                  height: '80px',
                  marginBottom: '8px',
                }}
              >
                <img
                  src={maskImage}
                  alt="Mask"
                  style={{
                    width: '100%',
                    height: '100%',
                    objectFit: 'cover',
                    borderRadius: '4px',
                  }}
                />
                <button
                  onClick={handleRemoveMask}
                  className="nodrag"
                  style={{
                    position: 'absolute',
                    top: '-6px',
                    right: '-6px',
                    width: '18px',
                    height: '18px',
                    borderRadius: '50%',
                    backgroundColor: '#e53e3e',
                    color: 'white',
                    border: 'none',
                    fontSize: '10px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    cursor: 'pointer',
                  }}
                >
                  ✕
                </button>
              </div>
            )}
          </div>

          {showOptions && (
            <div style={{ marginTop: '12px' }}>
              <div
                style={{
                  display: 'flex',
                  flexWrap: 'wrap',
                  gap: '8px',
                  marginBottom: '8px',
                }}
              >
                <div style={{ flex: '1 0 48%' }}>
                  <label
                    htmlFor="size"
                    style={{ display: 'block', marginBottom: '2px' }}
                  >
                    Size:
                  </label>
                  <select
                    id="size"
                    value={size}
                    onChange={(e) => setSize(e.target.value)}
                    className="nodrag"
                    style={{
                      width: '100%',
                      padding: '3px',
                      borderRadius: '3px',
                      border: '1px solid #ddd',
                      fontSize: '12px',
                    }}
                  >
                    <option value="1024x1024">1024x1024</option>
                    <option value="1536x1024">1536x1024</option>
                    <option value="1024x1536">1024x1536</option>
                    <option value="auto">Auto</option>
                  </select>
                </div>

                <div style={{ flex: '1 0 48%' }}>
                  <label
                    htmlFor="n"
                    style={{ display: 'block', marginBottom: '2px' }}
                  >
                    Number:
                  </label>
                  <select
                    id="n"
                    value={n}
                    onChange={(e) => setN(parseInt(e.target.value))}
                    className="nodrag"
                    style={{
                      width: '100%',
                      padding: '3px',
                      borderRadius: '3px',
                      border: '1px solid #ddd',
                      fontSize: '12px',
                    }}
                  >
                    <option value="1">1</option>
                    <option value="2">2</option>
                    <option value="3">3</option>
                    <option value="4">4</option>
                  </select>
                </div>

                <div style={{ flex: '1 0 48%' }}>
                  <label
                    htmlFor="quality"
                    style={{ display: 'block', marginBottom: '2px' }}
                  >
                    Quality:
                  </label>
                  <select
                    id="quality"
                    value={quality}
                    onChange={(e) => setQuality(e.target.value)}
                    className="nodrag"
                    style={{
                      width: '100%',
                      padding: '3px',
                      borderRadius: '3px',
                      border: '1px solid #ddd',
                      fontSize: '12px',
                    }}
                  >
                    <option value="auto">Auto</option>
                    <option value="high">High</option>
                    <option value="medium">Medium</option>
                    <option value="low">Low</option>
                  </select>
                </div>

                <div style={{ flex: '1 0 48%' }}>
                  <label
                    htmlFor="outputFormat"
                    style={{ display: 'block', marginBottom: '2px' }}
                  >
                    Format:
                  </label>
                  <select
                    id="outputFormat"
                    value={outputFormat}
                    onChange={(e) => setOutputFormat(e.target.value)}
                    className="nodrag"
                    style={{
                      width: '100%',
                      padding: '3px',
                      borderRadius: '3px',
                      border: '1px solid #ddd',
                      fontSize: '12px',
                    }}
                  >
                    <option value="png">PNG</option>
                    <option value="jpeg">JPEG</option>
                    <option value="webp">WebP</option>
                  </select>
                </div>

                {!isEditMode && (
                  <div style={{ flex: '1 0 48%' }}>
                    <label
                      htmlFor="moderation"
                      style={{ display: 'block', marginBottom: '2px' }}
                    >
                      Moderation:
                    </label>
                    <select
                      id="moderation"
                      value={moderation}
                      onChange={(e) => setModeration(e.target.value)}
                      className="nodrag"
                      style={{
                        width: '100%',
                        padding: '3px',
                        borderRadius: '3px',
                        border: '1px solid #ddd',
                        fontSize: '12px',
                      }}
                    >
                      <option value="auto">Auto</option>
                      <option value="low">Low</option>
                    </select>
                  </div>
                )}

                <div style={{ flex: '1 0 48%' }}>
                  <label
                    htmlFor="background"
                    style={{ display: 'block', marginBottom: '2px' }}
                  >
                    Background:
                  </label>
                  <select
                    id="background"
                    value={background}
                    onChange={(e) => setBackground(e.target.value)}
                    className="nodrag"
                    style={{
                      width: '100%',
                      padding: '3px',
                      borderRadius: '3px',
                      border: '1px solid #ddd',
                      fontSize: '12px',
                    }}
                  >
                    <option value="auto">Auto</option>
                    <option value="transparent">Transparent</option>
                    <option value="opaque">Opaque</option>
                  </select>
                </div>
              </div>
            </div>
          )}
        </div>

        {error && (
          <div style={{ color: 'red', fontSize: '12px', marginTop: '5px' }}>
            {error}
          </div>
        )}

        <button
          onClick={() => setShowOptions(!showOptions)}
          className="nodrag"
          style={{
            marginTop: '8px',
            padding: '6px 12px',
            backgroundColor: '#f8f9fa',
            color: '#4a5568',
            border: '1px solid #e2e8f0',
            borderRadius: '4px',
            cursor: 'pointer',
            width: '100%',
            fontSize: '13px',
            marginBottom: '8px',
          }}
        >
          {showOptions ? 'Hide Options' : 'Show Options'}
        </button>

        <button
          onClick={handleProcess}
          className="nodrag"
          disabled={isProcessing}
          style={{
            padding: '6px 12px',
            backgroundColor: isProcessing ? '#a29bfe' : '#6c5ce7',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: isProcessing ? 'not-allowed' : 'pointer',
            width: '100%',
            fontWeight: 'bold',
            fontSize: '13px',
          }}
        >
          {isProcessing
            ? 'Processing...'
            : isEditMode
            ? 'Edit Image'
            : 'Generate Image'}
        </button>
      </div>
      <Handle type="source" position={Position.Bottom} id="output" />
    </div>
  );
}

// Make this node non-selectable
PromptNode.selectable = false;
