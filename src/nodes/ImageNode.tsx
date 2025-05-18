import { Handle, Position, type NodeProps } from '@xyflow/react';
import { useState, useCallback } from 'react';
import { BaseNode } from '@/components/base-node';
import {
  NodeHeader,
  NodeHeaderTitle,
  NodeHeaderIcon,
  NodeHeaderActions,
  NodeHeaderDeleteAction,
} from '@/components/node-header';
import { ImageIcon, Download, Maximize } from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import useStore from '../store';
import { useShallow } from 'zustand/react/shallow';
import { AppNode, ImageNodeData } from './types';

export function ImageNode({ data, selected, id }: NodeProps) {
  // Cast data to expected type
  const nodeData = data as ImageNodeData;
  const [isDoubleClicking, setIsDoubleClicking] = useState(false);
  const [isDialogOpen, setIsDialogOpen] = useState(false);

  // Get required store functions
  const {
    findNonOverlappingPosition,
    setNodes,
    setEdges,
    rfInstance,
    setNodesToFocus,
    createPromptNode,
  } = useStore(
    useShallow((state) => ({
      findNonOverlappingPosition: state.findNonOverlappingPosition,
      setNodes: state.setNodes,
      setEdges: state.setEdges,
      rfInstance: state.rfInstance,
      setNodesToFocus: state.setNodesToFocus,
      createPromptNode: state.createPromptNode,
    })),
  );

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

  const handleDoubleClick = useCallback(() => {
    if (!nodeData.imageUrl || isDoubleClicking || !rfInstance) return;

    setIsDoubleClicking(true);

    // Get the current node position
    const currentNode = rfInstance.getNode(id);
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
    const newPosition = findNonOverlappingPosition(
      initialPosition,
      'prompt-node',
    );

    // Create a new prompt node with the current image as source
    const newNode = createPromptNode(newPosition, {
      prompt: '',
      sourceImages: [nodeData.imageUrl],
    });

    // Add the new node to the flow
    setNodes((nodes) => [...nodes, newNode] as AppNode[]);

    // Create an edge connecting the image node to the new prompt node
    setEdges((edges) => [
      ...edges,
      {
        id: `edge-${id}-to-${newNode.id}`,
        source: id,
        target: newNode.id,
        sourceHandle: 'output',
        targetHandle: 'input',
      },
    ]);

    // Focus on the newly created node
    setNodesToFocus([newNode.id]);

    // Release the double-clicking lock after focus is complete
    setTimeout(() => {
      setIsDoubleClicking(false);
    }, 300);
  }, [
    id,
    nodeData.imageUrl,
    isDoubleClicking,
    rfInstance,
    findNonOverlappingPosition,
    createPromptNode,
    setNodes,
    setEdges,
    setNodesToFocus,
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
