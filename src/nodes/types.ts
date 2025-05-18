import type { Node, BuiltInNode } from '@xyflow/react';

export type PositionLoggerNode = Node<{ label: string }, 'position-logger'>;
export type PromptNodeData = {
  prompt?: string;
  model?: 'gpt-image-1';
  size?: '1024x1024' | '1536x1024' | '1024x1536' | 'auto';
  n?: number;
  quality?: 'auto' | 'high' | 'medium' | 'low';
  outputFormat?: 'png' | 'jpeg' | 'webp';
  moderation?: 'auto' | 'low';
  background?: 'auto' | 'transparent' | 'opaque';
  onPromptChange?: (prompt: string) => void;
  sourceImages?: string[];
  maskImage?: string | null;
};
export type PromptNode = Node<PromptNodeData, 'prompt-node'>;

export type ImageNodeData = {
  imageUrl?: string;
  prompt?: string;
  generationParams?: Record<string, any>;
  isLoading?: boolean;
  error?: string;
  isEdited?: boolean;
};
export type ImageNode = Node<ImageNodeData, 'image-node'>;

export type AnnotationNode = Node<Record<string, never>, 'annotation-node'>;

export type AppNode =
  | BuiltInNode
  | PositionLoggerNode
  | PromptNode
  | ImageNode
  | AnnotationNode;
