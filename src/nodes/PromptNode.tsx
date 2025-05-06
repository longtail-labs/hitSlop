import { Handle, Position, type NodeProps, useReactFlow } from '@xyflow/react';
import { useCallback, useRef, useEffect, useState, KeyboardEvent } from 'react';
import { generateImage } from '../services/imageGenerationService';
import { AppNode, ImageNodeData } from './types';

export function PromptNode({ data, id }: NodeProps) {
  const reactFlowInstance = useReactFlow();
  const { deleteElements, addNodes, addEdges, setNodes, getNode } = reactFlowInstance;
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const [prompt, setPrompt] = useState<string>(data?.prompt as string || '');
  const [size, setSize] = useState<string>(data?.size as string || '1024x1024');
  const [n, setN] = useState<number>(data?.n as number || 1);
  const [quality, setQuality] = useState<string>(data?.quality as string || 'auto');
  const [outputFormat, setOutputFormat] = useState<string>(data?.outputFormat as string || 'png');
  const [moderation, setModeration] = useState<string>(data?.moderation as string || 'auto');
  const [background, setBackground] = useState<string>(data?.background as string || 'auto');
  const [showOptions, setShowOptions] = useState<boolean>(false);
  const [isGenerating, setIsGenerating] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  
  const handlePromptChange = useCallback((evt: React.ChangeEvent<HTMLTextAreaElement>) => {
    const newPrompt = evt.target.value;
    setPrompt(newPrompt);
    console.log('Prompt updated:', newPrompt);
    // If we had state management, we would update the node data here
  }, []);

  const handleDelete = useCallback(() => {
    deleteElements({ nodes: [{ id }] });
  }, [deleteElements, id]);

  const handleKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleGenerate();
    }
  };

  const handleGenerate = useCallback(async () => {
    if (!prompt.trim()) {
      setError('Please enter a prompt');
      return;
    }

    setIsGenerating(true);
    setError(null);

    try {
      // Get the position for the new node (below the current node)
      const currentNode = getNode(id);
      
      if (!currentNode) {
        throw new Error('Current node not found');
      }
      
      // Position the new node below the current one
      const newNodePosition = {
        x: currentNode.position.x,
        y: currentNode.position.y + 300, // Place it below with some spacing
      };

      // Create placeholder nodes for each image to be generated
      const loadingImageNodes: AppNode[] = [];
      const numImages = n;
      
      for (let i = 0; i < numImages; i++) {
        const imageNodeId = `image-node-${Date.now()}-${i}`;
        const offsetPosition = {
          x: newNodePosition.x + (i * 50), // Stagger horizontally
          y: newNodePosition.y + (i * 50)  // Stagger vertically
        };
        
        const loadingImageNode: AppNode = {
          id: imageNodeId,
          type: 'image-node',
          position: offsetPosition,
          data: {
            isLoading: true,
            prompt: prompt,
          }
        };
        
        loadingImageNodes.push(loadingImageNode);
        
        // Add the loading node to the flow
        addNodes(loadingImageNode);
        
        // Create an edge connecting the prompt node to each image node
        addEdges({
          id: `edge-${id}-to-${imageNodeId}`,
          source: id,
          target: imageNodeId,
          sourceHandle: 'output',
          targetHandle: 'input',
        });
      }

      // Generate the image(s)
      const params = {
        prompt,
        model: 'gpt-image-1' as const,
        size: size as any,
        n,
        quality: quality as any,
        outputFormat: outputFormat as any,
        moderation: moderation as any,
        background: background as any,
      };

      console.log('Generating image with parameters:', params);
      
      try {
        // Call the OpenAI API
        const result = await generateImage(params, newNodePosition);

        if (result.success && result.nodes && result.nodes.length > 0) {
          // Update each loading node with the corresponding generated image
          setNodes((nodes) => 
            nodes.map((node) => {
              // Find the corresponding result node for this loading node
              const resultNodeIndex = loadingImageNodes.findIndex(
                (loadingNode) => loadingNode.id === node.id
              );
              
              if (resultNodeIndex !== -1 && result.nodes && resultNodeIndex < result.nodes.length) {
                // Replace loading node with the generated image node data
                const resultNode = result.nodes[resultNodeIndex];
                const imageData = resultNode.data as ImageNodeData;
                
                return {
                  ...node,
                  data: {
                    ...node.data,
                    isLoading: false,
                    imageUrl: imageData.imageUrl,
                    generationParams: params
                  }
                };
              }
              return node;
            })
          );
        } else if (result.error) {
          // Update all loading nodes to show the error
          setNodes((nodes) => 
            nodes.map((node) => {
              if (loadingImageNodes.some(loadingNode => loadingNode.id === node.id)) {
                return {
                  ...node,
                  data: {
                    ...node.data,
                    isLoading: false,
                    error: result.error
                  }
                };
              }
              return node;
            })
          );
          setError(result.error);
        }
      } catch (err) {
        console.error('Error during image generation:', err);
        const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred';
        
        // Update all loading nodes to show the error
        setNodes((nodes) => 
          nodes.map((node) => {
            if (loadingImageNodes.some(loadingNode => loadingNode.id === node.id)) {
              return {
                ...node,
                data: {
                  ...node.data,
                  isLoading: false,
                  error: errorMessage
                }
              };
            }
            return node;
          })
        );
        
        setError(errorMessage);
      }
    } catch (err) {
      console.error('Error setting up image generation:', err);
      const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred';
      setError(errorMessage);
    } finally {
      setIsGenerating(false);
    }
  }, [prompt, size, n, quality, outputFormat, moderation, background, addNodes, addEdges, setNodes, getNode, id]);

  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
      textareaRef.current.style.height = `${textareaRef.current.scrollHeight}px`;
    }
  }, [prompt]);

  return (
    <div className="react-flow__node-default prompt-node" style={{ 
      width: '300px',
      borderRadius: '8px',
      boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)',
      backgroundColor: 'white',
      border: '1px solid #e2e8f0'
    }}>
      <div style={{ padding: '16px' }}>
        <Handle 
          type="target" 
          position={Position.Top} 
          id="input"
        />
        
        <div style={{ 
          display: 'flex', 
          justifyContent: 'space-between', 
          alignItems: 'center',
          marginBottom: '12px'
        }}>
          <div style={{ 
            fontWeight: 'bold', 
            fontSize: '14px',
            color: '#4a5568'
          }}>
            Image Prompt
          </div>
          <div style={{ display: 'flex', gap: '8px' }}>
            <button 
              onClick={() => setShowOptions(!showOptions)}
              className="nodrag"
              style={{
                backgroundColor: 'transparent',
                border: 'none',
                cursor: 'pointer',
                color: '#718096',
                padding: '2px',
                borderRadius: '4px',
                fontSize: '12px',
                display: 'flex',
                alignItems: 'center'
              }}
            >
              {showOptions ? 'Hide Options' : 'Show Options'}
            </button>
            <button 
              onClick={handleDelete}
              className="nodrag"
              style={{
                backgroundColor: 'transparent',
                border: 'none',
                cursor: 'pointer',
                color: '#e53e3e',
                padding: '2px',
                borderRadius: '4px'
              }}
            >
              ✕
            </button>
          </div>
        </div>
        
        <div>
          <textarea
            ref={textareaRef}
            value={prompt}
            onChange={handlePromptChange}
            onKeyDown={handleKeyDown}
            placeholder="Enter a prompt to gen an image..."
            className="nodrag"
            style={{
              width: '100%',
              minHeight: '80px',
              padding: '8px',
              borderRadius: '4px',
              border: '1px solid #e2e8f0',
              resize: 'none',
              fontSize: '13px',
              lineHeight: '1.5',
              fontFamily: 'inherit'
            }}
          />
          
          {showOptions && (
            <div style={{ marginTop: '12px' }}>
              <div style={{ 
                display: 'flex', 
                flexWrap: 'wrap', 
                gap: '8px',
                marginBottom: '8px'
              }}>
                <div style={{ flex: '1 0 48%' }}>
                  <label htmlFor="size" style={{ display: 'block', marginBottom: '2px' }}>Size:</label>
                  <select 
                    id="size" 
                    value={size} 
                    onChange={(e) => setSize(e.target.value)}
                    className="nodrag"
                    style={{
                      width: '100%',
                      padding: '3px',
                      borderRadius: '3px',
                      border: '1px solid #ddd',
                      fontSize: '12px'
                    }}
                  >
                    <option value="1024x1024">1024x1024</option>
                    <option value="1536x1024">1536x1024</option>
                    <option value="1024x1536">1024x1536</option>
                    <option value="auto">Auto</option>
                  </select>
                </div>
                
                <div style={{ flex: '1 0 48%' }}>
                  <label htmlFor="n" style={{ display: 'block', marginBottom: '2px' }}>Number:</label>
                  <select 
                    id="n" 
                    value={n} 
                    onChange={(e) => setN(parseInt(e.target.value))}
                    className="nodrag"
                    style={{
                      width: '100%',
                      padding: '3px',
                      borderRadius: '3px',
                      border: '1px solid #ddd',
                      fontSize: '12px'
                    }}
                  >
                    <option value="1">1</option>
                    <option value="2">2</option>
                    <option value="3">3</option>
                    <option value="4">4</option>
                  </select>
                </div>
                
                <div style={{ flex: '1 0 48%' }}>
                  <label htmlFor="quality" style={{ display: 'block', marginBottom: '2px' }}>Quality:</label>
                  <select 
                    id="quality" 
                    value={quality} 
                    onChange={(e) => setQuality(e.target.value)}
                    className="nodrag"
                    style={{
                      width: '100%',
                      padding: '3px',
                      borderRadius: '3px',
                      border: '1px solid #ddd',
                      fontSize: '12px'
                    }}
                  >
                    <option value="auto">Auto</option>
                    <option value="high">High</option>
                    <option value="medium">Medium</option>
                    <option value="low">Low</option>
                  </select>
                </div>
                
                <div style={{ flex: '1 0 48%' }}>
                  <label htmlFor="outputFormat" style={{ display: 'block', marginBottom: '2px' }}>Format:</label>
                  <select 
                    id="outputFormat" 
                    value={outputFormat} 
                    onChange={(e) => setOutputFormat(e.target.value)}
                    className="nodrag"
                    style={{
                      width: '100%',
                      padding: '3px',
                      borderRadius: '3px',
                      border: '1px solid #ddd',
                      fontSize: '12px'
                    }}
                  >
                    <option value="png">PNG</option>
                    <option value="jpeg">JPEG</option>
                    <option value="webp">WebP</option>
                  </select>
                </div>
                
                <div style={{ flex: '1 0 48%' }}>
                  <label htmlFor="moderation" style={{ display: 'block', marginBottom: '2px' }}>Moderation:</label>
                  <select 
                    id="moderation" 
                    value={moderation} 
                    onChange={(e) => setModeration(e.target.value)}
                    className="nodrag"
                    style={{
                      width: '100%',
                      padding: '3px',
                      borderRadius: '3px',
                      border: '1px solid #ddd',
                      fontSize: '12px'
                    }}
                  >
                    <option value="auto">Auto</option>
                    <option value="low">Low</option>
                  </select>
                </div>
                
                <div style={{ flex: '1 0 48%' }}>
                  <label htmlFor="background" style={{ display: 'block', marginBottom: '2px' }}>Background:</label>
                  <select 
                    id="background" 
                    value={background} 
                    onChange={(e) => setBackground(e.target.value)}
                    className="nodrag"
                    style={{
                      width: '100%',
                      padding: '3px',
                      borderRadius: '3px',
                      border: '1px solid #ddd',
                      fontSize: '12px'
                    }}
                  >
                    <option value="auto">Auto</option>
                    <option value="transparent">Transparent</option>
                    <option value="opaque">Opaque</option>
                  </select>
                </div>
              </div>
            </div>
          )}
        </div>
        
        {error && (
          <div style={{ color: 'red', fontSize: '12px', marginTop: '5px' }}>
            {error}
          </div>
        )}
        
        <button 
          onClick={handleGenerate}
          className="nodrag"
          disabled={isGenerating}
          style={{
            marginTop: '8px',
            padding: '6px 12px',
            backgroundColor: isGenerating ? '#a29bfe' : '#6c5ce7',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: isGenerating ? 'not-allowed' : 'pointer',
            width: '100%',
            fontWeight: 'bold',
            fontSize: '13px'
          }}
        >
          {isGenerating ? 'Generating...' : 'Generate Image'}
        </button>
      </div>
      <Handle 
        type="source" 
        position={Position.Bottom} 
        id="output"
      />
    </div>
  );
}
