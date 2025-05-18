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
  Node,
  ControlButton,
} from '@xyflow/react';
import Dexie from 'dexie';
import { Trash2 } from 'lucide-react';

import '@xyflow/react/dist/style.css';

import { initialNodes, nodeTypes } from './nodes';
import { initialEdges, edgeTypes } from './edges';
import { AppNode, ImageNodeData } from './nodes/types';
import { ArrowDown } from 'lucide-react';
import useStore from './store';
import { useShallow } from 'zustand/react/shallow';

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

// Define the database using Dexie
class FlowDatabase extends Dexie {
  flowData: Dexie.Table<any, number>;
  imageStorage: Dexie.Table<any, string>;

  constructor() {
    super('FlowDatabase');
    this.version(1).stores({
      flowData: '++id,nodes,edges,viewport',
    });
    this.version(2).stores({
      flowData: '++id,nodes,edges,viewport',
      imageStorage: 'key,data,timestamp',
    });
    this.flowData = this.table('flowData');
    this.imageStorage = this.table('imageStorage');
  }
}

const db = new FlowDatabase();
const FLOW_ID = 1; // Use a constant ID for simplicity

// Helper functions to work with the image store
async function storeImage(key: string, data: string) {
  return db.imageStorage.put({
    key,
    data,
    timestamp: Date.now(),
  });
}

