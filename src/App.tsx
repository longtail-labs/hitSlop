import { useCallback, useRef, useState, useEffect } from 'react';
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
} from '@xyflow/react';

import '@xyflow/react/dist/style.css';

import { initialNodes, nodeTypes } from './nodes';
import { initialEdges, edgeTypes } from './edges';
import { AppNode, ImageNodeData } from './nodes/types';

// Add some custom styles for our prompt nodes
import './styles.css';

let nodeId = 0;

function Flow() {
  const reactFlowWrapper = useRef<HTMLDivElement>(null);
  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges);
  const { screenToFlowPosition } = useReactFlow();
  const [selectedImageNodes, setSelectedImageNodes] = useState<AppNode[]>([]);
  const [previousSelectionCount, setPreviousSelectionCount] = useState(0);
  const [isSelecting, setIsSelecting] = useState(false);

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

        // Create a new node at the clicked position
        const newNode: AppNode = {
          id: `prompt-node-${nodeId++}`,
          type: 'prompt-node',
          position,
          data: {
            prompt: '',
          },
          selectable: false,
        };

        // Add the new node to the flow
        setNodes((nds) => [...nds, newNode]);
      }
    },
    [screenToFlowPosition, setNodes],
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

    // Collect image URLs from the selected nodes
    const selectedImages = selectedImageNodes
      .map((node) => {
        const data = node.data as ImageNodeData;
        return data?.imageUrl;
      })
      .filter(Boolean) as string[];

    if (selectedImages.length === 0) return;

    // Create a new edit node
    const newNode: AppNode = {
      id: `prompt-node-${nodeId++}`,
      type: 'prompt-node',
      position: avgPosition,
      data: {
        prompt: '',
        sourceImages: selectedImages,
      },
      selectable: false,
    };

    // Add the new node to the flow
    setNodes((nds) => [...nds, newNode]);

    // Create edges connecting each selected image node to the new edit node
    const newEdges = selectedImageNodes.map((imageNode) => ({
      id: `edge-${imageNode.id}-to-${newNode.id}`,
      source: imageNode.id,
      target: newNode.id,
      sourceHandle: 'output',
      targetHandle: 'input',
    }));

    setEdges((edges) => [...edges, ...newEdges]);
  }, [selectedImageNodes, setNodes, setEdges]);

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
    >
      <ReactFlow
        nodes={nodes}
        nodeTypes={nodeTypes}
        onNodesChange={onNodesChange}
        edges={edges}
        edgeTypes={edgeTypes}
        onEdgesChange={onEdgesChange}
        onConnect={onConnect}
        onPaneClick={onPaneClick}
        onSelectionChange={onSelectionChange}
        fitView
        panOnScroll
        selectionOnDrag
        panActivationKeyCode="Space"
        selectionMode={SelectionMode.Partial}
        panOnDrag={false}
      >
        <Background />
        <MiniMap />
        <Controls />
        <Panel position="top-center">
          <h3>AI Image Generator Flow</h3>
          <p>
            Click anywhere on the canvas to create a new prompt node. Press
            Space + drag to pan.
          </p>
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
