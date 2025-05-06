import type { Node, BuiltInNode } from '@xyflow/react';

export type PositionLoggerNode = Node<{ label: string }, 'position-logger'>;
export type PromptNodeData = {
  prompt?: string;
  onPromptChange?: (prompt: string) => void;
};
export type PromptNode = Node<PromptNodeData, 'prompt-node'>;
export type AppNode = BuiltInNode | PositionLoggerNode | PromptNode;
