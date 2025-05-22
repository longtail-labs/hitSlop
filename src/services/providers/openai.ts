import OpenAI from 'openai';
import { apiKeyService } from '../database';

// Initialize OpenAI client with placeholder - will be set dynamically
let openai: OpenAI | null = null;

async function getOpenAIClient(): Promise<OpenAI | null> {
  if (!openai) {
    const apiKey = await apiKeyService.getApiKey('openai');
    if (!apiKey) {
      return null;
    }
    openai = new OpenAI({
      apiKey,
      dangerouslyAllowBrowser: true,
    });
  }
  return openai;
}

// Reset client when API key changes
export function resetOpenAIClient() {
  openai = null;
}

export interface OpenAIImageParams {
  prompt: string;
  model: 'gpt-image-1' | 'dall-e-2' | 'dall-e-3';
  size?: '1024x1024' | '1536x1024' | '1024x1536';
  n?: number;
  quality?: 'auto' | 'high' | 'medium' | 'low';
  outputFormat?: 'png' | 'jpeg' | 'webp';
  moderation?: 'auto' | 'low';
  background?: 'auto' | 'transparent' | 'opaque';
  sourceImages?: string[];
  maskImage?: string;
}

export interface ImageResult {
  success: boolean;
  imageUrls?: string[];
  error?: string;
}

/**
 * Generate images using OpenAI's API (DALL-E 2, DALL-E 3, or GPT-Image-1)
 */
export const generateWithOpenAI = async (params: OpenAIImageParams): Promise<ImageResult> => {
  try {
    const client = await getOpenAIClient();
    if (!client) {
      return {
        success: false,
        error: 'OpenAI API key is not configured. Please set up your API key in settings.'
      };
    }

    const isEditOperation = params.sourceImages && params.sourceImages.length > 0;

    let response;

    if (isEditOperation) {
      // Handle image editing for models that support it
      if (params.model === 'gpt-image-1') {
        // GPT-Image-1 supports editing
        const formData = new FormData();
        formData.append('model', params.model);
        formData.append('prompt', params.prompt);

        params.sourceImages!.forEach((imageDataUrl) => {
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

        const apiKey = await apiKeyService.getApiKey('openai');
        const apiResponse = await fetch('https://api.openai.com/v1/images/edits', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${apiKey}`,
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
        // DALL-E 2 and DALL-E 3 editing (if supported)
        return {
          success: false,
          error: `Image editing not supported for ${params.model}`
        };
      }
    } else {
      // Generate new images
      const generateParams: any = {
        model: params.model,
        prompt: params.prompt,
        n: params.n || 1,
        size: params.size || '1024x1024',
      };

      // Add model-specific parameters
      if (params.model === 'dall-e-3' || params.model === 'gpt-image-1') {
        if (params.quality) generateParams.quality = params.quality;
        if (params.background) generateParams.background = params.background;
        if (params.outputFormat) generateParams.output_format = params.outputFormat;
        if (params.moderation) generateParams.moderation = params.moderation;
      }

      response = await client.images.generate(generateParams);
    }

    // Process response
    if (!response.data || response.data.length === 0) {
      return {
        success: false,
        error: 'No data returned from OpenAI API'
      };
    }

    const imageUrls: string[] = [];
    const format = params.outputFormat || 'png';

    response.data.forEach((imageData: any) => {
      let imageUrl;
      
      if (imageData.b64_json) {
        imageUrl = `data:image/${format};base64,${imageData.b64_json}`;
      } else if (imageData.url) {
        imageUrl = imageData.url;
      }
      
      if (imageUrl) {
        imageUrls.push(imageUrl);
      }
    });

    return {
      success: true,
      imageUrls
    };

  } catch (error) {
    console.error('OpenAI API error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown OpenAI API error'
    };
  }
};

/**
 * Helper function to convert Data URL to Blob
 */
function dataURItoBlob(dataURI: string): Blob {
  let byteString;
  if (dataURI.split(',')[0].indexOf('base64') >= 0) {
    byteString = atob(dataURI.split(',')[1]);
  } else {
    byteString = decodeURI(dataURI.split(',')[1]);
  }

  const mimeString = dataURI.split(',')[0].split(':')[1].split(';')[0];
  const ia = new Uint8Array(byteString.length);
  for (let i = 0; i < byteString.length; i++) {
    ia[i] = byteString.charCodeAt(i);
  }

  return new Blob([ia], { type: mimeString });
}