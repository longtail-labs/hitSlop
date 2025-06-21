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
      console.log('🔄 Debounced save - applying node changes:', changes);
      try {
        persistenceService.applyNodeChanges(changes);
        console.log('✅ Node changes applied successfully');
      } catch (error) {
        console.error('❌ Error applying node changes:', error);
      }
    }, 150),
  ).current;

  const debouncedFullSave = useRef(
    debounce((nodes: NodeType[]) => {
      console.log('🔄 Debounced full save - saving all nodes:', nodes.length);
      try {
        persistenceService.saveNodes(nodes);
        console.log('✅ Full node save completed');
      } catch (error) {
        console.error('❌ Error in full node save:', error);
      }
    }, 300),
  ).current;

  useEffect(() => {
    const load = async () => {
      console.log('📥 Loading persisted nodes...');
      try {
        const persistedNodes = await persistenceService.loadNodes();
        if (persistedNodes.length > 0) {
          console.log('✅ Loaded persisted nodes:', persistedNodes.length);
          setNodes(persistedNodes as NodeType[]);
        } else {
          console.log('📝 No persisted nodes, using initial nodes:', initialNodes.length);
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
      console.log('🔄 Nodes changed, triggering full save...');
      debouncedFullSave(nodes);
    }
  }, [nodes, isLoaded, debouncedFullSave]);

  const handleNodesChange = useCallback(
    (changes: NodeChange<NodeType>[]) => {
      console.log('🔄 Node changes received:', changes);
      onNodesChange(changes);
      if (isLoaded) {
        debouncedSave(changes as NodeChange[]);
      }
    },
    [onNodesChange, isLoaded, debouncedSave],
  );

  const handleSetNodes = useCallback(
    (nodesArg: SetStateAction<NodeType[]>) => {
      console.log('🔄 SetNodes called');
      setNodes(nodesArg);
      if (isLoaded) {
        const newNodes =
          typeof nodesArg === 'function'
            ? nodesArg(nodesRef.current)
            : nodesArg;
        console.log('💾 Immediate save for setNodes:', newNodes.length);
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
      console.log('🔄 Debounced save - applying edge changes:', changes);
      try {
        persistenceService.applyEdgeChanges(changes);
        console.log('✅ Edge changes applied successfully');
      } catch (error) {
        console.error('❌ Error applying edge changes:', error);
      }
    }, 150),
  ).current;

  const debouncedFullSave = useRef(
    debounce((edges: EdgeType[]) => {
      console.log('🔄 Debounced full save - saving all edges:', edges.length);
      try {
        persistenceService.saveEdges(edges);
        console.log('✅ Full edge save completed');
      } catch (error) {
        console.error('❌ Error in full edge save:', error);
      }
    }, 300),
  ).current;

  useEffect(() => {
    const load = async () => {
      console.log('📥 Loading persisted edges...');
      try {
        const persistedEdges = await persistenceService.loadEdges();
        if (persistedEdges.length > 0) {
          console.log('✅ Loaded persisted edges:', persistedEdges.length);
          setEdges(persistedEdges as EdgeType[]);
        } else {
          console.log('📝 No persisted edges, using initial edges:', initialEdges.length);
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
      console.log('🔄 Edges changed, triggering full save...');
      debouncedFullSave(edges);
    }
  }, [edges, isLoaded, debouncedFullSave]);

  const handleEdgesChange = useCallback(
    (changes: EdgeChange<EdgeType>[]) => {
      console.log('🔄 Edge changes received:', changes);
      onEdgesChange(changes);
      if (isLoaded) {
        debouncedSave(changes as EdgeChange[]);
      }
    },
    [onEdgesChange, isLoaded, debouncedSave],
  );

  const handleSetEdges = useCallback(
    (edgesArg: SetStateAction<EdgeType[]>) => {
      console.log('🔄 SetEdges called');
      setEdges(edgesArg);
      if (isLoaded) {
        const newEdges =
          typeof edgesArg === 'function'
            ? edgesArg(edgesRef.current)
            : edgesArg;
        console.log('💾 Immediate save for setEdges:', newEdges.length);
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
      console.log('🎯 Fitting view to show all content...');
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