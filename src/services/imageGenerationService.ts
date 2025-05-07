import OpenAI from 'openai';
import { AppNode } from '../nodes/types';

// Initialize OpenAI client
// Note: In a real application, you'd want to handle API keys more securely
// This is just for demonstration purposes
const openai = new OpenAI({
  apiKey: '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',
  dangerouslyAllowBrowser: true, // This allows using OpenAI in browser environments
});

export interface ImageOperationParams {
  prompt: string;
  sourceImages?: string[]; // Base64 encoded images
  maskImage?: string; // Optional base64 encoded mask
  model?: 'gpt-image-1';
  size?: '1024x1024' | '1536x1024' | '1024x1536' | 'auto';
  n?: number;
  quality?: 'auto' | 'high' | 'medium' | 'low';
  outputFormat?: 'png' | 'jpeg' | 'webp';
  moderation?: 'auto' | 'low';
  background?: 'auto' | 'transparent' | 'opaque';
  outputCompression?: number;
}

export interface OperationResult {
  success: boolean;
  imageUrls?: string[];
  error?: string;
  nodes?: AppNode[];
}

/**
 * Process an image operation (generation or editing) based on provided parameters
 */
export const processImageOperation = async (
  params: ImageOperationParams,
  position: { x: number, y: number }
): Promise<OperationResult> => {
  try {
    if (!openai.apiKey || openai.apiKey === '') {
      return {
        success: false,
        error: 'OpenAI API key is not set.'
      };
    }

    // Determine whether to generate or edit based on sourceImages
    const isEditOperation = params.sourceImages && params.sourceImages.length > 0;

    console.log(`Performing image ${isEditOperation ? 'edit' : 'generation'} with parameters:`, params);

    let response;

    if (isEditOperation) {
      // EDIT MODE - Use the edit endpoint with source images
      if (!params.sourceImages || params.sourceImages.length === 0) {
        return {
          success: false,
          error: 'No source images provided for editing'
        };
      }

      // Prepare form data for the API call
      const formData = new FormData();
      formData.append('model', params.model || 'gpt-image-1');
      formData.append('prompt', params.prompt);

      // Convert data URLs to Blob objects and append to form
      params.sourceImages.forEach((imageDataUrl, index) => {
        const blob = dataURItoBlob(imageDataUrl);
        formData.append(`image[]`, blob);
      });

      if (params.maskImage) {
        const maskBlob = dataURItoBlob(params.maskImage);
        formData.append('mask', maskBlob);
      }

      if (params.n) formData.append('n', params.n.toString());
      if (params.size) formData.append('size', params.size);
      if (params.quality) formData.append('quality', params.quality);
      if (params.background) formData.append('background', params.background);

      // Custom fetch call for image edits
      const apiResponse = await fetch('https://api.openai.com/v1/images/edits', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${openai.apiKey}`,
        },
        body: formData,
      });

      if (!apiResponse.ok) {
        const errorData = await apiResponse.json();
        return {
          success: false,
          error: errorData.error?.message || `API error: ${apiResponse.status}`
        };
      }

      response = await apiResponse.json();
    } else {
      // GENERATE MODE - Use the generation endpoint
      response = await openai.images.generate({
        model: params.model || 'gpt-image-1',
        prompt: params.prompt,
        n: params.n || 1,
        size: params.size || '1024x1024',
        quality: params.quality as any || 'auto',
        ...(params.background && { background: params.background }),
        ...(params.moderation && { moderation: params.moderation }),
        ...(params.outputFormat && { output_format: params.outputFormat }),
        ...(params.outputCompression && { output_compression: params.outputCompression }),
      });
    }

    // Check if we got a valid response
    if (!response.data || response.data.length === 0) {
      return {
        success: false,
        error: 'Failed to process image: No data returned from API'
      };
    }

    const imageUrls: string[] = [];
    const nodes: AppNode[] = [];
    const format = params.outputFormat || 'png';

    // Process each result image
    response.data.forEach((imageData: any, index: number) => {
      let imageUrl;

      if (imageData.b64_json) {
        // Create a data URL from the base64 image
        imageUrl = `data:image/${format};base64,${imageData.b64_json}`;
      } else if (imageData.url) {
        imageUrl = imageData.url;
      } else {
        return; // Skip if no image data
      }

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
          generationParams: { ...params },
          isEdited: isEditOperation
        }
      };

      nodes.push(newNode);
    });

    return {
      success: true,
      imageUrls,
      nodes
    };
  } catch (error) {
    console.error('Error processing image:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error occurred'
    };
  }
};

/**
 * Helper function to convert Data URL to Blob
 */
function dataURItoBlob(dataURI: string): Blob {
  // Convert base64/URLEncoded data component to raw binary data
  let byteString;
  if (dataURI.split(',')[0].indexOf('base64') >= 0) {
    byteString = atob(dataURI.split(',')[1]);
  } else {
    byteString = decodeURI(dataURI.split(',')[1]);
  }

  // Separate out the mime component
  const mimeString = dataURI.split(',')[0].split(':')[1].split(';')[0];

  // Write the bytes of the string to a typed array
  const ia = new Uint8Array(byteString.length);
  for (let i = 0; i < byteString.length; i++) {
    ia[i] = byteString.charCodeAt(i);
  }

  return new Blob([ia], { type: mimeString });
}
