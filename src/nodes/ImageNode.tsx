import { Handle, Position, type NodeProps } from '@xyflow/react';

export function ImageNode({ data }: NodeProps) {
  return (
    <div className="react-flow__node-default image-node">
      <div className="image-node-header">Generated Image</div>
      <div className="image-node-content">
        {data?.isLoading ? (
          <div className="image-loading" style={{ 
            padding: '20px', 
            textAlign: 'center',
            minHeight: '150px',
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
            alignItems: 'center'
          }}>
            <div className="spinner" style={{
              width: '40px',
              height: '40px',
              border: '4px solid rgba(0, 0, 0, 0.1)',
              borderRadius: '50%',
              borderTop: '4px solid #6c5ce7',
              animation: 'spin 1s linear infinite',
              marginBottom: '10px'
            }}></div>
            <div>Generating image...</div>
            <div style={{ fontSize: '12px', marginTop: '5px', color: '#666' }}>
              {data?.prompt ? `"${(data.prompt as string).substring(0, 50)}${(data.prompt as string).length > 50 ? '...' : ''}"` : ''}
            </div>
            <style>{`
              @keyframes spin {
                0% { transform: rotate(0deg); }
                100% { transform: rotate(360deg); }
              }
            `}</style>
          </div>
        ) : data?.imageUrl ? (
          <img 
            src={data.imageUrl as string} 
            alt="Generated AI image" 
            style={{ 
              maxWidth: '100%', 
              borderRadius: '4px',
              display: 'block'
            }} 
          />
        ) : data?.error ? (
          <div className="image-error" style={{
            padding: '20px',
            textAlign: 'center',
            backgroundColor: '#fff0f0',
            borderRadius: '4px',
            color: '#e74c3c',
            minHeight: '100px',
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center'
          }}>
            <div style={{ fontWeight: 'bold', marginBottom: '5px' }}>Generation Failed</div>
            <div style={{ fontSize: '12px' }}>{data.error as string}</div>
          </div>
        ) : (
          <div className="image-placeholder" style={{
            padding: '20px',
            textAlign: 'center',
            backgroundColor: '#f8f9fa',
            borderRadius: '4px',
            color: '#666'
          }}>
            Image failed to load
          </div>
        )}
      </div>
      <Handle 
        type="target" 
        position={Position.Top} 
        id="input"
      />
    </div>
  );
}
