declare module 'react' {
  export const useState: any;
  export const useEffect: any;
  export const useRef: any;
  export const useCallback: any;
  const React: any;
  export default React;
  export namespace React {}
}

declare namespace JSX {
  interface IntrinsicElements {
    [elem: string]: any;
  }
}

declare module 'react/jsx-runtime' {
  export const jsx: any;
  export const jsxs: any;
  export const Fragment: any;
}

declare module '@xyflow/react' {
  export const ReactFlow: any;
  export const Background: any;
  export const Controls: any;
  export const MiniMap: any;
  export function addEdge(...args: any[]): any;
  export function useNodesState<T = any>(
    initialNodes?: T[],
  ): [T[], (nds: T[]) => void, any];
  export function useEdgesState<T = any>(
    initialEdges?: T[],
  ): [T[], (eds: T[]) => void, any];
  export const Panel: any;
  export const useReactFlow: any;
  export const ReactFlowProvider: any;
  export const SelectionMode: any;
  export type NodeTypes = any;
  export type OnConnect = any;
  export type OnSelectionChangeParams = any;
  export type Node<T = any, U = any> = any;
  export type BuiltInNode = any;
}
declare module 'lucide-react';
declare module '@radix-ui/react-slot';
declare module 'openai';
declare module 'react-dom';
