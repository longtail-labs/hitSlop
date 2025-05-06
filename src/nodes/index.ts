import type { NodeTypes } from '@xyflow/react';

import { PositionLoggerNode } from './PositionLoggerNode';
import { PromptNode } from './PromptNode';
import { ImageNode } from './ImageNode';
import { AppNode } from './types';

export const initialNodes: AppNode[] = [
  { id: 'a', type: 'input', position: { x: 0, y: 0 }, data: { label: 'wire' } },
  {
    id: 'b',
    type: 'position-logger',
    position: { x: -100, y: 100 },
    data: { label: 'drag me!' },
  },
  { id: 'c', position: { x: 100, y: 100 }, data: { label: 'your ideas' } },
  {
    id: 'd',
    type: 'prompt-node',
    position: { x: 0, y: 200 },
    data: { prompt: '' },
  },
];

export const nodeTypes = {
  'position-logger': PositionLoggerNode,
  'prompt-node': PromptNode,
  'image-node': ImageNode,
  // Add any of your custom nodes here!
} satisfies NodeTypes;
