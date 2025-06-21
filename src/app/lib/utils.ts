import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';
import { nanoid } from 'nanoid';
import {
  ImageNode,
  ImageNodeData,
  LoadingImageNodeData,
} from '@/app/nodes/types';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/**
 * Generate a unique node ID with a specific prefix
 * @param prefix The prefix for the ID (e.g., 'image-node', 'prompt-node')
 * @param length Optional length for the nanoid (default: 12)
 * @returns A unique ID with the format: prefix-nanoid
 */
export function createNodeId(prefix: string = 'node'): string {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

/**
 * Generate a unique image ID for database storage
 * @param length Optional length for the nanoid (default: 12)
 * @returns A unique ID with the format: img_nanoid
 */
export function createImageId(): string {
  return `img-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

/**
 * Generate a unique edge ID for connecting nodes
 * @param sourceId The source node ID
 * @param targetId The target node ID
 * @returns A unique edge ID with the format: edge-sourceId-to-targetId
 */
export function createEdgeId(source: string, target: string): string {
  return `edge-${source}-${target}-${Date.now()}`;
}

/**
 * Generate a simple unique ID using nanoid
 * @param length Optional length for the nanoid (default: 12)
 * @returns A unique nanoid string
 */
export function createId(length: number = 12): string {
  return nanoid(length);
}

/**
 * Centralized helper to create image nodes consistently.
 * This is now a synchronous function that assumes the image ID is already known.
 */
export function createImageNode(
  imageId: string,
  options: Omit<ImageNodeData, 'imageId'> & { position: { x: number; y: number } }
): ImageNode {
  const nodeId = createNodeId('image-node');
  const { position, ...data } = options;

  const nodeData: ImageNodeData = {
    imageId,
    ...data,
  } as ImageNodeData;

  return {
    id: nodeId,
    type: 'image-node',
    position: position,
    data: nodeData,
    selectable: true,
  };
}

/**
 * Create a loading placeholder image node, which is a specific type of ImageNode.
 */
export function createLoadingImageNode(
  position: { x: number; y: number },
  prompt?: string
): ImageNode {
  const nodeId = createNodeId('image-node');

  const nodeData: LoadingImageNodeData = {
    source: 'generated', // Loading nodes are always for generated images
    isLoading: true,
    prompt: prompt,
  };

  return {
    id: nodeId,
    type: 'image-node',
    position,
    data: nodeData,
    selectable: true,
  };
}