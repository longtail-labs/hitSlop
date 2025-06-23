import { useState, useCallback, useRef, useEffect, SetStateAction } from 'react';
import {
  useNodesState,
  useEdgesState,
  Node,
  Edge,
  NodeChange,
  EdgeChange,
  useReactFlow,
} from '@xyflow/react';
import { persistenceService } from '../services/database';
import debounce from 'lodash.debounce';

export function useIsMobile() {
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const userAgent =
      typeof window.navigator === 'undefined' ? '' : navigator.userAgent;
    const mobile =
      /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
        userAgent,
      );
    setIsMobile(mobile);
  }, []);

  return isMobile;
}

export function usePersistedNodes<NodeType extends Node = Node>(
  initialNodes: NodeType[] = [],
) {
  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes);
  const [isLoaded, setIsLoaded] = useState(false);
  const nodesRef = useRef(nodes);
  nodesRef.current = nodes;

  const debouncedSave = useRef(
    debounce((changes: NodeChange[]) => {
      try {
        persistenceService.applyNodeChanges(changes);
      } catch (error) {
        console.error('❌ Error applying node changes:', error);
      }
    }, 150),
  ).current;

  const debouncedFullSave = useRef(
    debounce((nodes: NodeType[]) => {
      try {
        persistenceService.saveNodes(nodes);
      } catch (error) {
        console.error('❌ Error in full node save:', error);
      }
    }, 300),
  ).current;

  useEffect(() => {
    const load = async () => {
      try {
        const persistedNodes = await persistenceService.loadNodes();
        if (persistedNodes.length > 0) {
          setNodes(persistedNodes as NodeType[]);
        } else {
          setNodes(initialNodes);
        }
        setIsLoaded(true);
      } catch (error) {
        console.error('❌ Error loading nodes:', error);
        setNodes(initialNodes);
        setIsLoaded(true);
      }
    };
    load();
  }, [setNodes, initialNodes]);

  useEffect(() => {
    if (isLoaded && nodes.length > 0) {
      debouncedFullSave(nodes);
    }
  }, [nodes, isLoaded, debouncedFullSave]);

  const handleNodesChange = useCallback(
    (changes: NodeChange<NodeType>[]) => {
      onNodesChange(changes);
      if (isLoaded) {
        debouncedSave(changes as NodeChange[]);
      }
    },
    [onNodesChange, isLoaded, debouncedSave],
  );

  const handleSetNodes = useCallback(
    (nodesArg: SetStateAction<NodeType[]>) => {
      setNodes(nodesArg);
      if (isLoaded) {
        const newNodes =
          typeof nodesArg === 'function'
            ? nodesArg(nodesRef.current)
            : nodesArg;
        persistenceService.saveNodes(newNodes);
      }
    },
    [setNodes, isLoaded],
  );

  return [nodes, handleSetNodes, handleNodesChange, isLoaded] as const;
}

export function usePersistedEdges<EdgeType extends Edge = Edge>(
  initialEdges: EdgeType[] = [],
) {
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges);
  const [isLoaded, setIsLoaded] = useState(false);
  const edgesRef = useRef(edges);
  edgesRef.current = edges;

  const debouncedSave = useRef(
    debounce((changes: EdgeChange[]) => {
      try {
        persistenceService.applyEdgeChanges(changes);
      } catch (error) {
        console.error('❌ Error applying edge changes:', error);
      }
    }, 150),
  ).current;

  const debouncedFullSave = useRef(
    debounce((edges: EdgeType[]) => {
      try {
        persistenceService.saveEdges(edges);
      } catch (error) {
        console.error('❌ Error in full edge save:', error);
      }
    }, 300),
  ).current;

  useEffect(() => {
    const load = async () => {
      try {
        const persistedEdges = await persistenceService.loadEdges();
        if (persistedEdges.length > 0) {
          setEdges(persistedEdges as EdgeType[]);
        } else {
          setEdges(initialEdges);
        }
        setIsLoaded(true);
      } catch (error) {
        console.error('❌ Error loading edges:', error);
        setEdges(initialEdges);
        setIsLoaded(true);
      }
    };
    load();
  }, [setEdges, initialEdges]);

  useEffect(() => {
    if (isLoaded && edges.length >= 0) {
      debouncedFullSave(edges);
    }
  }, [edges, isLoaded, debouncedFullSave]);

  const handleEdgesChange = useCallback(
    (changes: EdgeChange<EdgeType>[]) => {
      onEdgesChange(changes);
      if (isLoaded) {
        debouncedSave(changes as EdgeChange[]);
      }
    },
    [onEdgesChange, isLoaded, debouncedSave],
  );

  const handleSetEdges = useCallback(
    (edgesArg: SetStateAction<EdgeType[]>) => {
      setEdges(edgesArg);
      if (isLoaded) {
        const newEdges =
          typeof edgesArg === 'function'
            ? edgesArg(edgesRef.current)
            : edgesArg;
        persistenceService.saveEdges(newEdges);
      }
    },
    [setEdges, isLoaded],
  );

  return [edges, handleSetEdges, handleEdgesChange, isLoaded] as const;
}

export function usePersistedFlow<NodeType extends Node = Node, EdgeType extends Edge = Edge>(
  initialNodes: NodeType[] = [],
  initialEdges: EdgeType[] = [],
) {
  const { fitView } = useReactFlow();
  const [nodes, setNodes, onNodesChange, nodesLoaded] = usePersistedNodes(initialNodes);
  const [edges, setEdges, onEdgesChange, edgesLoaded] = usePersistedEdges(initialEdges);
  
  const isLoaded = nodesLoaded && edgesLoaded;
  const hasFitView = useRef(false);

  useEffect(() => {
    if (isLoaded && !hasFitView.current && nodes.length > 0) {
      setTimeout(() => {
        fitView({
          duration: 800,
          padding: 0.1,
          maxZoom: 1,
          minZoom: 0.1,
        });
        hasFitView.current = true;
      }, 100);
    }
  }, [isLoaded, nodes.length, fitView]);

  return {
    nodes,
    edges,
    setNodes,
    setEdges,
    onNodesChange,
    onEdgesChange,
    isLoaded,
  };
} 