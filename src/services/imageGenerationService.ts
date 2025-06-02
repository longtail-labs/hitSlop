import { AppNode } from '../nodes/types';
import { generateWithOpenAI } from './providers/openai';
import { generateWithGoogle } from './providers/google';

export interface ImageOperationParams {
  prompt: string;
  sourceImages?: string[]; // Base64 encoded images
  maskImage?: string; // Optional base64 encoded mask
  model?: 'gpt-image-1' | 'dall-e-2' | 'dall-e-3' | 'imagen-3.0-generate-002' | 'imagen-3.0-fast-generate-001' | 'imagen-4.0-generate-preview-05-20';
  size?: '1024x1024' | '1536x1024' | '1024x1536' | 'auto';
  n?: number;
  quality?: 'auto' | 'high' | 'medium' | 'low';
  outputFormat?: 'png' | 'jpeg' | 'webp';
  moderation?: 'auto' | 'low';
  background?: 'auto' | 'transparent' | 'opaque';
  outputCompression?: number;
  // Streaming support
  enableStreaming?: boolean;
  partialImages?: number; // 1-3 partial images for streaming
  onPartialImageUpdate?: (nodeId: string, partialImageUrl: string) => void;
  onProgressUpdate?: (nodeId: string, status: string) => void;
}

export interface OperationResult {
  success: boolean;
  imageUrls?: string[];
  error?: string;
  nodes?: AppNode[];
  revisedPrompt?: string;
}

/**
 * Process an image operation (generation or editing) based on provided parameters
 */
export const processImageOperation = async (
  params: ImageOperationParams,
  position: { x: number, y: number },
  nodeId?: string // For streaming updates
): Promise<OperationResult> => {
  try {
    const model = params.model || 'gpt-image-1';

    // Determine whether to generate or edit based on sourceImages
    const isEditOperation = params.sourceImages && params.sourceImages.length > 0;

    console.log(`Performing image ${isEditOperation ? 'edit' : 'generation'} with model ${model}:`, params);

    let result;

    // Route to appropriate provider based on model
    if (model.startsWith('gpt-image') || model.startsWith('dall-e')) {
      // OpenAI models - prepare streaming callbacks if enabled
      const openAIParams: any = {
        prompt: params.prompt,
        model: model as any,
        size: params.size === 'auto' ? '1024x1024' : params.size,
        n: params.n,
        quality: params.quality,
        outputFormat: params.outputFormat,
        moderation: params.moderation,
        background: params.background,
        sourceImages: params.sourceImages,
        maskImage: params.maskImage,
      };

      // Add streaming support for gpt-image-1
      if (model === 'gpt-image-1' && params.enableStreaming) {
        openAIParams.stream = true;
        openAIParams.partialImages = params.partialImages || 2;

        // Set up streaming callbacks if nodeId provided
        if (nodeId) {
          openAIParams.onPartialImage = (partialImageUrl: string) => {
            params.onPartialImageUpdate?.(nodeId, partialImageUrl);
          };

          openAIParams.onProgress = (status: string) => {
            params.onProgressUpdate?.(nodeId, status);
          };
        }
      }

      result = await generateWithOpenAI(openAIParams);
    } else if (model.startsWith('imagen')) {
      // Google models (no streaming support yet)
      result = await generateWithGoogle({
        prompt: params.prompt,
        model: model as any,
        size: params.size === 'auto' ? '1024x1024' : params.size,
        n: params.n,
      });
    } else {
      return {
        success: false,
        error: `Unsupported model: ${model}`
      };
    }

    if (!result.success) {
      return {
        success: false,
        error: result.error
      };
    }

    if (!result.imageUrls || result.imageUrls.length === 0) {
      return {
        success: false,
        error: 'No images generated'
      };
    }

    // Create nodes for each generated image
    const nodes: AppNode[] = [];
    result.imageUrls.forEach((imageUrl, index) => {
      const newNode: AppNode = {
        id: nodeId || `image-node-${Date.now()}-${index}`,
        type: 'image-node',
        position: position, // This position will be overridden by the caller's layout logic
        data: {
          imageUrl,
          prompt: params.prompt,
          generationParams: { ...params },
          isEdited: isEditOperation,
          revisedPrompt: result.revisedPrompt
        }
      };
      nodes.push(newNode);
    });

    return {
      success: true,
      imageUrls: result.imageUrls,
      nodes,
      revisedPrompt: result.revisedPrompt
    };
  } catch (error) {
    console.error('Error processing image:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error occurred'
    };
  }
};

