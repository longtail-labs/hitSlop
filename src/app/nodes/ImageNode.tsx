import React from 'react';
import { Handle, Position, type NodeProps, useReactFlow } from '@xyflow/react';
import { useState, useCallback, useEffect } from 'react';
import { BaseNode } from '@/app/components/base-node';
import {
  NodeHeader,
  NodeHeaderTitle,
  NodeHeaderIcon,
  NodeHeaderActions,
  NodeHeaderDeleteAction,
} from '@/app/components/node-header';
import { ImageIcon, Download, Maximize } from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/app/components/ui/dialog';
import { imageService } from '@/app/services/database';
import { createNodeId, createEdgeId, createImageNode } from '@/app/lib/utils';
import { ImageNodeToolbar } from '@/app/components/image-node-toolbar';

// Import the ImageNodeData type from types
import { ImageNodeData } from './types';

export function ImageNode({ data, selected, id }: NodeProps) {
  const nodeData = data as unknown as ImageNodeData;
  const {
    addNodes,
    addEdges,
    getNode,
    getIntersectingNodes,
    fitView,
    setNodes,
  } = useReactFlow();

  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [currentImageUrl, setCurrentImageUrl] = useState<string | null>(null);
  const [imageLoadError, setImageLoadError] = useState<string | null>(null);

  // Simplified image loading
  useEffect(() => {
    const loadImage = async () => {
      if (nodeData.imageId) {
        try {
          const imageUrl = await imageService.getImage(nodeData.imageId);
          if (imageUrl) {
            setCurrentImageUrl(imageUrl);
            setImageLoadError(null);
          } else {
            setImageLoadError('Image not found in database');
          }
        } catch (error) {
          console.error('Error loading image:', error);
          setImageLoadError('Failed to load image');
        }
      } else {
        setCurrentImageUrl(null);
        setImageLoadError('No image ID provided to node');
      }
    };

    loadImage();
  }, [nodeData.imageId]);

  const handleDelete = useCallback(() => {
    setNodes((nodes) => nodes.filter((node) => node.id !== id));
  }, [id, setNodes]);

  const handleDownload = useCallback(async () => {
    if (!currentImageUrl) return;

    try {
      // Fetch the image data, whether it's a data URL or a remote URL
      const response = await fetch(currentImageUrl);
      if (!response.ok) {
        throw new Error('Network response was not ok.');
      }
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;

      // Attempt to create a more descriptive filename
      const getFilename = () => {
        if (nodeData.source === 'unsplash' && nodeData.alt) {
          return `${nodeData.alt
            .toLowerCase()
            .replace(/\s+/g, '-')
            .substring(0, 50)}.png`;
        }
        if (nodeData.prompt) {
          return `${String(nodeData.prompt)
            .toLowerCase()
            .replace(/\s+/g, '-')
            .substring(0, 50)}.png`;
        }
        return `image-${Date.now()}.png`;
      };

      link.download = getFilename();
      document.body.appendChild(link);
      link.click();

      // Cleanup
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);
    } catch (error) {
      console.error('Image download failed:', error);
      // Fallback: open in a new tab if fetch fails (e.g., CORS)
      window.open(currentImageUrl, '_blank');
    }
  }, [currentImageUrl, nodeData]);

  const findNonOverlappingPosition = useCallback(
    (
      initialPosition: { x: number; y: number },
      dimensions = { width: 300, height: 250 },
    ) => {
      let position = { ...initialPosition };
      let tempNode = {
        id: 'temp',
        position,
        width: dimensions.width,
        height: dimensions.height,
      };
      let intersections = getIntersectingNodes(tempNode);

      if (intersections.length > 0) {
        const spiralStep = 100;
        let attempts = 0;
        let angle = 0;
        let radius = spiralStep;

        while (intersections.length > 0 && attempts < 50) {
          angle += 0.5;
          radius = spiralStep * (1 + angle / 10);
          position = {
            x: initialPosition.x + radius * Math.cos(angle),
            y: initialPosition.y + radius * Math.sin(angle),
          };
          tempNode = { ...tempNode, position };
          intersections = getIntersectingNodes(tempNode);
          attempts++;
        }
      }

      return position;
    },
    [getIntersectingNodes],
  );

  const handleDuplicate = useCallback(() => {
    if (!nodeData.imageId) return;

    const currentNode = getNode(id);
    if (!currentNode) return;

    const newPosition = findNonOverlappingPosition({
      x: currentNode.position.x + 350,
      y: currentNode.position.y,
    });

    const options: any = {
      source: nodeData.source,
    };

    if ('prompt' in nodeData && nodeData.prompt) {
      options.prompt = nodeData.prompt;
    }

    if (nodeData.source === 'unsplash') {
      options.photographer = nodeData.photographer;
      options.photographer_url = nodeData.photographer_url;
      options.alt = nodeData.alt;
      options.attribution = nodeData.attribution;
    } else if (
      nodeData.source === 'generated' ||
      nodeData.source === 'edited'
    ) {
      options.generationParams = nodeData.generationParams;
      options.modelConfig = nodeData.modelConfig;
      options.revisedPrompt = nodeData.revisedPrompt;
      options.isEdited = nodeData.isEdited;
    }

    const newNode = createImageNode(nodeData.imageId, {
      position: newPosition,
      ...options,
    });

    addNodes(newNode as any); // Use `any` to satisfy React Flow's broad type

    setTimeout(() => {
      fitView({
        nodes: [{ id: newNode.id }],
        duration: 500,
        padding: 1.8,
        maxZoom: 0.8,
      });
    }, 100);
  }, [id, nodeData, addNodes, getNode, findNonOverlappingPosition, fitView]);

  const handleEdit = useCallback(
    (event: React.MouseEvent) => {
      event.stopPropagation();
      if (!nodeData.imageId) return;

      const currentNode = getNode(id);
      if (!currentNode) return;

      const initialPosition = {
        x: currentNode.position.x,
        y: currentNode.position.y + 350,
      };

      const newPosition = findNonOverlappingPosition(initialPosition);
      const newNodeId = createNodeId('prompt-node');

      const newNode = {
        id: newNodeId,
        type: 'prompt-node',
        position: newPosition,
        data: {
          prompt: '',
          sourceImages: [nodeData.imageId], // Always use imageId
        },
        selectable: false,
      };

      addNodes(newNode);

      const edgeId = createEdgeId(id, newNodeId);
      addEdges({
        id: edgeId,
        source: id,
        target: newNodeId,
        sourceHandle: 'output',
        targetHandle: 'input',
      });

      setTimeout(() => {
        fitView({
          nodes: [{ id: newNodeId }],
          duration: 500,
          padding: 1.8,
          maxZoom: 0.8,
        });
      }, 100);
    },
    [
      id,
      nodeData.imageId,
      addNodes,
      addEdges,
      getNode,
      findNonOverlappingPosition,
      fitView,
    ],
  );

  // Determine display title based on source
  const getImageTitle = () => {
    switch (nodeData.source) {
      case 'unsplash':
        return 'Unsplash Image';
      case 'uploaded':
        return 'Local Image';
      case 'edited':
        return 'Edited Image';
      default:
        return 'Generated Image';
    }
  };

  // Determine status styling
  const getStatusClass = () => {
    if (nodeData.isLoading) return 'animate-pulse border-2 border-blue-400';
    if (nodeData.error || imageLoadError) return 'border-2 border-destructive';
    if (currentImageUrl) return 'border-2 border-green-500';
    return '';
  };

  return (
    <div>
      <Handle type="target" position={Position.Top} id="input" />

      <ImageNodeToolbar
        isVisible={selected && !!currentImageUrl}
        onDuplicate={handleDuplicate}
        onDownload={handleDownload}
        onEdit={handleEdit}
        onDelete={handleDelete}
      />

      <BaseNode
        selected={selected}
        className={`image-node p-0 w-[300px] ${getStatusClass()}`}
      >
        <NodeHeader className="border-b">
          <NodeHeaderIcon>
            <ImageIcon size={18} />
          </NodeHeaderIcon>
          <NodeHeaderTitle>
            <span
              className="font-recursive"
              style={{
                fontVariationSettings: '"MONO" 0.7, "wght" 600, "CASL" 0.3',
              }}
            >
              {getImageTitle()}
            </span>
          </NodeHeaderTitle>
          <NodeHeaderActions>
            {currentImageUrl && (
              <>
                <button
                  onClick={() => setIsDialogOpen(true)}
                  className="nodrag flex items-center justify-center rounded-sm p-1 h-6 w-6 text-muted-foreground hover:text-foreground hover:bg-accent"
                  title="Expand image"
                >
                  <Maximize size={14} />
                </button>
                <button
                  onClick={handleDownload}
                  className="nodrag flex items-center justify-center rounded-sm p-1 h-6 w-6 text-muted-foreground hover:text-foreground hover:bg-accent"
                  title="Download image"
                >
                  <Download size={14} />
                </button>
              </>
            )}
            <NodeHeaderDeleteAction />
          </NodeHeaderActions>
        </NodeHeader>

        <div className="image-node-content">
          {nodeData.isLoading ? (
            <div className="p-5 text-center min-h-[150px] flex flex-col justify-center items-center">
              <div className="rounded-full bg-blue-500/20 w-10 h-10 mb-3 animate-spin border-2 border-blue-500 border-t-transparent"></div>
              <div
                className="text-sm text-muted-foreground font-recursive"
                style={{
                  fontVariationSettings: '"MONO" 0.5, "wght" 500, "CASL" 0.4',
                }}
              >
                Generating image...
              </div>
              {nodeData.prompt && (
                <div
                  className="text-xs mt-1.5 text-muted-foreground max-w-[250px] overflow-hidden text-ellipsis font-recursive"
                  style={{
                    fontVariationSettings: '"MONO" 0.3, "wght" 400, "CASL" 0.6',
                  }}
                >
                  "{String(nodeData.prompt).substring(0, 50)}
                  {String(nodeData.prompt).length > 50 ? '...' : ''}"
                </div>
              )}
            </div>
          ) : currentImageUrl ? (
            <div onDoubleClick={handleEdit} className="cursor-pointer">
              <img
                src={currentImageUrl}
                alt="AI generated image"
                className="max-w-full rounded"
              />
              {(nodeData.source === 'generated' ||
                nodeData.source === 'edited') &&
                nodeData.revisedPrompt &&
                nodeData.revisedPrompt !== nodeData.prompt && (
                  <div className="p-2 text-xs text-muted-foreground bg-muted/50 border-t">
                    <span
                      className="font-medium font-recursive"
                      style={{
                        fontVariationSettings:
                          '"MONO" 0.6, "wght" 600, "CASL" 0.2',
                      }}
                    >
                      Revised prompt:
                    </span>{' '}
                    <span
                      className="font-recursive"
                      style={{
                        fontVariationSettings:
                          '"MONO" 0.4, "wght" 400, "CASL" 0.5',
                      }}
                    >
                      {nodeData.revisedPrompt}
                    </span>
                  </div>
                )}
            </div>
          ) : nodeData.error || imageLoadError ? (
            <div className="p-5 text-center bg-destructive/10 rounded-sm m-2 text-destructive min-h-[100px] flex flex-col justify-center">
              <div
                className="font-medium mb-1 font-recursive"
                style={{
                  fontVariationSettings: '"MONO" 0.7, "wght" 600, "CASL" 0.2',
                }}
              >
                Generation Failed
              </div>
              <div
                className="text-xs font-recursive"
                style={{
                  fontVariationSettings: '"MONO" 0.4, "wght" 400, "CASL" 0.4',
                }}
              >
                {nodeData.error || imageLoadError}
              </div>
            </div>
          ) : (
            <div
              className="p-5 text-center bg-muted rounded m-2 text-muted-foreground font-recursive"
              style={{
                fontVariationSettings: '"MONO" 0.5, "wght" 400, "CASL" 0.5',
              }}
            >
              No image data
            </div>
          )}
        </div>
      </BaseNode>

      <Handle type="source" position={Position.Bottom} id="output" />

      {/* Fullscreen Image Dialog */}
      {currentImageUrl && (
        <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
          <DialogContent className="sm:max-w-[90vw] max-h-[90vh] p-0">
            <DialogHeader className="p-4 flex-row items-center justify-between border-b">
              <DialogTitle
                className="font-recursive"
                style={{
                  fontVariationSettings: '"MONO" 0.6, "wght" 600, "CASL" 0.3',
                }}
              >
                Image Preview
              </DialogTitle>
              <div className="flex items-center gap-2">
                <button
                  onClick={handleDownload}
                  className="flex items-center justify-center rounded-sm p-1.5 h-8 w-8 text-muted-foreground hover:text-foreground hover:bg-accent"
                  title="Download image"
                >
                  <Download size={18} />
                </button>
              </div>
            </DialogHeader>
            <div className="overflow-hidden p-4 flex items-center justify-center h-[calc(90vh-120px)]">
              <img
                src={currentImageUrl}
                alt="AI generated image (full size)"
                className="object-contain w-auto h-auto max-w-[calc(90vw-32px)] max-h-[calc(90vh-140px)]"
              />
            </div>
          </DialogContent>
        </Dialog>
      )}
    </div>
  );
}
