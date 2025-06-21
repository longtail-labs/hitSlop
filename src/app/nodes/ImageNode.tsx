import React from 'react';
import {
  Handle,
  Position,
  type NodeProps,
  useReactFlow,
  NodeToolbar,
} from '@xyflow/react';
import { useState, useCallback, useEffect } from 'react';
import { BaseNode } from '@/app/components/base-node';
import {
  NodeHeader,
  NodeHeaderTitle,
  NodeHeaderIcon,
  NodeHeaderActions,
  NodeHeaderDeleteAction,
} from '@/app/components/node-header';
import { ImageIcon, Download, Maximize, Copy, Edit3 } from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/app/components/ui/dialog';
import {
  Menubar,
  MenubarMenu,
  MenubarTrigger,
} from '@/app/components/ui/menubar';
import { imageService } from '@/app/services/database';
import { createNodeId, createEdgeId } from '@/app/lib/utils';

// Import the ImageNodeData type from types
import { ImageNodeData } from './types';

export function ImageNode({ data, selected, id }: NodeProps) {
  // Cast data to expected type
  const nodeData = data as ImageNodeData;
  const reactFlowInstance = useReactFlow();
  const { addNodes, addEdges, getNode, getIntersectingNodes, fitView } =
    reactFlowInstance;
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [currentImageUrl, setCurrentImageUrl] = useState<string | null>(null);
  const [imageLoadError, setImageLoadError] = useState<string | null>(null);
  const [imageSource, setImageSource] = useState<string>('generated');

  // Load image data when component mounts or imageId changes
  useEffect(() => {
    const loadImage = async () => {
      // If we have an imageId, load from optimized storage
      if (nodeData.imageId) {
        try {
          const [imageUrl, metadata] = await Promise.all([
            imageService.getImage(nodeData.imageId),
            imageService.getImageMetadata(nodeData.imageId),
          ]);

          if (imageUrl) {
            setCurrentImageUrl(imageUrl);
            setImageLoadError(null);
            // Set source from metadata, fallback to node data, then to default
            setImageSource(metadata?.source || nodeData.source || 'generated');
          } else {
            setImageLoadError('Image not found in storage');
            // Fallback to legacy imageUrl if available
            if (nodeData.imageUrl) {
              setCurrentImageUrl(nodeData.imageUrl);
              setImageLoadError(null);
              setImageSource(nodeData.source || 'generated');
            }
          }
        } catch (error) {
          console.error('Error loading image:', error);
          setImageLoadError('Failed to load image');
          // Fallback to legacy imageUrl if available
          if (nodeData.imageUrl) {
            setCurrentImageUrl(nodeData.imageUrl);
            setImageLoadError(null);
            setImageSource(nodeData.source || 'generated');
          }
        }
      }
      // Fallback to legacy imageUrl for backward compatibility
      else if (nodeData.imageUrl) {
        setCurrentImageUrl(nodeData.imageUrl);
        setImageLoadError(null);
        // For legacy nodes, try to determine source from attribution or node data
        if (nodeData.attribution?.service === 'Unsplash') {
          setImageSource('unsplash');
        } else if (nodeData.prompt && nodeData.prompt.startsWith('Uploaded:')) {
          setImageSource('uploaded');
        } else {
          setImageSource(nodeData.source || 'generated');
        }
      } else {
        setCurrentImageUrl(null);
        setImageSource(nodeData.source || 'generated');
      }
    };

    loadImage();
  }, [
    nodeData.imageId,
    nodeData.imageUrl,
    nodeData.source,
    nodeData.attribution,
  ]);

  const handleDownload = () => {
    if (currentImageUrl) {
      // Create a temporary anchor element
      const link = document.createElement('a');
      link.href = currentImageUrl;
      link.download = `ai-generated-image-${Date.now()}.png`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    }
  };

  // Find a non-overlapping position for a new node
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

      // Check if the position causes overlap
      let intersections = getIntersectingNodes(tempNode);

      // If there are intersections, try to find a better position
      if (intersections.length > 0) {
        // Try different positions in a spiral pattern
        const spiralStep = 100;
        let attempts = 0;
        let angle = 0;
        let radius = spiralStep;

        while (intersections.length > 0 && attempts < 50) {
          // Move in a spiral pattern
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
    if (!currentImageUrl) return;

    // Get the current node position
    const currentNode = getNode(id);
    if (!currentNode) return;

    // Create base position for new node (to the right of the current node)
    const initialPosition = {
      x: currentNode.position.x + 350, // Place it to the right with spacing
      y: currentNode.position.y,
    };

    // Find a non-overlapping position
    const newPosition = findNonOverlappingPosition(initialPosition);

    // Generate a unique ID
    const newNodeId = createNodeId('image-node');

    // Create a new image node with the same data
    const newNode = {
      id: newNodeId,
      type: 'image-node',
      position: newPosition,
      data: {
        ...nodeData, // Copy all existing data
      },
    };

    // Add the new node to the flow
    addNodes(newNode);

    // Focus on the newly created node
    setTimeout(() => {
      fitView({
        nodes: [{ id: newNodeId }],
        duration: 500,
        padding: 1.8,
        maxZoom: 0.8,
      });
    }, 100);
  }, [
    id,
    currentImageUrl,
    nodeData,
    addNodes,
    getNode,
    findNonOverlappingPosition,
    fitView,
  ]);

  const handleEdit = useCallback(
    (event: React.MouseEvent) => {
      event.stopPropagation();
      if (!currentImageUrl) return;

      // Get the current node position
      const currentNode = getNode(id);
      if (!currentNode) return;

      // Create base position for new node (below the current node)
      const initialPosition = {
        x: currentNode.position.x,
        y: currentNode.position.y + 350, // Place it below with spacing
      };

      // Find a non-overlapping position
      const newPosition = findNonOverlappingPosition(initialPosition);

      // Generate a unique ID
      const newNodeId = createNodeId('prompt-node');

      // Create a new prompt node with the current image as source
      // Use imageId if available, otherwise fall back to imageUrl
      const sourceImageReference = nodeData.imageId || currentImageUrl;

      const newNode = {
        id: newNodeId,
        type: 'prompt-node',
        position: newPosition,
        data: {
          prompt: '',
          sourceImages: [sourceImageReference],
        },
        selectable: false,
      };

      // Add the new node to the flow
      addNodes(newNode);

      // Create an edge connecting the image node to the new prompt node
      const edgeId = createEdgeId(id, newNodeId);
      addEdges({
        id: edgeId,
        source: id,
        target: newNodeId,
        sourceHandle: 'output',
        targetHandle: 'input',
      });

      // Focus on the newly created node
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
      currentImageUrl,
      nodeData.imageId,
      addNodes,
      addEdges,
      getNode,
      findNonOverlappingPosition,
      fitView,
    ],
  );

  // Determine status class
  let statusClass = '';
  if (nodeData.isLoading) {
    statusClass = 'animate-pulse border-2 border-blue-400';
  } else if (nodeData.error || imageLoadError) {
    statusClass = 'border-2 border-destructive';
  } else if (currentImageUrl) {
    statusClass = 'border-2 border-green-500';
  }

  return (
    <div>
      <Handle type="target" position={Position.Top} id="input" />

      {/* Node Toolbar */}
      <NodeToolbar
        isVisible={selected && !!currentImageUrl}
        position={Position.Top}
        offset={10}
      >
        <Menubar>
          <MenubarMenu>
            <MenubarTrigger
              className="px-3 py-2 gap-2 text-xs font-recursive"
              onClick={handleDuplicate}
              style={{
                fontVariationSettings: '"MONO" 0.8, "wght" 500, "CASL" 0.2',
              }}
            >
              <Copy size={14} />
              Duplicate
            </MenubarTrigger>
          </MenubarMenu>
          <MenubarMenu>
            <MenubarTrigger
              className="px-3 py-2 gap-2 text-xs font-recursive"
              onClick={handleDownload}
              style={{
                fontVariationSettings: '"MONO" 0.8, "wght" 500, "CASL" 0.2',
              }}
            >
              <Download size={14} />
              Download
            </MenubarTrigger>
          </MenubarMenu>
          <MenubarMenu>
            <MenubarTrigger
              className="px-3 py-2 gap-2 text-xs font-recursive"
              onClick={handleEdit}
              style={{
                fontVariationSettings: '"MONO" 0.8, "wght" 500, "CASL" 0.2',
              }}
            >
              <Edit3 size={14} />
              Edit
            </MenubarTrigger>
          </MenubarMenu>
        </Menubar>
      </NodeToolbar>

      <BaseNode
        selected={selected}
        className={`image-node p-0 w-[300px] ${statusClass}`}
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
              {imageSource === 'unsplash'
                ? 'Unsplash Image'
                : imageSource === 'pexels'
                ? 'Pexels Image'
                : imageSource === 'uploaded'
                ? 'Local Image'
                : imageSource === 'edited'
                ? 'Edited Image'
                : 'Generated Image'}
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
              <div
                className="text-xs mt-1.5 text-muted-foreground max-w-[250px] overflow-hidden text-ellipsis font-recursive"
                style={{
                  fontVariationSettings: '"MONO" 0.3, "wght" 400, "CASL" 0.6',
                }}
              >
                {nodeData.prompt
                  ? `"${String(nodeData.prompt).substring(0, 50)}${
                      String(nodeData.prompt).length > 50 ? '...' : ''
                    }"`
                  : ''}
              </div>
            </div>
          ) : currentImageUrl ? (
            <div onDoubleClick={handleEdit} className="cursor-pointer">
              <img
                src={currentImageUrl}
                alt="Generated AI image"
                className="max-w-full rounded"
              />
              {nodeData.revisedPrompt &&
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
              Image failed to load
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
                alt="Generated AI image (full size)"
                className="object-contain w-auto h-auto max-w-[calc(90vw-32px)] max-h-[calc(90vh-140px)]"
              />
            </div>
          </DialogContent>
        </Dialog>
      )}
    </div>
  );
}
