import type { Node, BuiltInNode } from '@xyflow/react';
import { ModelConfig, MODEL_CONFIGS } from '../services/models/modelConfig';

export type ModelId = keyof typeof MODEL_CONFIGS;

// New type for storable generation parameters
export interface SerializableGenerationParams {
  prompt: string;
  model?: ModelId;
  size?: string;
  n?: number;
  sourceImages?: string[]; // These will now be image IDs instead of data URLs
  maskImage?: string | null; // This will now be an image ID instead of data URL
  // Include other known serializable parameters from ModelConfig's 'parameters' array
  // For example, if 'quality', 'background', 'aspectRatio' are common model params:
  quality?: string;
  background?: string;
  moderation?: string;
  style?: string;
  aspectRatio?: string;
  // personGeneration is google specific, but if we want to store it:
  personGeneration?: string;
  // Add other potential params here if they should be stored
  // Or use a more generic approach if the list is too long/dynamic:
  // [key: string]: any; // Use with caution, prefer explicit properties
}

export type PositionLoggerNode = Node<{ label: string }, 'position-logger'>;
export type PromptNodeData = {
  prompt?: string;
  model?: ModelId; // Updated to ModelId
  size?: string;
  n?: number;
  // Removed quality, outputFormat, moderation, background, aspectRatio, personGeneration
  // These are now expected to be part of the 'modelParams' state in PromptNode
  // and then captured in 'SerializableGenerationParams' for ImageNodeData.
  onPromptChange?: (_prompt: string) => void; // This seems like a prop, not stored data.
  sourceImages?: string[]; // These will now be image IDs instead of data URLs
  maskImage?: string | null; // This will now be an image ID instead of data URL
  // [key: string]: any; // Removed, let PromptNode manage dynamic params in its state.
};
export type PromptNode = Node<PromptNodeData, 'prompt-node'>;

export type ImageNodeData = {
  // New optimized storage: store image ID instead of full data URL
  imageId?: string;
  // Keep imageUrl for backward compatibility during transition, but prefer imageId
  imageUrl?: string; // @deprecated - use imageId instead
  prompt?: string; // The original prompt that led to this image
  generationParams?: SerializableGenerationParams; // Updated to SerializableGenerationParams
  isLoading?: boolean;
  error?: string;
  isEdited?: boolean;
  revisedPrompt?: string;
  isStreaming?: boolean;
  partialImageUrl?: string;
  streamingProgress?: string;
  modelConfig?: ModelConfig; // This is good, provides full context of the model used
  // [key: string]: any; // Removed
};
export type ImageNode = Node<ImageNodeData, 'image-node'>;

export type AppNode = BuiltInNode | PositionLoggerNode | PromptNode | ImageNode;
