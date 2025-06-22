import { createStore } from 'tinybase';
import { createIndexedDbPersister } from 'tinybase/persisters/persister-indexed-db';
import { createIndexes } from 'tinybase/indexes';
import { Node, Edge, NodeChange, EdgeChange } from '@xyflow/react';
import { createImageId } from '@/app/lib/utils';

// TinyBase schemas for type safety
export const tablesSchema = {
  nodes: {
    id: { type: 'string' },
    type: { type: 'string' },
    positionX: { type: 'number' },
    positionY: { type: 'number' },
    data: { type: 'string' }, // JSON stringified
    selectable: { type: 'boolean', default: true },
  },
  edges: {
    id: { type: 'string' },
    source: { type: 'string' },
    target: { type: 'string' },
    sourceHandle: { type: 'string', default: '' },
    targetHandle: { type: 'string', default: '' },
  },
  apiKeys: {
    id: { type: 'string' },
    provider: { type: 'string' },
    key: { type: 'string' },
    createdAt: { type: 'number' },
    updatedAt: { type: 'number' },
  },
  images: {
    id: { type: 'string' },
    imageData: { type: 'string' }, // Base64 data URL
    mimeType: { type: 'string' },
    size: { type: 'number' },
    createdAt: { type: 'number' },
    width: { type: 'number', default: 0 },
    height: { type: 'number', default: 0 },
    source: { type: 'string', default: 'generated' },
    tags: { type: 'string', default: '' }, // JSON stringified array
  },
} as const;

export const valuesSchema = {
  tutorialDismissed: { type: 'boolean', default: false },
} as const;

// Create the main store
const mainStore = createStore()
  .setTablesSchema(tablesSchema)
  .setValuesSchema(valuesSchema);

// Create indexes for better querying
const mainIndexes = createIndexes(mainStore)
  .setIndexDefinition('nodesByType', 'nodes', 'type')
  .setIndexDefinition('imagesBySource', 'images', 'source')
  .setIndexDefinition('apiKeysByProvider', 'apiKeys', 'provider');

// Create IndexedDB persister
const mainPersister = createIndexedDbPersister(mainStore, 'hitSlopDB');

// Track database initialization state
let isDatabaseReady = false;
let databaseInitPromise: Promise<void> | null = null;

// Initialize persistence
export const initializeDatabase = async () => {
  if (databaseInitPromise) {
    return databaseInitPromise;
  }

  databaseInitPromise = (async () => {
    try {
      console.log('🔄 Initializing TinyBase database...');
      
      // Request persistent storage
      if (navigator.storage && navigator.storage.persist) {
        try {
          const isPersisted = await navigator.storage.persisted();
          if (!isPersisted) {
            const result = await navigator.storage.persist();
            console.log(result ? '✅ Storage persistence granted' : '⚠️ Storage persistence not granted');
          } else {
            console.log('✅ Storage already persistent');
          }
        } catch (error) {
          console.error('❌ Error requesting storage persistence:', error);
        }
      }

      await mainPersister.startAutoPersisting();
      await new Promise(resolve => setTimeout(resolve, 100));
      
      isDatabaseReady = true;
      console.log('✅ TinyBase database initialized');
    } catch (error) {
      console.error('❌ Failed to initialize TinyBase database:', error);
      isDatabaseReady = true;
    }
  })();

  return databaseInitPromise;
};

const ensureDatabaseReady = async () => {
  if (!isDatabaseReady) {
    await initializeDatabase();
  }
};

// Interface definitions
export interface PersistedNode extends Node {
  id: string;
  type: string;
  position: { x: number; y: number };
  data: any;
  selectable?: boolean;
}

export interface PersistedEdge extends Edge {
  id: string;
  source: string;
  target: string;
  sourceHandle?: string;
  targetHandle?: string;
}

export interface StoredImage {
  id: string;
  imageData: string;
  mimeType: string;
  size: number;
  createdAt: Date;
  width?: number;
  height?: number;
  source?: 'generated' | 'uploaded' | 'edited' | 'unsplash';
  tags?: string[];
}

