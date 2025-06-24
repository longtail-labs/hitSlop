import { useCallback } from 'react';
import { useReactFlow, Node } from '@xyflow/react';

// Define standard node dimensions for collision detection
const NODE_DIMENSIONS: Record<string, { width: number; height: number }> = {
  'prompt-node': { width: 300, height: 250 },
  'image-node': { width: 300, height: 300 },
  'annotation-node': { width: 250, height: 100 },
};

export function useNodePlacement() {
  const { getIntersectingNodes } = useReactFlow();

  const findNonOverlappingPosition = useCallback(
    (initialPosition: { x: number; y: number }, nodeType: string) => {
      const dimensions = NODE_DIMENSIONS[nodeType] || {
        width: 200,
        height: 200,
      };

      let position = { ...initialPosition };
      const tempNode: Node = {
        id: 'temp',
        type: nodeType,
        position,
        data: {},
        width: dimensions.width,
        height: dimensions.height,
      };

      // Check if the position causes overlap
      let intersections = getIntersectingNodes(tempNode);

      // If there are intersections, try to find a better position
      if (intersections.length > 0) {
        // Try different positions in a spiral pattern
        const spiralStep = Math.max(dimensions.width, dimensions.height) + 50; // Use node size + padding
        let attempts = 0;
        let angle = 0;
        let radius = spiralStep;
        const maxAttempts = 50;

        while (intersections.length > 0 && attempts < maxAttempts) {
          // Move in a spiral pattern
          angle += 0.5;
          radius = spiralStep * (1 + angle / (2 * Math.PI)); // Spiral out

          position = {
            x: initialPosition.x + radius * Math.cos(angle),
            y: initialPosition.y + radius * Math.sin(angle),
          };

          tempNode.position = position;
          intersections = getIntersectingNodes(tempNode);
          attempts++;
        }
      }

      // Snap to a grid
      const gridSize = 20;
      position.x = Math.round(position.x / gridSize) * gridSize;
      position.y = Math.round(position.y / gridSize) * gridSize;

      return position;
    },
    [getIntersectingNodes],
  );

  // Helper function for placing multiple nodes with proper spacing
  const findPositionsForMultipleNodes = useCallback(
    (
      basePosition: { x: number; y: number },
      nodeType: string,
      count: number,
    ) => {
      const dimensions = NODE_DIMENSIONS[nodeType] || {
        width: 200,
        height: 200,
      };
      
      const positions: { x: number; y: number }[] = [];
      const padding = 30; // Space between nodes
      const nodeSpacing = dimensions.width + padding;

      for (let i = 0; i < count; i++) {
        let candidatePosition;
        
        if (count === 1) {
          // Single node - use base position
          candidatePosition = basePosition;
        } else if (count <= 3) {
          // Small number - arrange horizontally
          candidatePosition = {
            x: basePosition.x + (i * nodeSpacing),
            y: basePosition.y,
          };
        } else {
          // Larger number - arrange in a grid
          const cols = Math.ceil(Math.sqrt(count));
          const row = Math.floor(i / cols);
          const col = i % cols;
          
          candidatePosition = {
            x: basePosition.x + (col * nodeSpacing),
            y: basePosition.y + (row * (dimensions.height + padding)),
          };
        }

        // Find non-overlapping position for this specific node
        const finalPosition = findNonOverlappingPosition(candidatePosition, nodeType);
        positions.push(finalPosition);
      }

      return positions;
    },
    [findNonOverlappingPosition],
  );

  return { findNonOverlappingPosition, findPositionsForMultipleNodes };
} 