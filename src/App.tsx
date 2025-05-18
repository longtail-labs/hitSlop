import React, { useCallback, useRef, useState, useEffect } from 'react';
import {
  ReactFlow,
  Background,
  Controls,
  MiniMap,
  addEdge,
  useNodesState,
  useEdgesState,
  type OnConnect,
  Panel,
  useReactFlow,
  ReactFlowProvider,
  SelectionMode,
  OnSelectionChangeParams,
  Node,
} from '@xyflow/react';

import '@xyflow/react/dist/style.css';

import { initialNodes, nodeTypes } from './nodes';
import { initialEdges, edgeTypes } from './edges';
import { AppNode, ImageNodeData } from './nodes/types';
import { ArrowDown } from 'lucide-react';

// Import annotation node components
import {
  AnnotationNode,
  AnnotationNodeContent,
  AnnotationNodeIcon,
} from '@/components/annotation-node';

// Add some custom styles for our prompt nodes
import './styles.css';

// Add global styles for monospace font
const globalStyle = document.createElement('style');
globalStyle.innerHTML = `
  .react-flow, .react-flow__node, .react-flow__controls, .react-flow__panel, button, input {
    font-family: 'JetBrains Mono', 'Fira Code', 'Courier New', monospace !important;
  }
`;
document.head.appendChild(globalStyle);

let nodeId = 0;

// Define standard node dimensions for collision detection
const NODE_DIMENSIONS = {
  'prompt-node': { width: 300, height: 250 },
  'image-node': { width: 300, height: 300 },
};

// Create an annotation node component
function InstructionAnnotation() {
  return (
    <AnnotationNode>
      <AnnotationNodeContent>
        Click anywhere on the canvas to create a new prompt node. Double-click
        on an image to edit it, or select and drag multiple images to edit them
        together.
      </AnnotationNodeContent>
      <AnnotationNodeIcon>
        <ArrowDown />
      </AnnotationNodeIcon>
    </AnnotationNode>
  );
}

// Define instruction annotation node type
const customNodeTypes = {
  ...nodeTypes,
  'annotation-node': InstructionAnnotation,
};

// Add initial annotation node pointing to a prompt node
const instructionalNodes = [
  // Keep existing initial nodes
  ...initialNodes,
  // Add an annotation node
  {
    id: 'instruction-annotation',
    type: 'annotation-node',
    position: { x: 50, y: -100 },
    data: {},
  },
];

