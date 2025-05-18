import { create } from 'zustand';
import {
  Connection,
  Edge,
  EdgeChange,
  NodeChange,
  addEdge,
  OnNodesChange,
  OnEdgesChange,
  OnConnect,
  Node,
  Viewport,
  applyNodeChanges,
  applyEdgeChanges,
  XYPosition,
} from '@xyflow/react';
import Dexie from 'dexie';
import { AppNode, ImageNodeData, PromptNodeData } from './nodes/types';
import { initialEdges } from './edges';

// Define standard node dimensions for collision detection
const NODE_DIMENSIONS = {
  'prompt-node': { width: 300, height: 250 },
  'image-node': { width: 300, height: 300 },
};

// Define our own initial nodes to avoid circular dependencies
const instructionalNodes: AppNode[] = [
  // Just the annotation node
  {
    id: 'instruction-annotation',
    type: 'annotation-node',
    position: { x: 50, y: -100 },
    data: {},
  },
];

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

type RFState = {
  nodes: AppNode[];
  edges: Edge[];
  selectedImageNodes: AppNode[];
  viewport: Viewport;
  rfInstance: any | null;
  isSelecting: boolean;
  isDragging: boolean;
  previousSelectionCount: number;
  lastSavedFlow: { nodeCount: number; edgeCount: number } | null;
  nodesToFocus: string[];

  // Actions
  onNodesChange: OnNodesChange;
  onEdgesChange: OnEdgesChange;
  onConnect: OnConnect;
  setNodes: (nodes: AppNode[] | ((nodes: AppNode[]) => AppNode[])) => void;
  setEdges: (edges: Edge[] | ((edges: Edge[]) => Edge[])) => void;
  setSelectedImageNodes: (nodes: AppNode[]) => void;
  setRfInstance: (instance: any) => void;
  setIsSelecting: (isSelecting: boolean) => void;
  setIsDragging: (isDragging: boolean) => void;
  setPreviousSelectionCount: (count: number) => void;
  setViewport: (viewport: Viewport) => void;
  setNodesToFocus: (nodeIds: string[]) => void;

  // Helper functions
  findNonOverlappingPosition: (initialPosition: XYPosition, nodeType: string) => XYPosition;
  createEditNodeFromSelection: () => void;
  saveFlow: () => Promise<void>;
  restoreFlow: () => Promise<void>;
  clearFlow: () => Promise<void>;

  // Node Creation Helpers
  createPromptNode: (position: XYPosition, data?: Partial<PromptNodeData>) => AppNode;
  createImageNode: (position: XYPosition, data?: Partial<ImageNodeData>) => AppNode;

  // Database helper functions
  storeImage: (key: string, data: string) => Promise<any>;
  retrieveImage: (key: string) => Promise<string | undefined>;
};

