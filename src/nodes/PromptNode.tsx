import { Handle, Position, type NodeProps, useReactFlow } from '@xyflow/react';
import { useCallback, useRef, useEffect } from 'react';

export function PromptNode({ data, id }: NodeProps) {
  const { deleteElements } = useReactFlow();
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  
  const handlePromptChange = useCallback((evt: React.ChangeEvent<HTMLTextAreaElement>) => {
    const newPrompt = evt.target.value;
    console.log('Prompt updated:', newPrompt);
    // If we had state management, we would update the node data here
  }, []);

  const handleDelete = useCallback(() => {
    deleteElements({ nodes: [{ id }] });
  }, [deleteElements, id]);

  // Focus the textarea when the component mounts
  useEffect(() => {
    if (textareaRef.current) {
      // Small timeout to ensure the node is fully rendered
      setTimeout(() => {
        textareaRef.current?.focus();
      }, 100);
    }
  }, []);

  return (
    <div className="react-flow__node-default prompt-node">
      <button 
        className="prompt-node-delete-btn" 
        onClick={handleDelete}
        style={{
          position: 'absolute',
          top: '5px',
          left: '5px',
          background: 'transparent',
          border: 'none',
          cursor: 'pointer',
          color: 'white',
          fontSize: '16px',
          zIndex: 10,
          padding: '2px 6px',
          borderRadius: '50%',
          lineHeight: 1
        }}
      >
        ×
      </button>
      <div className="prompt-node-header">AI Image Generator</div>
      <div className="prompt-node-content">
        <label htmlFor="prompt">Prompt:</label>
        <textarea 
          id="prompt" 
          name="prompt" 
          defaultValue={data?.prompt as string || ''}
          onChange={handlePromptChange}
          placeholder="Enter your image prompt here..."
          className="nodrag prompt-textarea"
          rows={4}
          ref={textareaRef}
          style={{ 
            boxSizing: 'border-box', 
            maxWidth: '100%', 
            overflow: 'auto' 
          }}
        />
      </div>
      <Handle 
        type="source" 
        position={Position.Bottom} 
        id="output"
      />
    </div>
  );
}
