import React, { useCallback, useRef, useState, useEffect } from 'react';
import {
  ReactFlow,
  Background,
  Controls,
  ControlButton,
  MiniMap,
  addEdge,
  useNodesState,
  useEdgesState,
  type OnConnect,
  Panel,
  useReactFlow,
  ReactFlowProvider,
  SelectionMode,
  useOnSelectionChange,
  Node,
  Edge,
  NodeChange,
} from '@xyflow/react';
import {
  persistenceService,
  apiKeyService,
  imageService,
  preferencesService,
  db,
} from './services/database';

import '@xyflow/react/dist/style.css';

import { initialNodes, nodeTypes } from './nodes';
import { initialEdges, edgeTypes } from './edges';
import { AppNode, ImageNodeData } from './nodes/types';
import { ArrowDown, Settings, Trash } from 'lucide-react';
import { DiscordIcon } from './components/ui/discord-icon';
import { GitHubIcon } from './components/ui/github-icon';
import { EXTERNAL_LINKS } from './config/links';
import { createNodeId } from './lib/utils';

// Import annotation node components
import {
  AnnotationNode,
  AnnotationNodeContent,
  AnnotationNodeIcon,
} from './components/annotation-node';

import { ApiKeyDialog } from './components/api-key-dialog';
import { Button } from './components/ui/button';
import { FloatingToolbar } from './components/floating-toolbar';
import { FloatingSidebar } from './components/floating-sidebar';
import { TutorialBox } from './components/tutorial-box';

// // Add some custom styles for our prompt nodes
// import './styles/styles.css';

