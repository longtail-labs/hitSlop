import React, { useCallback, useRef, useState, useEffect } from 'react';
import {
  ReactFlow,
  Background,
  Controls,
  ControlButton,
  MiniMap,
  addEdge,
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
  initializeDatabase,
} from './services/database';

import '@xyflow/react/dist/style.css';

import { initialNodes, nodeTypes } from './nodes';
import { initialEdges, edgeTypes } from './edges';
import { AppNode, ImageNodeData } from './nodes/types';
import { ArrowDown, Settings, Trash } from 'lucide-react';
import { DiscordIcon } from './components/ui/discord-icon';
import { GitHubIcon } from './components/ui/github-icon';
import { EXTERNAL_LINKS } from './config/links';
import { createNodeId, createImageNode } from './lib/utils';
import { useIsMobile, usePersistedFlow } from './lib/hooks';
import { useNodePlacement } from './lib/useNodePlacement';

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
import { MobileView } from './components/mobile-view';

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
  const {
    nodes,
    edges,
    setNodes,
    setEdges,
    onNodesChange,
    onEdgesChange,
    isLoaded,
  } = usePersistedFlow(instructionalNodes as AppNode[], initialEdges);

  const { screenToFlowPosition, fitView } = useReactFlow();
  const { findNonOverlappingPosition } = useNodePlacement();
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

  // Initialize TinyBase on mount
  useEffect(() => {
    initializeDatabase();
  }, []);

  // Check for API keys on startup and load tutorial preference
  useEffect(() => {
    if (!isLoaded) return;

    const checkApiKeys = async () => {
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
      try {
        const tutorialDismissed =
          await preferencesService.getTutorialDismissed();
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
            duration: 800,
            padding: 0.2,
            maxZoom: 1,
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

      // Check if the event originated from a node (to prevent conflicts)
      const target = event.target as HTMLElement;
      if (target.closest('.react-flow__node')) {
        console.log(
          'Double-click originated from a node, ignoring pane double-click',
        );
        return;
      }

      if (reactFlowWrapper.current) {
        console.log('Pane double-click triggered');

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

        console.log('Creating new prompt node from pane double-click');

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
          300, // Place it above
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
      imageFiles.forEach((file) => {
        const reader = new FileReader();
        reader.onload = async (e) => {
          const imageDataUrl = e.target?.result as string;
          if (!imageDataUrl) return;

          // Calculate position with offset for multiple files
          const position = findNonOverlappingPosition(
            {
              x: dropPosition.x, // Start at same x
              y: dropPosition.y, // Start at same y
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

            const newNode = await createImageNode(imageId, {
              position,
              source: 'uploaded',
              prompt: `Uploaded: ${file.name}`,
            });

            setNodes((nds) => [...nds, newNode]);
          } catch (error) {
            console.error('Error creating image node:', error);
            // Don't create fallback nodes - the error should be handled properly
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
      await preferencesService.setTutorialDismissed(true);
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
            className="flex items-center gap-2 mb-2"
            style={{ maxWidth: '220px', userSelect: 'none' }}
          >
            <img
              src="/logo.png"
              alt="hitSlop logo"
              className="w-12 border border-gray-300 rounded shadow-md"
            />
            <h1
              className="font-recursive"
              style={{
                userSelect: 'none',
                fontVariationSettings: '"MONO" 1, "wght" 700, "CASL" 0',
                fontSize: '24px',
                fontWeight: 700,
                letterSpacing: '-0.02em',
              }}
            >
              hitSlop.com
            </h1>
          </div>
          <h3
            className="font-recursive"
            style={{
              fontWeight: 'bold',
              userSelect: 'none',
              fontVariationSettings:
                '"MONO" 0.3, "wght" 600, "CASL" 0.8, "CRSV" 0.5',
              fontSize: '16px',
            }}
          >
            Image Gen Playground
          </h3>
          <div
            className="font-recursive"
            style={{
              fontSize: '0.9em',
              lineHeight: '1.4',
              userSelect: 'none',
              fontVariationSettings: '"MONO" 0.5, "wght" 400, "CASL" 0.6',
            }}
          >
            <p>OpenAI Image Gen</p>
            <p>Gemini</p>
            <p>FLUX Kontext</p>
            <p
              style={{
                marginTop: '8px',
                fontStyle: 'italic',
                fontVariationSettings:
                  '"MONO" 0.2, "wght" 400, "CASL" 1, "CRSV" 1',
              }}
            >
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
              <Button
                variant="outline"
                size="sm"
                className="font-recursive"
                style={{
                  fontVariationSettings: '"MONO" 0.8, "wght" 500, "CASL" 0.2',
                }}
              >
                <GitHubIcon className="h-4 w-4" />
                GitHub
              </Button>
            </a>
            <a
              href={EXTERNAL_LINKS.discord}
              target="_blank"
              rel="noopener noreferrer"
            >
              <Button
                variant="outline"
                size="sm"
                className="font-recursive"
                style={{
                  fontVariationSettings: '"MONO" 0.8, "wght" 500, "CASL" 0.2',
                }}
              >
                <DiscordIcon className="h-4 w-4" />
                Discord
              </Button>
            </a>
            <ApiKeyDialog
              open={isApiKeyDialogOpen}
              onOpenChange={setIsApiKeyDialogOpen}
              trigger={
                <Button
                  variant="outline"
                  size="sm"
                  className="font-recursive"
                  style={{
                    fontVariationSettings: '"MONO" 0.8, "wght" 500, "CASL" 0.2',
                  }}
                >
                  <Settings className="h-4 w-4" />
                  Keys
                </Button>
              }
            />
          </div>
        </Panel>
      </ReactFlow>
      <FloatingToolbar setNodesToFocus={setNodesToFocus} />
      <FloatingSidebar setNodesToFocus={setNodesToFocus} />
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
  const isMobile = useIsMobile();

  // Handle tutorial play action
  const handleTutorialPlay = useCallback(() => {
    // Open tutorial link - replace with your actual tutorial URL
    window.open('https://your-tutorial-link.com', '_blank');
  }, []);

  // Render mobile view if on mobile device
  if (isMobile) {
    return <MobileView onPlayClick={handleTutorialPlay} />;
  }

  return (
    <ReactFlowProvider>
      <Flow />
    </ReactFlowProvider>
  );
}
