import Dexie, { Table } from 'dexie';
import { Node, Edge } from '@xyflow/react';
import { createImageId } from '@/app/lib/utils';

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

export interface ApiKey {
  id: string;
  provider: string;
  key: string;
  createdAt: Date;
  updatedAt: Date;
}

// New interface for user preferences
export interface UserPreference {
  id: string;
  key: string;
  value: any;
  updatedAt: Date;
}

// New interface for optimized image storage
export interface StoredImage {
  id: string;
  imageData: string; // Base64 data URL - stored but NOT indexed
  mimeType: string;
  size: number; // File size in bytes for reference
  createdAt: Date;
  // Optional metadata that CAN be indexed
  width?: number;
  height?: number;
  source?: 'generated' | 'uploaded' | 'edited' | 'unsplash' | 'pexels';
  tags?: string[]; // For AI-analyzed tags if we add that feature later
}

export class FlowDatabase extends Dexie {
  nodes!: Table<PersistedNode>;
  edges!: Table<PersistedEdge>;
  apiKeys!: Table<ApiKey>;
  images!: Table<StoredImage>;
  preferences!: Table<UserPreference>;

  constructor() {
    super('FlowDatabase');
    // Increment version to 4 to add the preferences table
    this.version(4).stores({
      nodes: 'id, type, position, data, selectable',
      edges: 'id, source, target, sourceHandle, targetHandle',
      apiKeys: 'id, provider, key, createdAt, updatedAt',
      // Images table: only index metadata, NOT the imageData itself
      images: 'id, mimeType, size, createdAt, width, height, source, *tags',
      preferences: 'id, key, value, updatedAt'
    });
  }
}

export const db = new FlowDatabase();

export const persistenceService = {
  async saveNodes(nodes: Node[]) {
    await db.nodes.clear();
    await db.nodes.bulkPut(nodes as PersistedNode[]);
  },

  async saveEdges(edges: Edge[]) {
    await db.edges.clear();
    await db.edges.bulkPut(edges as PersistedEdge[]);
  },

  async loadNodes(): Promise<PersistedNode[]> {
    return await db.nodes.toArray();
  },

  async loadEdges(): Promise<PersistedEdge[]> {
    return await db.edges.toArray();
  },

  async clearAll() {
    await db.nodes.clear();
    await db.edges.clear();
    await db.preferences.clear();
  }
};

export const apiKeyService = {
  async saveApiKey(provider: string, key: string): Promise<void> {
    const now = new Date();
    const apiKey: ApiKey = {
      id: provider,
      provider,
      key,
      createdAt: now,
      updatedAt: now
    };
    await db.apiKeys.put(apiKey);
  },

  async getApiKey(provider: string): Promise<string | null> {
    const apiKey = await db.apiKeys.get(provider);
    return apiKey?.key || null;
  },

  async getAllApiKeys(): Promise<Record<string, string>> {
    const keys = await db.apiKeys.toArray();
    return keys.reduce((acc, key) => {
      acc[key.provider] = key.key;
      return acc;
    }, {} as Record<string, string>);
  },

  async deleteApiKey(provider: string): Promise<void> {
    await db.apiKeys.delete(provider);
  },

  async hasApiKey(provider: string): Promise<boolean> {
    const key = await this.getApiKey(provider);
    return key !== null && key.trim() !== '';
  }
};

// New optimized image service
export const imageService = {
  /**
   * Store an image and return its ID
   * @param imageDataUrl Base64 data URL of the image
   * @param source Source of the image (generated, uploaded, edited)
   * @param metadata Optional metadata like dimensions
   * @returns Promise<string> The image ID
   */
  async storeImage(
    imageDataUrl: string,
    source: 'generated' | 'uploaded' | 'edited' | 'unsplash' | 'pexels' = 'generated',
    metadata?: { width?: number; height?: number; tags?: string[] }
  ): Promise<string> {
    const imageId = createImageId();

    // Extract MIME type from data URL
    const mimeMatch = imageDataUrl.match(/^data:([^;]+);base64,/);
    const mimeType = mimeMatch ? mimeMatch[1] : 'image/png';

    // Calculate approximate size (base64 is ~33% larger than binary)
    const base64Data = imageDataUrl.split(',')[1] || '';
    const approximateSize = Math.floor(base64Data.length * 0.75);

    const storedImage: StoredImage = {
      id: imageId,
      imageData: imageDataUrl,
      mimeType,
      size: approximateSize,
      createdAt: new Date(),
      source,
      ...metadata
    };

    await db.images.put(storedImage);
    return imageId;
  },

  /**
   * Retrieve an image by its ID
   * @param imageId The image ID
   * @returns Promise<string | null> The image data URL or null if not found
   */
  async getImage(imageId: string): Promise<string | null> {
    const storedImage = await db.images.get(imageId);
    return storedImage?.imageData || null;
  },

  /**
   * Retrieve image metadata without the binary data
   * @param imageId The image ID
   * @returns Promise<Omit<StoredImage, 'imageData'> | null>
   */
  async getImageMetadata(imageId: string): Promise<Omit<StoredImage, 'imageData'> | null> {
    const storedImage = await db.images.get(imageId);
    if (!storedImage) return null;

    const metadata = Object.fromEntries(
      Object.entries(storedImage).filter(([key]) => key !== 'imageData')
    ) as Omit<StoredImage, 'imageData'>;
    return metadata;
  },

  /**
   * Delete an image by its ID
   * @param imageId The image ID
   * @returns Promise<void>
   */
  async deleteImage(imageId: string): Promise<void> {
    await db.images.delete(imageId);
  },

  /**
   * Get all image metadata (useful for debugging/management)
   * @returns Promise<Omit<StoredImage, 'imageData'>[]>
   */
  async getAllImageMetadata(): Promise<Omit<StoredImage, 'imageData'>[]> {
    const images = await db.images.toArray();
    return images.map(img => {
      const metadata = Object.fromEntries(
        Object.entries(img).filter(([key]) => key !== 'imageData')
      ) as Omit<StoredImage, 'imageData'>;
      return metadata;
    });
  },

  /**
   * Clean up orphaned images (images not referenced by any nodes)
   * @param nodeImageIds Array of image IDs currently referenced by nodes
   * @returns Promise<number> Number of images deleted
   */
  async cleanupOrphanedImages(nodeImageIds: string[]): Promise<number> {
    const allImages = await db.images.toArray();
    const orphanedImages = allImages.filter(img => !nodeImageIds.includes(img.id));

    for (const orphanedImage of orphanedImages) {
      await db.images.delete(orphanedImage.id);
    }

    return orphanedImages.length;
  },

  /**
   * Get total storage usage of images
   * @returns Promise<{count: number, totalSize: number}>
   */
  async getStorageStats(): Promise<{ count: number, totalSize: number }> {
    const images = await db.images.toArray();
    const totalSize = images.reduce((sum, img) => sum + (img.size || 0), 0);
    return {
      count: images.length,
      totalSize
    };
  }
};

// User preferences service
export const preferencesService = {
  async setPreference(key: string, value: any): Promise<void> {
    const preference: UserPreference = {
      id: key,
      key,
      value,
      updatedAt: new Date()
    };
    await db.preferences.put(preference);
  },

  async getPreference(key: string, defaultValue: any = null): Promise<any> {
    const preference = await db.preferences.get(key);
    return preference ? preference.value : defaultValue;
  },

  async hasPreference(key: string): Promise<boolean> {
    const preference = await db.preferences.get(key);
    return preference !== undefined;
  },

  async deletePreference(key: string): Promise<void> {
    await db.preferences.delete(key);
  }
};