// // Add global styles for monospace font
// const globalStyle = document.createElement('style');
// globalStyle.innerHTML = `
//   .react-flow, .react-flow__node, .react-flow__controls, .react-flow__panel, button, input {
//     font-family: 'JetBrains Mono', 'Fira Code', 'Courier New', monospace !important;
//   }
// `;
// document.head.appendChild(globalStyle);

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
        Double-click anywhere on the canvas to create a new prompt node.
        Double-click on an image to edit it, or select and drag multiple images
        to edit them together.
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
  const [isLoaded, setIsLoaded] = useState(false);
  const [, setIsDragOver] = useState(false);
  const [isApiKeyDialogOpen, setIsApiKeyDialogOpen] = useState(false);
  const [nodesToFocus, setNodesToFocus] = useState<string | null>(null);
  const [currentSelectedImageNodes, setCurrentSelectedImageNodes] = useState<
    AppNode[]
  >([]);
  const [showTutorialBox, setShowTutorialBox] = useState(false);

  // Handle selection changes with the React Flow hook - just track the selection
  const onSelectionChangeHandler = useCallback(
    ({ nodes }: { nodes: Node[]; edges: Edge[] }) => {
      // Filter for image nodes
      const imageNodes = nodes.filter(
        (node) => node.type === 'image-node',
      ) as AppNode[];

      setCurrentSelectedImageNodes(imageNodes);
    },
    [],
  );

  useOnSelectionChange({
    onChange: onSelectionChangeHandler,
  });

  // Request persistent storage to prevent data loss
  useEffect(() => {
    const requestPersistence = async () => {
      console.log('Requesting storage persistence');
      if (navigator.storage && navigator.storage.persist) {
        console.log('Storage API is available');
        try {
          const isPersisted = await navigator.storage.persisted();
          if (!isPersisted) {
            const result = await navigator.storage.persist();
            if (result) {
              console.log('Storage persistence granted.');
            } else {
              console.warn(
                'Storage persistence not granted. Data may be cleared by the browser.',
              );
            }
          }
        } catch (error) {
          console.error('Error requesting storage persistence:', error);
        }
      }
    };

    requestPersistence();
  }, []);

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

  // Check for API keys on startup and load tutorial preference
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

    const loadTutorialPreference = async () => {
      if (!isLoaded) return;

      try {
        const tutorialDismissed = await preferencesService.getPreference(
          'tutorial_dismissed',
          false,
        );
        setShowTutorialBox(!tutorialDismissed);
      } catch (error) {
        console.error('Failed to load tutorial preference:', error);
        // Default to showing tutorial if there's an error
        setShowTutorialBox(true);
      }
    };

    checkApiKeys();
    loadTutorialPreference();
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
      'use memo';
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
    (connection) => {
      'use memo';
      return setEdges((edges) => addEdge(connection, edges));
    },
    [setEdges],
  );

  // Custom onNodesChange handler to detect when nodes are initialized
  const handleNodesChange = useCallback(
    (changes: NodeChange<AppNode>[]) => {
      'use memo';
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

  const onPaneDoubleClick = useCallback(
    (event: React.MouseEvent) => {
      'use memo';
      if (reactFlowWrapper.current) {
        // Get the position where the user double-clicked
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

        // Generate a unique ID using nanoid
        const newNodeId = createNodeId('prompt-node');

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

  const createEditNodeFromSelection = useCallback(
    (imageNodes: AppNode[]) => {
      'use memo';
      if (imageNodes.length === 0 || !reactFlowWrapper.current) return;

      // Calculate the average position of selected nodes to place the new node
      const avgPosition = {
        x:
          imageNodes.reduce((sum, node) => sum + node.position.x, 0) /
          imageNodes.length,
        y:
          imageNodes.reduce((sum, node) => sum + node.position.y, 0) /
            imageNodes.length -
          200, // Place it above
      };

      // Find a non-overlapping position based on the average position
      const nonOverlappingPosition = findNonOverlappingPosition(
        avgPosition,
        'prompt-node',
      );

      // Collect image references from the selected nodes (prefer imageId over imageUrl)
      const selectedImageReferences = imageNodes
        .map((node) => {
          const data = node.data as ImageNodeData;
          return data?.imageId || data?.imageUrl; // Prefer imageId, fallback to imageUrl
        })
        .filter(Boolean) as string[];

      if (selectedImageReferences.length === 0) return;

      // Create a new edit node
      const newNodeId = createNodeId('prompt-node');
      const newNode: AppNode = {
        id: newNodeId,
        type: 'prompt-node',
        position: nonOverlappingPosition,
        data: {
          prompt: '',
          sourceImages: selectedImageReferences, // These can be image IDs or URLs
        },
        selectable: false,
      };

      // Add the new node to the flow
      setNodes((nds) => [...nds, newNode]);

      // Create edges connecting each selected image node to the new edit node
      const newEdges = imageNodes.map((imageNode) => ({
        id: `edge-${imageNode.id}-to-${newNodeId}`,
        source: imageNode.id,
        target: newNodeId,
        sourceHandle: 'output',
        targetHandle: 'input',
      }));

      setEdges((edges) => [...edges, ...newEdges]);

      // Set the node to focus once it's initialized
      setNodesToFocus(newNodeId);
    },
    [setNodes, setEdges, findNonOverlappingPosition],
  );

  // Listen for mouse up to create edit node when user finishes selecting
  useEffect(() => {
    // Don't run if the app hasn't loaded yet
    if (!isLoaded) return;

    const handleMouseUp = () => {
      // Only create edit node if we have multiple image nodes selected
      if (currentSelectedImageNodes.length > 1) {
        // Filter out any nodes that no longer exist (in case they were deleted)
        const existingNodes = currentSelectedImageNodes.filter((selectedNode) =>
          nodes.some((currentNode) => currentNode.id === selectedNode.id),
        );

        if (existingNodes.length > 1) {
          createEditNodeFromSelection(existingNodes);
          // Clear the selection after creating the edit node to prevent repeated triggers
          setCurrentSelectedImageNodes([]);
        } else {
          // If we don't have enough existing nodes, clear the selection
          setCurrentSelectedImageNodes([]);
        }
      }
    };

    // Add event listener to the document to catch mouse up anywhere
    document.addEventListener('mouseup', handleMouseUp);

    return () => {
      document.removeEventListener('mouseup', handleMouseUp);
    };
  }, [
    currentSelectedImageNodes,
    createEditNodeFromSelection,
    nodes,
    setCurrentSelectedImageNodes,
    isLoaded,
  ]);

  // Handle drag and drop for local image files
  const handleDragOver = useCallback((event: React.DragEvent) => {
    'use memo';
    event.preventDefault();
    event.stopPropagation();
    setIsDragOver(true);
  }, []);

  const handleDragLeave = useCallback((event: React.DragEvent) => {
    'use memo';
    event.preventDefault();
    event.stopPropagation();
    setIsDragOver(false);
  }, []);

  const handleDrop = useCallback(
    (event: React.DragEvent) => {
      'use memo';
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
        reader.onload = async (e) => {
          const imageDataUrl = e.target?.result as string;
          if (!imageDataUrl) return;

          // Calculate position with offset for multiple files
          const position = findNonOverlappingPosition(
            {
              x: dropPosition.x + index * 50,
              y: dropPosition.y + index * 50,
            },
            'image-node',
          );

          try {
            // Store the image in optimized storage
            const imageId = await imageService.storeImage(
              imageDataUrl,
              'uploaded',
              {
                // We could extract dimensions here if needed
              },
            );

            const newNodeId = createNodeId('image-node');
            const newNode: AppNode = {
              id: newNodeId,
              type: 'image-node',
              position,
              data: {
                imageId, // Use the stored image ID
                source: 'uploaded' as const,
                isLoading: false,
                prompt: `Uploaded: ${file.name}`,
              },
              selectable: true,
            };

            setNodes((nds) => [...nds, newNode]);
          } catch (error) {
            console.error('Error storing uploaded image:', error);
            // Fallback to legacy storage for backward compatibility
            const newNodeId = createNodeId('image-node');
            const newNode: AppNode = {
              id: newNodeId,
              type: 'image-node',
              position,
              data: {
                imageUrl: imageDataUrl, // Fallback to direct URL storage
                source: 'uploaded' as const,
                isLoading: false,
                prompt: `Uploaded: ${file.name}`,
              },
              selectable: true,
            };

            setNodes((nds) => [...nds, newNode]);
          }
        };
        reader.readAsDataURL(file);
      });
    },
    [screenToFlowPosition, findNonOverlappingPosition, setNodes],
  );

  // Handle tutorial box actions
  const handleTutorialDismiss = useCallback(async () => {
    try {
      await preferencesService.setPreference('tutorial_dismissed', true);
      setShowTutorialBox(false);
    } catch (error) {
      console.error('Failed to save tutorial preference:', error);
      // Still hide it locally even if saving fails
      setShowTutorialBox(false);
    }
  }, []);

  const handleTutorialPlay = useCallback(() => {
    // Open tutorial link - replace with your actual tutorial URL
    window.open('https://your-tutorial-link.com', '_blank');
  }, []);

  // Add clear all function
  const clearAllData = useCallback(async () => {
    const confirmed = window.confirm(
      'Are you sure you want to clear all data? This will remove all nodes, edges, images, and preferences (including tutorial state). API keys will be preserved. This action cannot be undone.',
    );

    if (confirmed) {
      try {
        // Clear all data from the database except API keys
        await persistenceService.clearAll();
        await db.images.clear();

        // Reset the flow to initial state
        setNodes([]);
        setEdges([]);
        setCurrentSelectedImageNodes([]);

        // Reset tutorial state since preferences were cleared
        setShowTutorialBox(true);

        alert(
          'All data has been cleared successfully. API keys have been preserved. Tutorial will show again on next visit.',
        );
      } catch (error) {
        console.error('Error clearing data:', error);
        alert('An error occurred while clearing data. Please try again.');
      }
    }
  }, [setNodes, setEdges]);

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
        onDoubleClick={onPaneDoubleClick}
        zoomOnDoubleClick={false}
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
        {!showTutorialBox && <MiniMap pannable zoomable />}
        <Controls>
          <ControlButton onClick={clearAllData} title="Clear all data">
            <Trash />
          </ControlButton>
        </Controls>
        <Panel position="top-left">
          <div
            className="flex items-center gap-3 mb-2"
            style={{ maxWidth: '220px' }}
          >
            <img src="/hitslop.png" alt="hitSlop logo" className="w-8" />
            <h1>hitSlop</h1>
          </div>
          <h3 style={{ fontWeight: 'bold' }}>Image Gen Playground</h3>
          <div style={{ fontSize: '0.9em', lineHeight: '1.4' }}>
            <p>OpenAI Image Gen</p>
            <p>Gemini</p>
            <p>FLUX Knotext</p>
            <p style={{ marginTop: '8px', fontStyle: 'italic' }}>
              Join discord to suggest more
            </p>
          </div>
        </Panel>
        <Panel position="top-right">
          <div className="flex gap-2">
            <a
              href={EXTERNAL_LINKS.github}
              target="_blank"
              rel="noopener noreferrer"
            >
              <Button variant="outline" size="sm">
                <GitHubIcon className="h-4 w-4" />
                GitHub
              </Button>
            </a>
            <a
              href={EXTERNAL_LINKS.discord}
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
      <FloatingToolbar
        findNonOverlappingPosition={findNonOverlappingPosition}
        setNodesToFocus={setNodesToFocus}
      />
      <FloatingSidebar
        findNonOverlappingPosition={findNonOverlappingPosition}
        setNodesToFocus={setNodesToFocus}
      />
      {showTutorialBox && (
        <TutorialBox
          onDismiss={handleTutorialDismiss}
          onPlayClick={handleTutorialPlay}
        />
      )}
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
