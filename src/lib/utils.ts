import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"
import { nanoid } from "nanoid"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

/**
 * Generate a unique node ID with a specific prefix
 * @param prefix The prefix for the ID (e.g., 'image-node', 'prompt-node')
 * @param length Optional length for the nanoid (default: 12)
 * @returns A unique ID with the format: prefix-nanoid
 */
export function createNodeId(prefix: string, length: number = 12): string {
  return `${prefix}-${nanoid(length)}`
}

/**
 * Generate a unique image ID for database storage
 * @param length Optional length for the nanoid (default: 12)
 * @returns A unique ID with the format: img_nanoid
 */
export function createImageId(length: number = 12): string {
  return `img_${nanoid(length)}`
}

/**
 * Generate a unique edge ID for connecting nodes
 * @param sourceId The source node ID
 * @param targetId The target node ID
 * @returns A unique edge ID with the format: edge-sourceId-to-targetId
 */
export function createEdgeId(sourceId: string, targetId: string): string {
  return `edge-${sourceId}-to-${targetId}`
}

/**
 * Generate a simple unique ID using nanoid
 * @param length Optional length for the nanoid (default: 12)
 * @returns A unique nanoid string
 */
export function createId(length: number = 12): string {
  return nanoid(length)
}
