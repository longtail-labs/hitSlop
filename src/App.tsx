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
  Edge,
  NodeChange,
} from '@xyflow/react';
import { v4 as uuidv4 } from 'uuid';

import { persistenceService, apiKeyService } from './services/database';

import '@xyflow/react/dist/style.css';

import { initialNodes, nodeTypes } from './nodes';
import { initialEdges, edgeTypes } from './edges';
import { AppNode, ImageNodeData } from './nodes/types';
import { ArrowDown, Settings } from 'lucide-react';
import { DiscordIcon } from '@/components/ui/discord-icon';
import { GitHubIcon } from '@/components/ui/github-icon';

// Import annotation node components
import {
  AnnotationNode,
  AnnotationNodeContent,
  AnnotationNodeIcon,
} from '@/components/annotation-node';

import { ApiKeyDialog } from '@/components/api-key-dialog';
import { Button } from '@/components/ui/button';

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
  const [nodes, setNodes, onNodesChange] = useNodesState<AppNode>([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState<Edge>([]);
  const { screenToFlowPosition, getIntersectingNodes, fitView } =
    useReactFlow();
  const [selectedImageNodes, setSelectedImageNodes] = useState<AppNode[]>([]);
  const [previousSelectionCount, setPreviousSelectionCount] = useState(0);
  const [isSelecting, setIsSelecting] = useState(false);
  const [isLoaded, setIsLoaded] = useState(false);
  const [, setIsDragOver] = useState(false);
  const [isApiKeyDialogOpen, setIsApiKeyDialogOpen] = useState(false);
  const [nodesToFocus, setNodesToFocus] = useState<string | null>(null);

  // Load persisted data on mount
  useEffect(() => {
    const loadPersistedData = async () => {
      try {
        const [persistedNodes, persistedEdges] = await Promise.all([
          persistenceService.loadNodes(),
          persistenceService.loadEdges(),
        ]);

        if (persistedNodes.length > 0 || persistedEdges.length > 0) {
          setNodes(persistedNodes as unknown as AppNode[]);
          setEdges(persistedEdges);
        } else {
          // Load default nodes if no persisted data
          setNodes(instructionalNodes as unknown as AppNode[]);
          setEdges(initialEdges);
        }
      } catch (error) {
        console.error('Failed to load persisted data:', error);
        // Fallback to default nodes
        setNodes(instructionalNodes as unknown as AppNode[]);
        setEdges(initialEdges);
      } finally {
        setIsLoaded(true);
      }
    };

    loadPersistedData();
  }, [setNodes, setEdges]);

  // Check for API keys on startup
  useEffect(() => {
    const checkApiKeys = async () => {
      if (!isLoaded) return;

      try {
        const hasOpenAiKey = await apiKeyService.hasApiKey('openai');
        if (!hasOpenAiKey) {
          // Show API key dialog if no OpenAI key is configured
          setTimeout(() => {
            setIsApiKeyDialogOpen(true);
          }, 1000);
        }
      } catch (error) {
        console.error('Failed to check API keys:', error);
      }
    };

    checkApiKeys();
  }, [isLoaded]);

  // Save nodes when they change
  useEffect(() => {
    if (!isLoaded) return;

    const saveNodes = async () => {
      try {
        await persistenceService.saveNodes(nodes);
      } catch (error) {
        console.error('Failed to save nodes:', error);
      }
    };

    saveNodes();
  }, [nodes, isLoaded]);

  // Save edges when they change
  useEffect(() => {
    if (!isLoaded) return;

    const saveEdges = async () => {
      try {
        await persistenceService.saveEdges(edges);
      } catch (error) {
        console.error('Failed to save edges:', error);
      }
    };

    saveEdges();
  }, [edges, isLoaded]);

  // Find a non-overlapping position for a new node
  const findNonOverlappingPosition = useCallback(
    (initialPosition: { x: number; y: number }, nodeType: string) => {
      const dimensions = NODE_DIMENSIONS[
        nodeType as keyof typeof NODE_DIMENSIONS
      ] || { width: 200, height: 200 };

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

  const onConnect: OnConnect = useCallback(
    (connection) => setEdges((edges) => addEdge(connection, edges)),
    [setEdges],
  );

  // Custom onNodesChange handler to detect when nodes are initialized
  const handleNodesChange = useCallback(
    (changes: NodeChange<AppNode>[]) => {
      // Apply the changes
      onNodesChange(changes);

      // Check for dimension changes that indicate a node has been initialized
      if (nodesToFocus) {
        const dimensionChange = changes.find(
          (change) =>
            change.type === 'dimensions' &&
            change.id === nodesToFocus &&
            change.dimensions &&
            change.dimensions.width > 0 &&
            change.dimensions.height > 0,
        );

        if (dimensionChange) {
          // Node has been initialized with dimensions, now we can focus on it
          fitView({
            nodes: [{ id: nodesToFocus }],
            duration: 500,
            padding: 1.8,
            maxZoom: 0.8,
          });

          // Reset the focus target
          setNodesToFocus(null);
        }
      }
    },
    [nodesToFocus, fitView, onNodesChange],
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

        // Generate a unique ID using UUID
        const newNodeId = `prompt-node-${uuidv4()}`;

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
        setNodes((nds) => [...nds, newNode]);

        // Set the node to focus once it's initialized
        setNodesToFocus(newNodeId);
      }
    },
    [screenToFlowPosition, setNodes, findNonOverlappingPosition],
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
    const newNodeId = `prompt-node-${uuidv4()}`;
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
    setNodes((nds) => [...nds, newNode]);

    // Create edges connecting each selected image node to the new edit node
    const newEdges = selectedImageNodes.map((imageNode) => ({
      id: `edge-${imageNode.id}-to-${newNodeId}`,
      source: imageNode.id,
      target: newNodeId,
      sourceHandle: 'output',
      targetHandle: 'input',
    }));

    setEdges((edges) => [...edges, ...newEdges]);

    // Set the node to focus once it's initialized
    setNodesToFocus(newNodeId);
  }, [selectedImageNodes, setNodes, setEdges, findNonOverlappingPosition]);

  // Handle drag and drop for local image files
  const handleDragOver = useCallback((event: React.DragEvent) => {
    event.preventDefault();
    event.stopPropagation();
    setIsDragOver(true);
  }, []);

  const handleDragLeave = useCallback((event: React.DragEvent) => {
    event.preventDefault();
    event.stopPropagation();
    setIsDragOver(false);
  }, []);

  const handleDrop = useCallback(
    (event: React.DragEvent) => {
      event.preventDefault();
      event.stopPropagation();
      setIsDragOver(false);

      const files = Array.from(event.dataTransfer.files);
      const imageFiles = files.filter((file) => file.type.startsWith('image/'));

      if (imageFiles.length === 0) return;

      // Get drop position
      const reactFlowBounds = reactFlowWrapper.current?.getBoundingClientRect();
      if (!reactFlowBounds) return;

      const dropPosition = screenToFlowPosition({
        x: event.clientX - reactFlowBounds.left,
        y: event.clientY - reactFlowBounds.top,
      });

      // Create image nodes for each dropped file
      imageFiles.forEach((file, index) => {
        const reader = new FileReader();
        reader.onload = (e) => {
          const imageUrl = e.target?.result as string;

          // Calculate position with offset for multiple files
          const position = findNonOverlappingPosition(
            {
              x: dropPosition.x + index * 50,
              y: dropPosition.y + index * 50,
            },
            'image-node',
          );

          const newNodeId = `image-node-${uuidv4()}`;
          const newNode: AppNode = {
            id: newNodeId,
            type: 'image-node',
            position,
            data: {
              imageUrl,
              isLoading: false,
              prompt: `Uploaded: ${file.name}`,
            },
            selectable: true,
          };

          setNodes((nds) => [...nds, newNode]);
        };
        reader.readAsDataURL(file);
      });
    },
    [screenToFlowPosition, findNonOverlappingPosition, setNodes],
  );

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
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
    >
      <ReactFlow
        nodes={nodes}
        nodeTypes={customNodeTypes}
        onNodesChange={handleNodesChange}
        edges={edges}
        edgeTypes={edgeTypes}
        onEdgesChange={onEdgesChange}
        onConnect={onConnect}
        onPaneClick={onPaneClick}
        onSelectionChange={onSelectionChange}
        fitView
        minZoom={0.15}
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
          <div className="flex items-center gap-3 mb-2">
            <img src="/hitslop.png" alt="hitSlop logo" className="w-8" />
            <h1>hitSlop</h1>
          </div>
          <h3>Cursor for creating graphics,</h3>
          <p>using OpenAI's new Image gen API & Gemini</p>
        </Panel>
        <Panel position="top-right">
          <div className="flex gap-2">
            <a
              href="https://github.com/longtail-labs/hitslop"
              target="_blank"
              rel="noopener noreferrer"
            >
              <Button variant="outline" size="sm">
                <GitHubIcon className="h-4 w-4" />
                GitHub
              </Button>
            </a>
            <a
              href="https://discord.gg/Sb7nWXbP"
              target="_blank"
              rel="noopener noreferrer"
            >
              <Button variant="outline" size="sm">
                <DiscordIcon className="h-4 w-4" />
                Discord
              </Button>
            </a>
            <ApiKeyDialog
              open={isApiKeyDialogOpen}
              onOpenChange={setIsApiKeyDialogOpen}
              trigger={
                <Button variant="outline" size="sm">
                  <Settings className="h-4 w-4" />
                  Keys
                </Button>
              }
            />
          </div>
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
