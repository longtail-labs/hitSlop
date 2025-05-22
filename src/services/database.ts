import Dexie, { Table } from 'dexie';
import { Node, Edge } from '@xyflow/react';

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

export class FlowDatabase extends Dexie {
  nodes!: Table<PersistedNode>;
  edges!: Table<PersistedEdge>;
  apiKeys!: Table<ApiKey>;

  constructor() {
    super('FlowDatabase');
    this.version(2).stores({
      nodes: 'id, type, position, data, selectable',
      edges: 'id, source, target, sourceHandle, targetHandle',
      apiKeys: 'id, provider, key, createdAt, updatedAt'
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