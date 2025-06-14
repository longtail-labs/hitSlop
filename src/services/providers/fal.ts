import { OperationResult } from '../imageGenerationService';
import { apiKeyService } from '../database';

// Install this package: npm install @fal-ai/client
let fal: any = null;

// Lazy load the fal client
async function getFalClient() {
  if (!fal) {
    try {
      const { fal: falClient } = await import('@fal-ai/client');
      fal = falClient;

      // Configure with API key
      const apiKey = await apiKeyService.getApiKey('fal');
      if (apiKey) {
        fal.config({
          credentials: apiKey
        });
      }
    } catch {
      throw new Error('Failed to load @fal-ai/client. Please install it with: npm install @fal-ai/client');
    }
  }
  return fal;
}

// Reset client when API key changes
export function resetFalClient() {
  fal = null;
}

export interface FalGenerationParams {
  prompt: string;
  model: string;
  image_url?: string; // For single image-to-image operations
  image_urls?: string[]; // For multi-image operations
  guidance_scale?: number;
  num_images?: number;
  safety_tolerance?: number;
  output_format?: 'jpeg' | 'png';
  aspect_ratio?: string;
  seed?: number;
}

export async function generateWithFal(params: FalGenerationParams): Promise<OperationResult> {
  try {
    const falClient = await getFalClient();

    // Check if we have an API key
    const apiKey = await apiKeyService.getApiKey('fal');
    if (!apiKey) {
      return {
        success: false,
        error: 'FAL API key not found. Please add your FAL API key in settings.'
      };
    }

    // For fal-ai/flux-pro/kontext (single image editing), we need an image_url
    if (params.model === 'fal-ai/flux-pro/kontext' && !params.image_url) {
      return {
        success: false,
        error: 'FLUX Kontext (Edit) requires a source image for editing. Please upload an image first.'
      };
    }

    // For fal-ai/flux-pro/kontext/max/multi (multi-image editing), we need image_urls
    if (params.model === 'fal-ai/flux-pro/kontext/max/multi' && (!params.image_urls || params.image_urls.length === 0)) {
      return {
        success: false,
        error: 'FLUX Kontext Multi requires multiple source images for editing. Please upload images first.'
      };
    }

    // Prepare request payload
    const requestPayload: any = {
      prompt: params.prompt,
      num_images: params.num_images || 1,
      safety_tolerance: "5", // Default to most permissive
      output_format: "png", // Always use PNG
    };

    // Add model-specific parameters
    if (params.image_url) {
      requestPayload.image_url = params.image_url;
    }

    if (params.image_urls && params.image_urls.length > 0) {
      requestPayload.image_urls = params.image_urls;
    }

    if (params.guidance_scale !== undefined) {
      requestPayload.guidance_scale = params.guidance_scale;
    }

    if (params.aspect_ratio) {
      requestPayload.aspect_ratio = params.aspect_ratio;
    }

    if (params.seed !== undefined) {
      requestPayload.seed = params.seed;
    }

    console.log('Generating with FAL:', {
      model: params.model,
      prompt: params.prompt,
      hasSourceImage: !!params.image_url,
      hasMultipleSourceImages: !!(params.image_urls && params.image_urls.length > 0),
      numImages: params.num_images || 1
    });

    // Submit request to FAL with sync mode to ensure base64 response
    const result = await falClient.subscribe(params.model, {
      input: {
        ...requestPayload,
        sync_mode: true, // Force synchronous mode to get base64 responses
      },
      logs: true,
      onQueueUpdate: (update: any) => {
        if (update.status === "IN_PROGRESS") {
          console.log('FAL Progress:', update.logs?.map((log: any) => log.message).join('\n'));
        }
      },
    });

    console.log('FAL Result:', result);

    if (!result.data || !result.data.images || result.data.images.length === 0) {
      return {
        success: false,
        error: 'No images generated by FAL'
      };
    }

    // Extract image URLs from FAL response and validate they are base64 data URLs
    const imageUrls: string[] = [];

    for (const img of result.data.images) {
      if (!img.url) {
        console.warn('FAL returned image without URL');
        continue;
      }

      // Check if it's a base64 data URL
      if (img.url.startsWith('data:')) {
        imageUrls.push(img.url);
        console.log(`FAL returned base64 data URL: ${img.url.substring(0, 50)}...`);
      } else {
        // If it's a regular URL, we need to convert it to base64
        console.log(`FAL returned regular URL, converting to base64: ${img.url}`);
        try {
          const response = await fetch(img.url);
          if (!response.ok) {
            throw new Error(`Failed to fetch image from URL: ${response.statusText}`);
          }

          const arrayBuffer = await response.arrayBuffer();
          const base64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)));
          const mimeType = response.headers.get('content-type') || 'image/png';
          const dataUrl = `data:${mimeType};base64,${base64}`;

          imageUrls.push(dataUrl);
          console.log(`Successfully converted URL to base64: ${dataUrl.substring(0, 50)}...`);
        } catch (error) {
          console.error(`Failed to convert FAL URL to base64:`, error);
          // As a fallback, still include the URL but warn about it
          imageUrls.push(img.url);
        }
      }
    }

    if (imageUrls.length === 0) {
      return {
        success: false,
        error: 'No valid images returned from FAL'
      };
    }

    return {
      success: true,
      imageUrls,
      revisedPrompt: result.data.prompt || params.prompt
    };

  } catch (error) {
    console.error('FAL API Error:', error);

    let errorMessage = 'Unknown error occurred';
    if (error instanceof Error) {
      errorMessage = error.message;
    } else if (typeof error === 'object' && error !== null && 'message' in error) {
      errorMessage = String(error.message);
    }

    // Handle common FAL API errors
    if (errorMessage.includes('401') || errorMessage.includes('unauthorized')) {
      errorMessage = 'Invalid FAL API key. Please check your API key in settings.';
    } else if (errorMessage.includes('quota') || errorMessage.includes('limit')) {
      errorMessage = 'FAL API quota exceeded. Please check your account limits.';
    } else if (errorMessage.includes('timeout')) {
      errorMessage = 'Request timed out. Please try again.';
    }

    return {
      success: false,
      error: errorMessage
    };
  }
} 