function Flow() {
  const reactFlowWrapper = useRef<HTMLDivElement>(null);
  const [nodes, setNodes, onNodesChange] = useNodesState(instructionalNodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges);
  const { screenToFlowPosition, getIntersectingNodes, fitView } = useReactFlow();
  const [selectedImageNodes, setSelectedImageNodes] = useState<AppNode[]>([]);
  const [previousSelectionCount, setPreviousSelectionCount] = useState(0);
  const [isSelecting, setIsSelecting] = useState(false);

  // Find a non-overlapping position for a new node
  const findNonOverlappingPosition = useCallback(
    (initialPosition: { x: number; y: number }, nodeType: string) => {
      const dimensions =
        NODE_DIMENSIONS[nodeType as keyof typeof NODE_DIMENSIONS] || {
          width: 200,
          height: 200,
        };

      let position = { ...initialPosition };
      let tempNode: Node = {
        id: 'temp',
        type: nodeType,
        position,
        data: {},
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

  const handleDragOver = useCallback((event: React.DragEvent<HTMLDivElement>) => {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'copy';
  }, []);

  const handleDrop = useCallback(
    (event: React.DragEvent<HTMLDivElement>) => {
      event.preventDefault();
      if (!reactFlowWrapper.current) return;

      const reactFlowBounds = reactFlowWrapper.current.getBoundingClientRect();
      const files = Array.from(event.dataTransfer.files ?? []) as File[];

      files.forEach((file, index) => {
        if (!file.type.startsWith('image/')) return;
        const reader = new FileReader();
        reader.onload = () => {
          const basePosition = screenToFlowPosition({
            x: event.clientX - reactFlowBounds.left + index * 20,
            y: event.clientY - reactFlowBounds.top + index * 20,
          });
          const position = findNonOverlappingPosition(basePosition, 'image-node');
          const newNodeId = `image-node-${nodeId++}`;
          const newNode: AppNode = {
            id: newNodeId,
            type: 'image-node',
            position,
            data: { imageUrl: reader.result as string },
          };
          setNodes((nds: AppNode[]) => [...nds, newNode]);
        };
        reader.readAsDataURL(file);
      });
    },
    [screenToFlowPosition, findNonOverlappingPosition, setNodes],
  );

  const onConnect: OnConnect = useCallback(
    (connection) => setEdges((edges) => addEdge(connection, edges)),
    [setEdges],
  );

  const onPaneClick = useCallback(
    (event: React.MouseEvent) => {
      if (reactFlowWrapper.current) {
        // Get the position where the user clicked
        const reactFlowBounds =
          reactFlowWrapper.current.getBoundingClientRect();
        const position = screenToFlowPosition({
          x: event.clientX - reactFlowBounds.left,
          y: event.clientY - reactFlowBounds.top,
        });

        // Find a non-overlapping position for the new node
        const nonOverlappingPosition = findNonOverlappingPosition(
          position,
          'prompt-node',
        );

        // Generate a unique ID with timestamp to avoid conflicts
        const newNodeId = `prompt-node-${nodeId++}`;

        // Create a new node at the non-overlapping position
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
        setNodes((nds: AppNode[]) => [...nds, newNode]);

        // Focus directly on the new node with the same parameters as in ImageNode.tsx
        setTimeout(() => {
          fitView({
            nodes: [{ id: newNodeId }],
            duration: 500,
            padding: 1.8,
            maxZoom: 0.8,
          });
        }, 100);
      }
    },
    [screenToFlowPosition, setNodes, findNonOverlappingPosition, fitView],
  );

  const onSelectionChange = useCallback(
    (params: OnSelectionChangeParams) => {
      // Filter for image nodes
      const imageNodes = params.nodes.filter(
        (node) => node.type === 'image-node',
      ) as AppNode[];

      // Update the selected image nodes
      setSelectedImageNodes(imageNodes);

      // Track that we're in the selection process
      setIsSelecting(true);

      // Update the previous selection count
      setPreviousSelectionCount(imageNodes.length);
    },
    [previousSelectionCount],
  );

  const createEditNodeFromSelection = useCallback(() => {
    if (selectedImageNodes.length === 0 || !reactFlowWrapper.current) return;

    // Calculate the average position of selected nodes to place the new node
    const avgPosition = {
      x:
        selectedImageNodes.reduce((sum, node) => sum + node.position.x, 0) /
        selectedImageNodes.length,
      y:
        selectedImageNodes.reduce((sum, node) => sum + node.position.y, 0) /
          selectedImageNodes.length -
        200, // Place it above
    };

    // Find a non-overlapping position based on the average position
    const nonOverlappingPosition = findNonOverlappingPosition(
      avgPosition,
      'prompt-node',
    );

    // Collect image URLs from the selected nodes
    const selectedImages = selectedImageNodes
      .map((node) => {
        const data = node.data as ImageNodeData;
        return data?.imageUrl;
      })
      .filter(Boolean) as string[];

    if (selectedImages.length === 0) return;

    // Create a new edit node
    const newNodeId = `prompt-node-${nodeId++}`;
    const newNode: AppNode = {
      id: newNodeId,
      type: 'prompt-node',
      position: nonOverlappingPosition,
      data: {
        prompt: '',
        sourceImages: selectedImages,
      },
      selectable: false,
    };

    // Add the new node to the flow
    setNodes((nds: AppNode[]) => [...nds, newNode]);

    // Create edges connecting each selected image node to the new edit node
    const newEdges = selectedImageNodes.map((imageNode) => ({
      id: `edge-${imageNode.id}-to-${newNodeId}`,
      source: imageNode.id,
      target: newNodeId,
      sourceHandle: 'output',
      targetHandle: 'input',
    }));

    setEdges((edges) => [...edges, ...newEdges]);

    // Focus directly on the new node with the same parameters as in ImageNode.tsx
    setTimeout(() => {
      fitView({
        nodes: [{ id: newNodeId }],
        duration: 500,
        padding: 1.8,
        maxZoom: 0.8,
      });
    }, 100);
  }, [
    selectedImageNodes,
    setNodes,
    setEdges,
    findNonOverlappingPosition,
    fitView,
  ]);

  // Handle mouse up to detect when selection is finished
  useEffect(() => {
    const handleMouseUp = () => {
      if (isSelecting && selectedImageNodes.length > 0) {
        // We were selecting and now we're done, create the edit node
        createEditNodeFromSelection();
        setIsSelecting(false);
      } else {
        setIsSelecting(false);
      }
    };

    window.addEventListener('mouseup', handleMouseUp);
    return () => {
      window.removeEventListener('mouseup', handleMouseUp);
    };
  }, [isSelecting, selectedImageNodes, createEditNodeFromSelection]);

  return (
    <div
      className="flow-wrapper"
      ref={reactFlowWrapper}
      style={{ width: '100%', height: '100vh' }}
      onDragOver={handleDragOver}
      onDrop={handleDrop}
    >
      <ReactFlow
        nodes={nodes}
        nodeTypes={customNodeTypes}
        onNodesChange={onNodesChange}
        edges={edges}
        edgeTypes={edgeTypes}
        onEdgesChange={onEdgesChange}
        onConnect={onConnect}
        onPaneClick={onPaneClick}
        onSelectionChange={onSelectionChange}
        fitView
        minZoom={0.25}
        fitViewOptions={{
          padding: 1.0, // Value from 0-1 represents percentage of the viewport
          minZoom: 0.01,
          maxZoom: 1.5,
        }}
        panOnScroll
        selectionOnDrag
        panActivationKeyCode="Space"
        selectionMode={SelectionMode.Partial}
        panOnDrag={false}
      >
        <Background />
        <MiniMap pannable zoomable />
        <Controls />
        <Panel position="top-left">
          <h1>hitSlop</h1>
          <h3>Cursor for designing,</h3>
          <p>using OpenAI's new Image gen API</p>
        </Panel>
      </ReactFlow>
    </div>
  );
}

export default function App() {
  return (
    <ReactFlowProvider>
      <Flow />
    </ReactFlowProvider>
  );
}
