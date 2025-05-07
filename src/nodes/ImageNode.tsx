import { Handle, Position, type NodeProps } from '@xyflow/react';

export function ImageNode({ data }: NodeProps) {
  const handleDownload = () => {
    if (data?.imageUrl) {
      // Create a temporary anchor element
      const link = document.createElement('a');
      link.href = data.imageUrl as string;
      link.download = `ai-generated-image-${Date.now()}.png`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    }
  };

  return (
    <div
      className="react-flow__node-default image-node"
      style={{
        transition: 'all 0.3s ease-in-out', // Add smooth transition for position changes
        boxShadow: '0 4px 10px rgba(0, 0, 0, 0.1)',
        borderRadius: '8px',
        border: '1px solid #e2e8f0',
        background: 'white',
      }}
    >
      <div
        className="image-node-header"
        style={{
          padding: '10px',
          borderBottom: '1px solid #e2e8f0',
          fontWeight: 'bold',
          fontSize: '14px',
          textAlign: 'center',
          color: '#333',
        }}
      >
        Generated Image
      </div>
      <div className="image-node-content">
        {data?.isLoading ? (
          <div
            className="image-loading"
            style={{
              padding: '20px',
              textAlign: 'center',
              minHeight: '150px',
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'center',
              alignItems: 'center',
            }}
          >
            <div
              className="spinner"
              style={{
                width: '40px',
                height: '40px',
                border: '4px solid rgba(0, 0, 0, 0.1)',
                borderRadius: '50%',
                borderTop: '4px solid #6c5ce7',
                animation: 'spin 1s linear infinite',
                marginBottom: '10px',
              }}
            ></div>
            <div>Generating image...</div>
            <div style={{ fontSize: '12px', marginTop: '5px', color: '#666' }}>
              {data?.prompt
                ? `"${(data.prompt as string).substring(0, 50)}${
                    (data.prompt as string).length > 50 ? '...' : ''
                  }"`
                : ''}
            </div>
            <style>{`
              @keyframes spin {
                0% { transform: rotate(0deg); }
                100% { transform: rotate(360deg); }
              }
            `}</style>
          </div>
        ) : data?.imageUrl ? (
          <div style={{ position: 'relative' }}>
            <img
              src={data.imageUrl as string}
              alt="Generated AI image"
              style={{
                maxWidth: '100%',
                borderRadius: '4px',
                display: 'block',
              }}
            />
            <button
              onClick={handleDownload}
              style={{
                position: 'absolute',
                top: '8px',
                right: '8px',
                background: 'rgba(255, 255, 255, 0.8)',
                border: 'none',
                borderRadius: '4px',
                padding: '5px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: '0 1px 3px rgba(0,0,0,0.12)',
              }}
              title="Download image"
            >
              <svg
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  d="M12 16L12 8"
                  stroke="#000"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
                <path
                  d="M9 13L12 16L15 13"
                  stroke="#000"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
                <path
                  d="M20 16V18C20 19.1046 19.1046 20 18 20H6C4.89543 20 4 19.1046 4 18V16"
                  stroke="#000"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </button>
          </div>
        ) : data?.error ? (
          <div
            className="image-error"
            style={{
              padding: '20px',
              textAlign: 'center',
              backgroundColor: '#fff0f0',
              borderRadius: '4px',
              color: '#e74c3c',
              minHeight: '100px',
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'center',
            }}
          >
            <div style={{ fontWeight: 'bold', marginBottom: '5px' }}>
              Generation Failed
            </div>
            <div style={{ fontSize: '12px' }}>{data.error as string}</div>
          </div>
        ) : (
          <div
            className="image-placeholder"
            style={{
              padding: '20px',
              textAlign: 'center',
              backgroundColor: '#f8f9fa',
              borderRadius: '4px',
              color: '#666',
            }}
          >
            Image failed to load
          </div>
        )}
      </div>
      <Handle type="target" position={Position.Top} id="input" />
    </div>
  );
}