const useStore = create<RFState>((set, get) => ({
  nodes: instructionalNodes,
  edges: initialEdges,
  selectedImageNodes: [],
  viewport: { x: 0, y: 0, zoom: 1 },
  rfInstance: null,
  isSelecting: false,
  isDragging: false,
  previousSelectionCount: 0,
  lastSavedFlow: null,
  nodesToFocus: [],

  // Basic flow actions
  onNodesChange: (changes: NodeChange[]) => {
    set({
      nodes: applyNodeChanges(changes, get().nodes) as AppNode[],
    });
  },

  onEdgesChange: (changes: EdgeChange[]) => {
    set({
      edges: applyEdgeChanges(changes, get().edges),
    });
  },

  onConnect: (connection: Connection) => {
    set({
      edges: addEdge(connection, get().edges),
    });
    // Save flow after connecting edges
    setTimeout(() => {
      get().saveFlow();
    }, 100);
  },

  setNodes: (nodes) => {
    if (typeof nodes === 'function') {
      set({ nodes: nodes(get().nodes) });
    } else {
      set({ nodes });
    }
  },

  setEdges: (edges) => {
    if (typeof edges === 'function') {
      set({ edges: edges(get().edges) });
    } else {
      set({ edges });
    }
  },

  setSelectedImageNodes: (selectedImageNodes) => set({ selectedImageNodes }),
  setRfInstance: (rfInstance) => set({ rfInstance }),
  setIsSelecting: (isSelecting) => set({ isSelecting }),
  setIsDragging: (isDragging) => set({ isDragging }),
  setPreviousSelectionCount: (previousSelectionCount) => set({ previousSelectionCount }),
  setViewport: (viewport) => set({ viewport }),
  setNodesToFocus: (nodesToFocus) => set({ nodesToFocus }),

  // Helper functions to create properly typed nodes
  createPromptNode: (position, data = {}) => {
    const timestamp = Date.now();
    const randomStr = Math.random().toString(36).substring(2, 10);
    const id = `prompt-node-${timestamp}-${randomStr}`;

    return {
      id,
      type: 'prompt-node',
      position,
      data: {
        prompt: '',
        ...data,
      },
      selectable: false,
    } as AppNode;
  },

  createImageNode: (position, data = {}) => {
    const timestamp = Date.now();
    const randomStr = Math.random().toString(36).substring(2, 10);
    const id = `image-node-${timestamp}-${randomStr}`;

    return {
      id,
      type: 'image-node',
      position,
      data: {
        ...data,
      },
    } as AppNode;
  },

  // Helper function to find non-overlapping positions
  findNonOverlappingPosition: (initialPosition, nodeType) => {
    const rfInstance = get().rfInstance;
    if (!rfInstance) return initialPosition;

    const currentNodes = get().nodes;
    const dimensions = NODE_DIMENSIONS[nodeType as keyof typeof NODE_DIMENSIONS] || { width: 200, height: 200 };

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
    let intersections: Node[] = [];

    try {
      // Use the rfInstance to find intersecting nodes if the method exists
      if (rfInstance && typeof rfInstance.getIntersectingNodes === 'function') {
        intersections = rfInstance.getIntersectingNodes(tempNode);
      } else {
        // Fallback: simple overlap detection
        intersections = currentNodes.filter(node => {
          if (!node.width || !node.height) return false;

          const nodeBounds = {
            left: node.position.x,
            right: node.position.x + (node.width || 0),
            top: node.position.y,
            bottom: node.position.y + (node.height || 0)
          };

          const tempBounds = {
            left: position.x,
            right: position.x + dimensions.width,
            top: position.y,
            bottom: position.y + dimensions.height
          };

          return !(
            tempBounds.right < nodeBounds.left ||
            tempBounds.left > nodeBounds.right ||
            tempBounds.bottom < nodeBounds.top ||
            tempBounds.top > nodeBounds.bottom
          );
        });
      }
    } catch (e) {
      console.error('Error checking for intersections:', e);
    }

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

        try {
          // Check for intersections with the new position
          if (rfInstance && typeof rfInstance.getIntersectingNodes === 'function') {
            intersections = rfInstance.getIntersectingNodes(tempNode);
          } else {
            // Use the same fallback as before
            intersections = currentNodes.filter(node => {
              if (!node.width || !node.height) return false;

              const nodeBounds = {
                left: node.position.x,
                right: node.position.x + (node.width || 0),
                top: node.position.y,
                bottom: node.position.y + (node.height || 0)
              };

              const tempBounds = {
                left: position.x,
                right: position.x + dimensions.width,
                top: position.y,
                bottom: position.y + dimensions.height
              };

              return !(
                tempBounds.right < nodeBounds.left ||
                tempBounds.left > nodeBounds.right ||
                tempBounds.bottom < nodeBounds.top ||
                tempBounds.top > nodeBounds.bottom
              );
            });
          }
        } catch (e) {
          console.error('Error checking for intersections in loop:', e);
          break;
        }

        attempts++;
      }
    }

    return position;
  },

  createEditNodeFromSelection: () => {
    const { selectedImageNodes, findNonOverlappingPosition, setNodes, setEdges } = get();

    if (selectedImageNodes.length === 0 || !get().rfInstance) return;

    // Calculate the average position of selected nodes to place the new node
    const avgPosition = {
      x: selectedImageNodes.reduce((sum, node) => sum + node.position.x, 0) / selectedImageNodes.length,
      y: selectedImageNodes.reduce((sum, node) => sum + node.position.y, 0) / selectedImageNodes.length - 200, // Place it above
    };

    // Find a non-overlapping position based on the average position
    const nonOverlappingPosition = findNonOverlappingPosition(avgPosition, 'prompt-node');

    // Collect image URLs from the selected nodes
    const selectedImages = selectedImageNodes
      .map((node) => {
        const data = node.data as ImageNodeData;
        return data?.imageUrl;
      })
      .filter(Boolean) as string[];

    if (selectedImages.length === 0) return;

    // Create a new node with proper typing
    const newNode = get().createPromptNode(nonOverlappingPosition, {
      prompt: '',
      sourceImages: selectedImages,
    });

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

    // Save flow after creating edit node
    setTimeout(() => {
      get().saveFlow();
    }, 100);

    // Focus directly on the new node
    get().setNodesToFocus([newNode.id]);
  },

  // Database operations
  saveFlow: async () => {
    const { rfInstance, nodes, edges } = get();
    if (!rfInstance) return;

    try {
      const flow = rfInstance.toObject();

      // Skip saving if there's no change from the last saved state
      const flowKey = {
        nodeCount: flow.nodes.length,
        edgeCount: flow.edges.length,
      };

      if (flow.nodes.length === 0) return;

      // Check if we already saved this exact configuration
      const lastSavedFlow = get().lastSavedFlow;
      if (
        lastSavedFlow &&
        lastSavedFlow.nodeCount === flowKey.nodeCount &&
        lastSavedFlow.edgeCount === flowKey.edgeCount
      ) {
        // No need to save, already saved this state
        return;
      }

      // Update our reference
      set({ lastSavedFlow: flowKey });

      // Process nodes to handle large binary data
      const processedNodes = await Promise.all(
        flow.nodes.map(async (node: any) => {
          // Create a shallow copy of the node
          const processedNode = { ...node };

          // If the node has image data, handle it specially
          if (node.type === 'image-node' && node.data && node.data.imageUrl) {
            // For images, we'll just store a reference that it's a large binary
            // Instead of storing the full base64 in the node data
            if (node.data.imageUrl.length > 10000) {
              // Store the image separately with a key based on the node ID
              const imageKey = `image-${node.id}`;

              // Store the image data separately
              await storeImage(imageKey, node.data.imageUrl);

              // Replace the actual image data with a reference
              processedNode.data = {
                ...node.data,
                imageUrl: `__REF_${imageKey}__`,
                isImageReference: true,
              };
            }
          }

          // Similarly for source images in prompt nodes
          if (
            node.type === 'prompt-node' &&
            node.data &&
            node.data.sourceImages &&
            node.data.sourceImages.length > 0
          ) {
            const processedSourceImages = await Promise.all(
              node.data.sourceImages.map(
                async (imgUrl: string, index: number) => {
                  if (imgUrl && imgUrl.length > 10000) {
                    const imageKey = `source-image-${node.id}-${index}`;
                    await storeImage(imageKey, imgUrl);
                    return `__REF_${imageKey}__`;
                  }
                  return imgUrl;
                },
              ),
            );

            processedNode.data = {
              ...node.data,
              sourceImages: processedSourceImages,
              hasImageReferences: true,
            };
          }

          return processedNode;
        }),
      );

      // Save to IndexedDB
      await db.flowData.put({
        id: FLOW_ID,
        nodes: processedNodes,
        edges: flow.edges,
        viewport: flow.viewport,
      });
    } catch (error) {
      console.error('Error preparing flow for save:', error);
    }
  },

  restoreFlow: async () => {
    const { setNodes, setEdges, setViewport } = get();

    try {
      const savedFlow = await db.flowData.get(FLOW_ID);

      if (savedFlow) {
        let { nodes: savedNodes, edges: savedEdges, viewport } = savedFlow;

        // Restore image references from IndexedDB
        if (savedNodes) {
          savedNodes = await Promise.all(
            savedNodes.map(async (node: any) => {
              // Restore image node references
              if (
                node.type === 'image-node' &&
                node.data &&
                node.data.imageUrl &&
                typeof node.data.imageUrl === 'string' &&
                node.data.imageUrl.startsWith('__REF_')
              ) {
                const imageKey = node.data.imageUrl
                  .replace('__REF_', '')
                  .replace('__', '');
                const imageData = await retrieveImage(imageKey);

                if (imageData) {
                  node.data = {
                    ...node.data,
                    imageUrl: imageData,
                    isImageReference: false,
                  };
                }
              }

              // Restore prompt node source image references
              if (
                node.type === 'prompt-node' &&
                node.data &&
                node.data.sourceImages &&
                node.data.hasImageReferences
              ) {
                const restoredSourceImages = await Promise.all(
                  node.data.sourceImages.map(async (ref: string) => {
                    if (typeof ref === 'string' && ref.startsWith('__REF_')) {
                      const imageKey = ref
                        .replace('__REF_', '')
                        .replace('__', '');
                      const imageData = await retrieveImage(imageKey);
                      return imageData || ref;
                    }
                    return ref;
                  }),
                );

                node.data = {
                  ...node.data,
                  sourceImages: restoredSourceImages,
                  hasImageReferences: false,
                };
              }

              return node;
            }),
          );
        }

        if (savedNodes) setNodes(savedNodes as AppNode[]);
        if (savedEdges) setEdges(savedEdges);
        if (viewport) {
          const { x = 0, y = 0, zoom = 1 } = viewport;
          setViewport({ x, y, zoom });
        }
      }
    } catch (error) {
      console.error('Error restoring flow:', error);
    }
  },

  clearFlow: async () => {
    const { setNodes, setEdges, setViewport } = get();

    try {
      // Clear Dexie data
      await db.flowData.delete(FLOW_ID);

      // Clear image storage
      await db.imageStorage.clear();

      // Reset to initial state
      setNodes(instructionalNodes);
      setEdges(initialEdges);
      setViewport({ x: 0, y: 0, zoom: 1 });
    } catch (error) {
      console.error('Error clearing flow:', error);
    }
  },

  // Database helper functions
  storeImage,
  retrieveImage,
}));

export default useStore; 