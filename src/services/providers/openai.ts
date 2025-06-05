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
  model: string;
  size?: string;
  n?: number;
  quality?: string;
  outputFormat?: string;
  moderation?: string;
  background?: string;
  sourceImages?: string[];
  maskImage?: string;
  style?: string;
}

export interface ImageResult {
  success: boolean;
  imageUrls?: string[];
  error?: string;
  revisedPrompt?: string;
}

/**
 * Convert data URL to File object for OpenAI API
 */
function dataUrlToFile(dataUrl: string, filename: string = 'image.png'): File {
  // Validate data URL format
  if (!dataUrl.startsWith('data:')) {
    throw new Error(`Invalid data URL format: Expected data URL but got: ${dataUrl.substring(0, 50)}...`);
  }

  const arr = dataUrl.split(',');
  if (arr.length !== 2) {
    throw new Error(`Invalid data URL format: Missing comma separator in data URL`);
  }

  const mime = arr[0].match(/:(.*?);/)?.[1] || 'image/png';
  const base64Data = arr[1];

  // Validate base64 string
  if (!base64Data || base64Data.length === 0) {
    throw new Error(`Invalid data URL format: Empty base64 data`);
  }

  // Check for invalid base64 characters
  const base64Regex = /^[A-Za-z0-9+/]*={0,2}$/;
  if (!base64Regex.test(base64Data)) {
    throw new Error(`Invalid data URL format: Base64 string contains invalid characters`);
  }

  try {
    const bstr = atob(base64Data);
    let n = bstr.length;
    const u8arr = new Uint8Array(n);
    while (n--) {
      u8arr[n] = bstr.charCodeAt(n);
    }
    return new File([u8arr], filename, { type: mime });
  } catch (error) {
    throw new Error(`Failed to decode base64 data: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }
}

/**
 * Generate images using OpenAI's Images API
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
      // Use Images Edit API
      const images = params.sourceImages!.map((dataUrl, index) => {
        try {
          return dataUrlToFile(dataUrl, `source-${index}.png`);
        } catch (error) {
          console.error(`Error processing source image ${index}:`, error);
          throw new Error(`Failed to process source image ${index}: ${error instanceof Error ? error.message : 'Unknown error'}`);
        }
      });

      const editParams: any = {
        model: params.model,
        prompt: params.prompt,
        image: images.length === 1 ? images[0] : images,
        n: params.n || 1,
        size: params.size || '1024x1024',
      };

      // Add model-specific parameters
      if (params.model === 'gpt-image-1') {
        if (params.quality && params.quality !== 'auto') editParams.quality = params.quality;
        if (params.background && params.background !== 'auto') editParams.background = params.background;
        editParams.moderation = 'low'; // Always use low moderation
        // gpt-image-1 always returns base64
      } else {
        // dall-e-2 parameters
        editParams.response_format = 'b64_json';
      }

      // Add mask if provided
      if (params.maskImage) {
        editParams.mask = dataUrlToFile(params.maskImage, 'mask.png');
      }

      response = await client.images.edit(editParams);
    } else {
      // Use Images Generate API
      const generateParams: any = {
        model: params.model,
        prompt: params.prompt,
        n: params.n || 1,
        size: params.size || '1024x1024',
      };

      // Add model-specific parameters
      if (params.model === 'gpt-image-1') {
        if (params.quality && params.quality !== 'auto') generateParams.quality = params.quality;
        if (params.background && params.background !== 'auto') generateParams.background = params.background;
        generateParams.moderation = 'low'; // Always use low moderation
        if (params.outputFormat && params.outputFormat !== 'png') generateParams.output_format = params.outputFormat;
        // gpt-image-1 always returns base64
      } else if (params.model === 'dall-e-3') {
        if (params.quality && params.quality !== 'auto') generateParams.quality = params.quality;
        if (params.style && params.style !== 'vivid') generateParams.style = params.style;
        generateParams.response_format = 'b64_json';
      } else {
        // dall-e-2
        generateParams.response_format = 'b64_json';
      }

      response = await client.images.generate(generateParams);
    }

    if (!response.data || response.data.length === 0) {
      return {
        success: false,
        error: 'No data returned from OpenAI Images API'
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

    // Get revised prompt if available (mainly for DALL-E 3)
    const revisedPrompt = response.data[0]?.revised_prompt;

    return {
      success: true,
      imageUrls,
      revisedPrompt: revisedPrompt || undefined
    };

  } catch (error) {
    console.error('OpenAI Images API error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown OpenAI API error'
    };
  }
};