// Persistence service
export const persistenceService = {
  applyNodeChanges(changes: NodeChange[]) {
    mainStore.transaction(() => {
      changes.forEach((change) => {
        try {
          if (change.type === 'add') {
            const node = change.item;
            mainStore.setRow('nodes', node.id, {
              id: node.id,
              type: node.type || '',
              positionX: node.position.x,
              positionY: node.position.y,
              data: JSON.stringify(node.data),
              selectable: node.selectable ?? true,
            });
          } else if (change.type === 'position' && change.position) {
            mainStore.setCell('nodes', change.id, 'positionX', change.position.x);
            mainStore.setCell('nodes', change.id, 'positionY', change.position.y);
          } else if (change.type === 'remove') {
            mainStore.delRow('nodes', change.id);
          }
        } catch (error) {
          console.error('❌ Error processing node change:', change, error);
        }
      });
    });
  },

  applyEdgeChanges(changes: EdgeChange[]) {
    mainStore.transaction(() => {
      changes.forEach((change) => {
        try {
          if (change.type === 'add') {
            const edge = change.item;
            mainStore.setRow('edges', edge.id, {
              id: edge.id,
              source: edge.source,
              target: edge.target,
              sourceHandle: edge.sourceHandle || '',
              targetHandle: edge.targetHandle || '',
            });
          } else if (change.type === 'remove') {
            mainStore.delRow('edges', change.id);
          }
        } catch (error) {
          console.error('❌ Error processing edge change:', change, error);
        }
      });
    });
  },

  async saveNodes(nodes: Node[]) {
    mainStore.transaction(() => {
      const storeNodeIds = new Set(mainStore.getRowIds('nodes'));
      const incomingNodeIds = new Set(nodes.map((n) => n.id));

      // Add or update nodes
      nodes.forEach((node) => {
        mainStore.setRow('nodes', node.id, {
          id: node.id,
          type: node.type || '',
          positionX: node.position.x,
          positionY: node.position.y,
          data: JSON.stringify(node.data),
          selectable: node.selectable ?? true,
        });
      });

      // Delete orphaned nodes
      storeNodeIds.forEach((id) => {
        if (!incomingNodeIds.has(id)) {
          mainStore.delRow('nodes', id);
        }
      });
    });
  },

  async saveEdges(edges: Edge[]) {
    mainStore.transaction(() => {
      const storeEdgeIds = new Set(mainStore.getRowIds('edges'));
      const incomingEdgeIds = new Set(edges.map((e) => e.id));

      // Add or update edges
      edges.forEach((edge) => {
        mainStore.setRow('edges', edge.id, {
          id: edge.id,
          source: edge.source,
          target: edge.target,
          sourceHandle: edge.sourceHandle || '',
          targetHandle: edge.targetHandle || '',
        });
      });

      // Delete orphaned edges
      storeEdgeIds.forEach((id) => {
        if (!incomingEdgeIds.has(id)) {
          mainStore.delRow('edges', id);
        }
      });
    });
  },

  async loadNodes(): Promise<PersistedNode[]> {
    await ensureDatabaseReady();
    try {
      const nodes: PersistedNode[] = [];
      mainStore.forEachRow('nodes', (rowId) => {
        const node: PersistedNode = {
          id: mainStore.getCell('nodes', rowId, 'id') as string,
          type: mainStore.getCell('nodes', rowId, 'type') as string,
          position: { 
            x: mainStore.getCell('nodes', rowId, 'positionX') as number, 
            y: mainStore.getCell('nodes', rowId, 'positionY') as number 
          },
          data: JSON.parse(mainStore.getCell('nodes', rowId, 'data') as string),
          selectable: mainStore.getCell('nodes', rowId, 'selectable') as boolean,
        };
        nodes.push(node);
      });
      return nodes;
    } catch (error) {
      console.error('Error loading nodes:', error);
      return [];
    }
  },

  async loadEdges(): Promise<PersistedEdge[]> {
    await ensureDatabaseReady();
    try {
      const edges: PersistedEdge[] = [];
      mainStore.forEachRow('edges', (rowId) => {
        const sourceHandle = mainStore.getCell('edges', rowId, 'sourceHandle') as string;
        const targetHandle = mainStore.getCell('edges', rowId, 'targetHandle') as string;
        
        const edge: PersistedEdge = {
          id: mainStore.getCell('edges', rowId, 'id') as string,
          source: mainStore.getCell('edges', rowId, 'source') as string,
          target: mainStore.getCell('edges', rowId, 'target') as string,
          sourceHandle: sourceHandle && sourceHandle !== '' ? sourceHandle : undefined,
          targetHandle: targetHandle && targetHandle !== '' ? targetHandle : undefined,
        };
        edges.push(edge);
      });
      return edges;
    } catch (error) {
      console.error('Error loading edges:', error);
      return [];
    }
  },

  async clearAll() {
    ['nodes', 'edges', 'images'].forEach(tableId => {
      if (mainStore.getTableIds().includes(tableId)) {
        mainStore.getRowIds(tableId).forEach(rowId => mainStore.delRow(tableId, rowId));
      }
    });
    await preferencesService.resetAllPreferences();
  }
};

