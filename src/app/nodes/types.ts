import type { Node, BuiltInNode } from '@xyflow/react';
import { ModelConfig, MODEL_CONFIGS } from '../services/models/modelConfig';

export type ModelId = keyof typeof MODEL_CONFIGS;

// Base for all image nodes
export interface BaseImageNodeData {
  imageId?: string;
  isLoading?: boolean;
  error?: string;
  [key:string]: any;
}

// For images uploaded by the user
export interface LocalImageNodeData extends BaseImageNodeData {
  source: 'uploaded';
}
export type LocalImageNode = Node<LocalImageNodeData, 'image-node'>;

// For images from Unsplash
export interface UnsplashImageNodeData extends BaseImageNodeData {
  source: 'unsplash';
  prompt?: string;
  photographer: string;
  photographer_url: string;
  alt?: string;
  attribution: {
    service: 'Unsplash';
    serviceUrl: 'https://unsplash.com';
    creator: string;
    creatorUrl: string;
    photoUrl: string;
  };
}
export type UnsplashImageNode = Node<UnsplashImageNodeData, 'image-node'>;

// Base for all generated/edited images
interface BaseGeneratedImageNodeData extends BaseImageNodeData {
  source: 'generated' | 'edited';
  prompt: string;
  isEdited: boolean;
  revisedPrompt?: string;
  modelConfig: ModelConfig;
  // Streaming-related fields
  isStreaming?: boolean;
  partialImageUrl?: string;
  streamingProgress?: string;
}

// --- Generation Parameter Types ---

export interface BaseGenerationParams {
  prompt: string;
  model: ModelId;
  n?: number;
  sourceImages?: string[]; // image IDs
  maskImage?: string | null; // image ID
}

export interface OpenAIGenerationParams extends BaseGenerationParams {
  size?: string;
  quality?: string;
  style?: string;
  background?: string; // Custom param
}

export interface GeminiGenerationParams extends BaseGenerationParams {
  size?: string;
  aspectRatio?: string;
  personGeneration?: string;
}

export interface FalGenerationParams extends BaseGenerationParams {
  guidance_scale?: number;
  seed?: number;
  aspect_ratio?: string;
}

export type SerializableGenerationParams =
  | OpenAIGenerationParams
  | GeminiGenerationParams
  | FalGenerationParams;

// --- Specific Generated Image Node Data Types ---

export interface OpenAIGeneratedImageNodeData extends BaseGeneratedImageNodeData {
  generationParams: OpenAIGenerationParams;
}
export type OpenAIGeneratedImageNode = Node<
  OpenAIGeneratedImageNodeData,
  'image-node'
>;

export interface GeminiGeneratedImageNodeData extends BaseGeneratedImageNodeData {
  generationParams: GeminiGenerationParams;
}
export type GeminiGeneratedImageNode = Node<
  GeminiGeneratedImageNodeData,
  'image-node'
>;

export interface FalGeneratedImageNodeData extends BaseGeneratedImageNodeData {
  generationParams: FalGenerationParams;
}
export type FalGeneratedImageNode = Node<
  FalGeneratedImageNodeData,
  'image-node'
>;

// Union of all generated image data types
export type GeneratedImageNodeData =
  | OpenAIGeneratedImageNodeData
  | GeminiGeneratedImageNodeData
  | FalGeneratedImageNodeData;
export type GeneratedImageNode = Node<GeneratedImageNodeData, 'image-node'>;

// A specific type for the temporary loading state
export interface LoadingImageNodeData extends BaseImageNodeData {
  source: 'generated' | 'edited';
  isLoading: true;
  prompt?: string;
}
export type LoadingImageNode = Node<LoadingImageNodeData, 'image-node'>;

// The main ImageNodeData is a union of all specific image types
export type ImageNodeData =
  | LocalImageNodeData
  | UnsplashImageNodeData
  | GeneratedImageNodeData
  | LoadingImageNodeData;
export type ImageNode = Node<ImageNodeData, 'image-node'>;

// --- Prompt Node ---
export interface PromptNodeData {
  prompt?: string;
  model?: ModelId;
  sourceImages?: string[]; // Image IDs
  // No other dynamic params needed here; they are managed inside PromptNode state
  [key: string]: any;
}
export type PromptNode = Node<PromptNodeData, 'prompt-node'>;

// --- App Node ---
export type AppNode = BuiltInNode | PromptNode | ImageNode;