async function retrieveImage(key: string) {
  const record = await db.imageStorage.get(key);
  return record?.data;
}

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
        together. You can also drag and drop local images onto the canvas.
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
    selectedImageNodes,
    rfInstance,
    isSelecting,
    isDragging,
    nodesToFocus,
    onNodesChange,
    onEdgesChange,
    onConnect,
    setNodes,
    setRfInstance,
    setIsSelecting,
    setIsDragging,
    findNonOverlappingPosition,
    createEditNodeFromSelection,
    saveFlow,
    restoreFlow,
    clearFlow,
    setSelectedImageNodes,
    setNodesToFocus,
  } = useStore(
    useShallow((state) => ({
      nodes: state.nodes,
      edges: state.edges,
      selectedImageNodes: state.selectedImageNodes,
      rfInstance: state.rfInstance,
      isSelecting: state.isSelecting,
      isDragging: state.isDragging,
      nodesToFocus: state.nodesToFocus,
      onNodesChange: state.onNodesChange,
      onEdgesChange: state.onEdgesChange,
      onConnect: state.onConnect,
      setNodes: state.setNodes,
      setRfInstance: state.setRfInstance,
      setIsSelecting: state.setIsSelecting,
      setIsDragging: state.setIsDragging,
      findNonOverlappingPosition: state.findNonOverlappingPosition,
      createEditNodeFromSelection: state.createEditNodeFromSelection,
      saveFlow: state.saveFlow,
      restoreFlow: state.restoreFlow,
      clearFlow: state.clearFlow,
      setSelectedImageNodes: state.setSelectedImageNodes,
      setNodesToFocus: state.setNodesToFocus,
    })),
  );

  // Initialize the flow on first render
  useEffect(() => {
    restoreFlow();
  }, [restoreFlow]);

  const onInit = useCallback(
    (instance: any) => {
      setRfInstance(instance);
      // Add a small timeout to ensure fitView works properly on initial load
      setTimeout(() => {
        instance.fitView({
          padding: 1.0,
          minZoom: 0.01,
          maxZoom: 1.5,
        });
      }, 100);
    },
    [setRfInstance],
  );

  // Add useEffect to ensure fitView runs when nodes change, but not during drag
  useEffect(() => {
    if (rfInstance && nodes.length > 0 && !isDragging) {
      rfInstance.fitView({
        padding: 1.0,
        minZoom: 0.01,
        maxZoom: 1.5,
      });
    }
  }, [rfInstance, nodes, isDragging]);

  // Focus on specified nodes when nodesToFocus changes
  useEffect(() => {
    if (rfInstance && nodesToFocus.length > 0) {
      const timer = setTimeout(() => {
        rfInstance.fitView({
          nodes: nodesToFocus.map((id) => ({ id })),
          duration: 500,
          padding: 1.8,
          maxZoom: 0.8,
        });
        // Clear the focus list after focusing
        setNodesToFocus([]);
      }, 200);

      return () => clearTimeout(timer);
    }
  }, [nodesToFocus, rfInstance, setNodesToFocus]);

  const onPaneClick = useCallback(
    (event: React.MouseEvent) => {
      if (reactFlowWrapper.current && rfInstance) {
        // Get the position where the user clicked
        const reactFlowBounds =
          reactFlowWrapper.current.getBoundingClientRect();
        const position = rfInstance.screenToFlowPosition({
          x: event.clientX - reactFlowBounds.left,
          y: event.clientY - reactFlowBounds.top,
        });

        // Find a non-overlapping position for the new node
        const nonOverlappingPosition = findNonOverlappingPosition(
          position,
          'prompt-node',
        );

        // Generate a truly unique ID with timestamp and random string to avoid conflicts
        const timestamp = Date.now();
        const randomStr = Math.random().toString(36).substring(2, 10);
        const newNodeId = `prompt-node-${timestamp}-${randomStr}`;

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

        // Save flow after adding node
        setTimeout(() => {
          saveFlow();
        }, 100);

        // Focus on the new node
        setNodesToFocus([newNodeId]);
      }
    },
    [
      rfInstance,
      setNodes,
      findNonOverlappingPosition,
      saveFlow,
      setNodesToFocus,
    ],
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
    },
    [setSelectedImageNodes, setIsSelecting],
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
  }, [
    isSelecting,
    selectedImageNodes,
    createEditNodeFromSelection,
    setIsSelecting,
  ]);

  // Handle drag and drop for external images
  const onDragOver = useCallback((event: React.DragEvent) => {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'copy';
  }, []);

  const onDrop = useCallback(
    (event: React.DragEvent) => {
      event.preventDefault();

      // Get the files being dropped
      const files = event.dataTransfer.files;
      if (files.length === 0) return;

      // Check if files are images
      const imageFiles = Array.from(files).filter((file) =>
        file.type.startsWith('image/'),
      );
      if (imageFiles.length === 0) return;

      // Get the position where the file was dropped
      if (reactFlowWrapper.current && rfInstance) {
        const reactFlowBounds =
          reactFlowWrapper.current.getBoundingClientRect();
        const position = rfInstance.screenToFlowPosition({
          x: event.clientX - reactFlowBounds.left,
          y: event.clientY - reactFlowBounds.top,
        });

        // Process each dropped image
        imageFiles.forEach((file, index) => {
          // Read the file as a data URL
          const reader = new FileReader();
          reader.onload = (loadEvent) => {
            const imageUrl = loadEvent.target?.result as string;
            if (!imageUrl) return;

            // Find a non-overlapping position with slight offset for multiple files
            const offsetPosition = {
              x: position.x + index * 20,
              y: position.y + index * 20,
            };
            const nonOverlappingPosition = findNonOverlappingPosition(
              offsetPosition,
              'image-node',
            );

            // Generate a truly unique ID with timestamp and random string to avoid conflicts
            const timestamp = Date.now();
            const randomStr = Math.random().toString(36).substring(2, 10);
            const newNodeId = `image-node-${timestamp}-${randomStr}`;

            const newNode: AppNode = {
              id: newNodeId,
              type: 'image-node',
              position: nonOverlappingPosition,
              data: {
                imageUrl,
                prompt: `Imported: ${file.name}`,
                isLocalImage: true,
              },
            } as AppNode;

            // Add the new node to the flow
            setNodes((nds) => [...nds, newNode]);

            // Save flow after adding node
            setTimeout(() => {
              saveFlow();
            }, 100);
          };
          reader.readAsDataURL(file);
        });
      }
    },
    [rfInstance, setNodes, findNonOverlappingPosition, saveFlow],
  );

  // Save flow on nodes or edges change, but not during drag
  useEffect(() => {
    if (rfInstance && !isDragging) {
      const timeoutId = setTimeout(() => {
        saveFlow();
      }, 300);
      return () => clearTimeout(timeoutId);
    }
  }, [nodes, edges, saveFlow, rfInstance, isDragging]);

  // Track node drag state
  const onNodeDragStart = useCallback(() => {
    setIsDragging(true);
  }, [setIsDragging]);

  const onNodeDragStop = useCallback(() => {
    setIsDragging(false);
    // Save flow after drag stops
    setTimeout(() => {
      saveFlow();
    }, 100);
  }, [saveFlow, setIsDragging]);

  return (
    <div
      className="flow-wrapper"
      ref={reactFlowWrapper}
      style={{ width: '100%', height: '100vh' }}
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
        onInit={onInit}
        onDragOver={onDragOver}
        onDrop={onDrop}
        onNodeDragStart={onNodeDragStart}
        onNodeDragStop={onNodeDragStop}
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
        <Controls>
          <ControlButton
            title="Clear flow"
            aria-label="Clear flow"
            onClick={clearFlow}
          >
            <Trash2 size={15} />
          </ControlButton>
        </Controls>
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