// API Key service
export const apiKeyService = {
  async saveApiKey(provider: string, key: string): Promise<void> {
    await ensureDatabaseReady();
    const now = Date.now();
    mainStore.setRow('apiKeys', provider, {
      id: provider,
      provider,
      key,
      createdAt: now,
      updatedAt: now,
    });
  },

  async getApiKey(provider: string): Promise<string | null> {
    await ensureDatabaseReady();
    const key = mainStore.getCell('apiKeys', provider, 'key');
    return key ? (key as string) : null;
  },

  async getAllApiKeys(): Promise<Record<string, string>> {
    await ensureDatabaseReady();
    const keys: Record<string, string> = {};
    mainStore.forEachRow('apiKeys', (rowId) => {
      const provider = mainStore.getCell('apiKeys', rowId, 'provider') as string;
      const key = mainStore.getCell('apiKeys', rowId, 'key') as string;
      keys[provider] = key;
    });
    return keys;
  },

  async deleteApiKey(provider: string): Promise<void> {
    await ensureDatabaseReady();
    mainStore.delRow('apiKeys', provider);
  },

  async hasApiKey(provider: string): Promise<boolean> {
    const key = await this.getApiKey(provider);
    return key !== null && key.trim() !== '';
  }
};

// Image service
export const imageService = {
  async storeImage(
    imageDataUrl: string,
    source: 'generated' | 'uploaded' | 'edited' | 'unsplash' = 'generated',
    metadata?: { width?: number; height?: number; tags?: string[] }
  ): Promise<string> {
    const imageId = createImageId();

    // Extract MIME type from data URL
    const mimeMatch = imageDataUrl.match(/^data:([^;]+);base64,/);
    const mimeType = mimeMatch ? mimeMatch[1] : 'image/png';

    // Calculate approximate size
    const base64Data = imageDataUrl.split(',')[1] || '';
    const approximateSize = Math.floor(base64Data.length * 0.75);

    mainStore.setRow('images', imageId, {
      id: imageId,
      imageData: imageDataUrl,
      mimeType,
      size: approximateSize,
      createdAt: Date.now(),
      source,
      width: metadata?.width || 0,
      height: metadata?.height || 0,
      tags: JSON.stringify(metadata?.tags || []),
    });

    return imageId;
  },

  async getImage(imageId: string): Promise<string | null> {
    const imageData = mainStore.getCell('images', imageId, 'imageData');
    return imageData ? (imageData as string) : null;
  },

  async getImageMetadata(imageId: string): Promise<Omit<StoredImage, 'imageData'> | null> {
    if (!mainStore.hasRow('images', imageId)) return null;

    return {
      id: mainStore.getCell('images', imageId, 'id') as string,
      mimeType: mainStore.getCell('images', imageId, 'mimeType') as string,
      size: mainStore.getCell('images', imageId, 'size') as number,
      createdAt: new Date(mainStore.getCell('images', imageId, 'createdAt') as number),
      width: mainStore.getCell('images', imageId, 'width') as number,
      height: mainStore.getCell('images', imageId, 'height') as number,
      source: mainStore.getCell('images', imageId, 'source') as StoredImage['source'],
      tags: JSON.parse(mainStore.getCell('images', imageId, 'tags') as string),
    };
  },

  async deleteImage(imageId: string): Promise<void> {
    mainStore.delRow('images', imageId);
  },

  async cleanupOrphanedImages(nodeImageIds: string[]): Promise<number> {
    let deletedCount = 0;
    const imagesToDelete: string[] = [];
    
    mainStore.forEachRow('images', (rowId) => {
      if (!nodeImageIds.includes(rowId)) {
        imagesToDelete.push(rowId);
      }
    });

    imagesToDelete.forEach(imageId => {
      mainStore.delRow('images', imageId);
      deletedCount++;
    });

    return deletedCount;
  },

  async getStorageStats(): Promise<{ count: number, totalSize: number }> {
    let count = 0;
    let totalSize = 0;
    
    mainStore.forEachRow('images', (rowId) => {
      count++;
      totalSize += (mainStore.getCell('images', rowId, 'size') as number) || 0;
    });

    return { count, totalSize };
  }
};

// Preferences service
export const preferencesService = {
  async setTutorialDismissed(dismissed: boolean): Promise<void> {
    await ensureDatabaseReady();
    mainStore.setValue('tutorialDismissed', dismissed);
  },

  async getTutorialDismissed(): Promise<boolean> {
    await ensureDatabaseReady();
    return mainStore.getValue('tutorialDismissed') as boolean;
  },

  async isTutorialDismissed(): Promise<boolean> {
    return this.getTutorialDismissed();
  },

  async resetAllPreferences(): Promise<void> {
    await ensureDatabaseReady();
    mainStore.setValue('tutorialDismissed', false);
  }
};

// Export the store for use in React components
export const store = mainStore;
export const indexes = mainIndexes;
export const persister = mainPersister;
