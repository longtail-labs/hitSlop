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
  model: string; // Now accepts any OpenAI model ID
  size?: string;
  n?: number;
  quality?: string;
  outputFormat?: string;
  moderation?: string;
  background?: string;
  sourceImages?: string[];
  maskImage?: string;
  // Streaming support
  stream?: boolean;
  partialImages?: number; // 1-3 partial images
  onPartialImage?: (_partialImageBase64: string, _index: number) => void;
  onProgress?: (_status: string) => void;
}

export interface ImageResult {
  success: boolean;
  imageUrls?: string[];
  error?: string;
  revisedPrompt?: string;
}

/**
 * Generate images using OpenAI's Responses API (supports streaming)
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

    // For DALL-E models, fallback to Image API since Responses API only supports gpt-image-1
    if (params.model === 'dall-e-2' || params.model === 'dall-e-3') {
      return generateWithImageAPI(params);
    }

    // Use Responses API for gpt-image-1
    const isEditOperation = params.sourceImages && params.sourceImages.length > 0;

    // Prepare input content
    const inputContent: any[] = [
      { type: "input_text", text: params.prompt }
    ];

    // Add source images if editing
    if (isEditOperation) {
      params.sourceImages!.forEach((imageDataUrl) => {
        inputContent.push({
          type: "input_image",
          image_url: imageDataUrl
        });
      });
    }

    // Prepare tools configuration
    const imageGenerationTool: any = {
      type: "image_generation"
    };

    // Add optional parameters
    if (params.quality && params.quality !== 'auto') {
      imageGenerationTool.quality = params.quality;
    }
    if (params.background && params.background !== 'auto') {
      imageGenerationTool.background = params.background;
    }
    // Always include size parameter to ensure correct dimensions
    if (params.size) {
      console.log('Setting image generation size:', params.size);
      imageGenerationTool.size = params.size;
    }
    if (params.outputFormat && params.outputFormat !== 'png') {
      imageGenerationTool.output_format = params.outputFormat;
    }
    if (params.moderation && params.moderation !== 'auto') {
      imageGenerationTool.moderation = params.moderation;
    }

    // Add mask for inpainting if provided
    if (params.maskImage) {
      imageGenerationTool.input_image_mask = {
        image_url: params.maskImage
      };
    }

    // Add streaming support
    if (params.stream && params.partialImages) {
      imageGenerationTool.partial_images = Math.min(Math.max(params.partialImages, 1), 3);
    }

    console.log('Image generation tool config:', imageGenerationTool);

    const requestParams: any = {
      model: "gpt-4.1-mini", // Use a supported model for Responses API
      input: [
        {
          role: "user",
          content: inputContent
        }
      ],
      tools: [imageGenerationTool]
    };

    // Handle streaming
    if (params.stream) {
      requestParams.stream = true;
      return handleStreamingGeneration(client, requestParams, params);
    } else {
      // Non-streaming generation
      const response = await client.responses.create(requestParams);
      return processResponse(response);
    }

  } catch (error) {
    console.error('OpenAI Responses API error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown OpenAI API error'
    };
  }
};

/**
 * Handle streaming image generation
 */
async function handleStreamingGeneration(
  client: OpenAI,
  requestParams: any,
  params: OpenAIImageParams
): Promise<ImageResult> {
  try {
    console.log('Starting streaming generation with params:', requestParams);
    const stream = await client.responses.create(requestParams) as any; // Type assertion for streaming

    let finalImageBase64: string | null = null;
    let revisedPrompt: string | null = null;
    let partialImageCount = 0;

    params.onProgress?.('Starting image generation...');

    for await (const event of stream) {
      console.log('Received streaming event:', event.type, event);

      if (event.type === "response.image_generation_call.partial_image") {
        partialImageCount++;
        const partialImageBase64 = event.partial_image_b64;
        const partialIndex = event.partial_image_index || 0;

        console.log(`Received partial image ${partialImageCount}, index: ${partialIndex}`);
        params.onProgress?.('Generating...');

        // Convert base64 to data URL
        const dataUrl = `data:image/png;base64,${partialImageBase64}`;
        params.onPartialImage?.(dataUrl, partialIndex);

      } else if (event.type === "response.image_generation_call.completed") {
        console.log('Image generation completed event:', event);
        finalImageBase64 = event.result;
        revisedPrompt = event.revised_prompt;
        params.onProgress?.('Generation complete!');

      } else if (event.type === "response.completed") {
        console.log('Response completed event:', event);
        // This might be where the final image is
        if (event.response?.output) {
          const imageGenerationCall = event.response.output.find((output: any) => output.type === "image_generation_call");
          if (imageGenerationCall && imageGenerationCall.result) {
            console.log('Found final image in response.completed:', imageGenerationCall);
            finalImageBase64 = imageGenerationCall.result;
            revisedPrompt = imageGenerationCall.revised_prompt;
          }
        }
      } else {
        console.log('Unhandled event type:', event.type, event);
      }
    }

    console.log('Streaming completed. Final image available:', !!finalImageBase64);

    if (!finalImageBase64) {
      return {
        success: false,
        error: 'No final image received from streaming response'
      };
    }

    // Convert base64 to data URL
    const finalDataUrl = `data:image/png;base64,${finalImageBase64}`;

    return {
      success: true,
      imageUrls: [finalDataUrl],
      revisedPrompt: revisedPrompt || undefined
    };

  } catch (error) {
    console.error('Streaming generation error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Streaming generation failed'
    };
  }
}

/**
 * Process non-streaming response
 */
function processResponse(response: any): ImageResult {
  const imageData = response.output
    .filter((output: any) => output.type === "image_generation_call")
    .map((output: any) => output.result);

  if (imageData.length === 0) {
    return {
      success: false,
      error: 'No image data in response'
    };
  }

  // Convert base64 to data URLs
  const imageUrls = imageData.map((base64: string) => `data:image/png;base64,${base64}`);

  // Get revised prompt if available
  const imageGenerationCall = response.output.find((output: any) => output.type === "image_generation_call");
  const revisedPrompt = imageGenerationCall?.revised_prompt;

  return {
    success: true,
    imageUrls,
    revisedPrompt
  };
}

/**
 * Fallback to Image API for DALL-E models
 */
async function generateWithImageAPI(params: OpenAIImageParams): Promise<ImageResult> {
  try {
    const client = await getOpenAIClient();
    if (!client) {
      return {
        success: false,
        error: 'OpenAI API key is not configured.'
      };
    }

    const generateParams: any = {
      model: params.model,
      prompt: params.prompt,
      n: params.n || 1,
      size: params.size || '1024x1024',
    };

    // Add model-specific parameters for DALL-E 3
    if (params.model === 'dall-e-3') {
      if (params.quality && params.quality !== 'auto') generateParams.quality = params.quality;
    }

    const response = await client.images.generate(generateParams);

    if (!response.data || response.data.length === 0) {
      return {
        success: false,
        error: 'No data returned from OpenAI Image API'
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
    console.error('OpenAI Image API error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Image API error'
    };
  }
}