import OpenAI from 'openai';
import { AppNode } from '../nodes/types';

// Initialize OpenAI client
// Note: In a real application, you'd want to handle API keys more securely
// This is just for demonstration purposes
const openai = new OpenAI({
  apiKey: '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',
  dangerouslyAllowBrowser: true, // This allows using OpenAI in browser environments
});

export interface GenerateImageParams {
  prompt: string;
  model?: 'gpt-image-1';
  size?: '1024x1024' | '1536x1024' | '1024x1536' | 'auto';
  n?: number;
  quality?: 'auto' | 'high' | 'medium' | 'low';
  outputFormat?: 'png' | 'jpeg' | 'webp';
  moderation?: 'auto' | 'low';
  background?: 'auto' | 'transparent' | 'opaque';
}

export interface GenerationResult {
  success: boolean;
  imageUrls?: string[];
  error?: string;
  nodes?: AppNode[];
}

/**
 * Generate an image using OpenAI's API and create a new image node
 */
export const generateImage = async (
  params: GenerateImageParams,
  position: { x: number, y: number }
): Promise<GenerationResult> => {
  try {
    if (!openai.apiKey || openai.apiKey === '') {
      return {
        success: false,
        error: 'OpenAI API key is not set. Please set REACT_APP_OPENAI_API_KEY in your environment.'
      };
    }

    // Log generation parameters
    console.log('Generating image with parameters:', params);

    // Call OpenAI API
    const response = await openai.images.generate({
      model: params.model || 'gpt-image-1',
      prompt: params.prompt,
      n: params.n || 1,
      size: params.size || '1024x1024',
      quality: params.quality as any || 'auto',
      style: undefined, // Not used for gpt-image-1
      ...(params.background && { background: params.background }),
      ...(params.moderation && { moderation: params.moderation }),
    });

    // Check if we got a valid response
    if (!response.data || response.data.length === 0 || !response.data[0].b64_json) {
      return {
        success: false,
        error: 'Failed to generate image: No data returned from API'
      };
    }

    const imageUrls: string[] = [];
    const nodes: AppNode[] = [];
    const format = params.outputFormat || 'png';

    // Process each generated image
    response.data.forEach((imageData, index) => {
      if (imageData.b64_json) {
        // Create a data URL from the base64 image
        const imageBase64 = imageData.b64_json;
        const imageUrl = `data:image/${format};base64,${imageBase64}`;
        imageUrls.push(imageUrl);

        // Calculate position for each node (staggered if multiple)
        const nodePosition = {
          x: position.x + (index * 50), // Stagger horizontally
          y: position.y + (index * 50)  // Stagger vertically
        };

        // Create a new image node
        const newNode: AppNode = {
          id: `image-node-${Date.now()}-${index}`,
          type: 'image-node',
          position: nodePosition,
          data: {
            imageUrl,
            prompt: params.prompt,
            generationParams: { ...params }
          }
        };

        nodes.push(newNode);
      }
    });

    return {
      success: true,
      imageUrls,
      nodes
    };
  } catch (error) {
    console.error('Error generating image:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error occurred'
    };
  }
};
