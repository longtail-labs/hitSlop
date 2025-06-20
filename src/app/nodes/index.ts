import type { NodeTypes } from '@xyflow/react';
import { PromptNode } from './PromptNode';
import { ImageNode } from './ImageNode';
import { AppNode } from './types';

export const initialNodes: AppNode[] = [
  {
    id: 'd',
    type: 'prompt-node',
    position: { x: 0, y: 200 },
    data: { prompt: '' },
    selectable: false,
  },
];

export const nodeTypes = {
  'prompt-node': PromptNode,
  'image-node': ImageNode,
  // Add any of your custom nodes here!
} satisfies NodeTypes;
