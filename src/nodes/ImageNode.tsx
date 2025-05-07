import { Handle, Position, type NodeProps, useReactFlow } from '@xyflow/react';
import { useState, useCallback } from 'react';
import { BaseNode } from '@/components/base-node';
import {
  NodeHeader,
  NodeHeaderTitle,
  NodeHeaderIcon,
  NodeHeaderActions,
  NodeHeaderDeleteAction,
} from '@/components/node-header';
import { ImageIcon, Download, Maximize, X } from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';

// Define the expected data structure
interface ImageNodeData {
  imageUrl?: string;
  isLoading?: boolean;
  error?: string;
  prompt?: string;
}

export function ImageNode({ data, selected, id }: NodeProps) {
  // Cast data to expected type
  const nodeData = data as ImageNodeData;
  const reactFlowInstance = useReactFlow();
  const {
    addNodes,
    addEdges,
    getNode,
    getNodes,
    getIntersectingNodes,
    fitView,
    setNodes,
  } = reactFlowInstance;
  const [isDoubleClicking, setIsDoubleClicking] = useState(false);
  const [isDialogOpen, setIsDialogOpen] = useState(false);

  const handleDownload = () => {
    if (nodeData.imageUrl) {
      // Create a temporary anchor element
      const link = document.createElement('a');
      link.href = nodeData.imageUrl;
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

  const handleDoubleClick = useCallback(() => {
    if (!nodeData.imageUrl || isDoubleClicking) return;

    setIsDoubleClicking(true);

    // Get the current node position
    const currentNode = getNode(id);
    if (!currentNode) {
      setIsDoubleClicking(false);
      return;
    }

    // Create base position for new node (below the current node)
    const initialPosition = {
      x: currentNode.position.x,
      y: currentNode.position.y + 350, // Place it below with spacing
    };

    // Find a non-overlapping position
    const newPosition = findNonOverlappingPosition(initialPosition);

    // Generate a unique ID with timestamp to avoid conflicts
    const newNodeId = `prompt-node-${Date.now()}`;

    // Create a new prompt node with the current image as source
    const newNode = {
      id: newNodeId,
      type: 'prompt-node',
      position: newPosition,
      data: {
        prompt: '',
        sourceImages: [nodeData.imageUrl],
      },
      selectable: false,
    };

    // Add the new node to the flow
    addNodes(newNode);

    // Create an edge connecting the image node to the new prompt node
    addEdges({
      id: `edge-${id}-to-${newNodeId}`,
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

    setIsDoubleClicking(false);
  }, [
    id,
    nodeData.imageUrl,
    addNodes,
    addEdges,
    getNode,
    isDoubleClicking,
    findNonOverlappingPosition,
    fitView,
  ]);

  // Determine status class
  let statusClass = '';
  if (nodeData.isLoading) {
    statusClass = 'animate-pulse';
  } else if (nodeData.error) {
    statusClass = 'border-2 border-destructive';
  } else if (nodeData.imageUrl) {
    statusClass = 'border-2 border-green-500';
  }

  return (
    <div>
      <Handle type="target" position={Position.Top} id="input" />
      <BaseNode
        selected={selected}
        className={`image-node p-0 w-[300px] ${statusClass}`}
        onDoubleClick={handleDoubleClick}
      >
        <NodeHeader className="border-b">
          <NodeHeaderIcon>
            <ImageIcon size={18} />
          </NodeHeaderIcon>
          <NodeHeaderTitle>Generated Image</NodeHeaderTitle>
          <NodeHeaderActions>
            {nodeData.imageUrl && (
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

        <div className="image-node-content" onDoubleClick={handleDoubleClick}>
          {nodeData.isLoading ? (
            <div className="p-5 text-center min-h-[150px] flex flex-col justify-center items-center">
              <div className="rounded-full bg-blue-500/20 w-10 h-10 mb-3 animate-spin border-2 border-blue-500 border-t-transparent"></div>
              <div className="text-sm text-muted-foreground">
                Generating image...
              </div>
              <div className="text-xs mt-1.5 text-muted-foreground max-w-[250px] overflow-hidden text-ellipsis">
                {nodeData.prompt
                  ? `"${String(nodeData.prompt).substring(0, 50)}${
                      String(nodeData.prompt).length > 50 ? '...' : ''
                    }"`
                  : ''}
              </div>
            </div>
          ) : nodeData.imageUrl ? (
            <div>
              <img
                src={nodeData.imageUrl}
                alt="Generated AI image"
                className="max-w-full rounded"
              />
            </div>
          ) : nodeData.error ? (
            <div className="p-5 text-center bg-destructive/10 rounded-sm m-2 text-destructive min-h-[100px] flex flex-col justify-center">
              <div className="font-medium mb-1">Generation Failed</div>
              <div className="text-xs">{nodeData.error}</div>
            </div>
          ) : (
            <div className="p-5 text-center bg-muted rounded m-2 text-muted-foreground">
              Image failed to load
            </div>
          )}
        </div>
      </BaseNode>
      <Handle type="source" position={Position.Bottom} id="output" />

      {/* Fullscreen Image Dialog */}
      {nodeData.imageUrl && (
        <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
          <DialogContent className="sm:max-w-[90vw] max-h-[90vh] p-0">
            <DialogHeader className="p-4 flex-row items-center justify-between border-b">
              <DialogTitle>Image Preview</DialogTitle>
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
                src={nodeData.imageUrl}
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
