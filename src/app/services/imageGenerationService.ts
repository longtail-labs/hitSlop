import { AppNode, SerializableGenerationParams } from '../nodes/types';
import { generateWithOpenAI } from './providers/openai';
import { generateWithGoogle } from './providers/google';
import { generateWithFal } from './providers/fal';
import { getModelConfig, validateModelParameters, MODEL_CONFIGS } from './models/modelConfig';
import { imageService } from './database';
import { createImageNode } from '../lib/utils';

export type ModelId = keyof typeof MODEL_CONFIGS;

export interface ImageOperationParams {
  prompt: string;
  sourceImages?: string[]; // Image IDs only (no mixed ID/URL handling)
  maskImage?: string; // Image ID only
  model?: ModelId;
  size?: string;
  n?: number;
  // Dynamic parameters based on model config
  [key: string]: any;
}

export interface OperationResult {
  success: boolean;
  imageUrls?: string[];
  error?: string;
  nodes?: AppNode[];
  revisedPrompt?: string;
}

/**
 * Simple helper to resolve image IDs to data URLs for API calls
 */
async function getImageDataUrls(imageIds: string[]): Promise<string[]> {
  const dataUrls: string[] = [];
  
  for (const imageId of imageIds) {
    try {
      const imageData = await imageService.getImage(imageId);
      if (imageData) {
        dataUrls.push(imageData);
      } else {
        console.warn(`Image not found: ${imageId}`);
      }
    } catch (error) {
      console.error(`Failed to load image ${imageId}:`, error);
    }
  }
  
  return dataUrls;
}

/**
 * Store a data URL and return its ID - used for immediate storage of uploaded images
 */
export async function storeImageFromDataUrl(
  dataUrl: string, 
  source: 'uploaded' | 'generated' | 'edited' | 'unsplash' = 'uploaded'
): Promise<string> {
  return await imageService.storeImage(dataUrl, source);
}

/**
 * Process an image operation (generation or editing) based on provided parameters
 */
export const processImageOperation = async (
  params: ImageOperationParams,
  position: { x: number, y: number },
  _nodeId?: string
): Promise<OperationResult> => {
  try {
    const modelId = params.model || 'gpt-image-1';
    const modelConfig = getModelConfig(modelId);

    if (!modelConfig) {
      return {
        success: false,
        error: `Unsupported model: ${modelId}`
      };
    }

    // Validate parameters for this model
    const validation = validateModelParameters(modelId, params);
    if (!validation.valid) {
      return {
        success: false,
        error: `Parameter validation failed: ${validation.errors.join(', ')}`
      };
    }

    // Convert image IDs to data URLs for API calls
    const sourceImageUrls = params.sourceImages ? await getImageDataUrls(params.sourceImages) : [];
    const maskImageUrl = params.maskImage ? (await getImageDataUrls([params.maskImage]))[0] : undefined;

    // Determine whether to generate or edit based on sourceImages
    const isEditOperation = sourceImageUrls.length > 0;

    console.log(`Performing image ${isEditOperation ? 'edit' : 'generation'} with model ${modelConfig.name}:`, {
      prompt: params.prompt,
      sourceImageCount: sourceImageUrls.length,
      model: modelId
    });

    let result;

    // Route to appropriate provider based on model configuration
    if (modelConfig.provider === 'openai') {
      result = await generateWithOpenAI({
        prompt: params.prompt,
        model: modelId,
        size: params.size,
        n: params.n,
        quality: params.quality,
        background: params.background,
        style: params.style,
        sourceImages: sourceImageUrls,
        maskImage: maskImageUrl,
        outputFormat: 'png',
      });
    } else if (modelConfig.provider === 'google') {
      result = await generateWithGoogle({
        prompt: params.prompt,
        model: modelId,
        size: params.size,
        n: params.n,
        aspectRatio: params.aspectRatio,
        personGeneration: params.personGeneration,
      });
    } else if (modelConfig.provider === 'fal') {
      // Handle automatic model switching for flux-kontext-auto
      let actualModelId = modelId;
      if (modelId === 'flux-kontext-auto') {
        if (sourceImageUrls.length === 0) {
          actualModelId = 'fal-ai/flux-pro/kontext/text-to-image';
        } else if (sourceImageUrls.length === 1) {
          actualModelId = 'fal-ai/flux-pro/kontext';
        } else {
          actualModelId = 'fal-ai/flux-pro/kontext/max/multi';
        }
        console.log(`FAL model selection: ${sourceImageUrls.length} source images -> ${actualModelId}`);
      }

      const falParams: any = {
        prompt: params.prompt,
        model: actualModelId,
        guidance_scale: params.guidance_scale,
        num_images: params.n,
        safety_tolerance: params.safety_tolerance,
        output_format: params.output_format,
        aspect_ratio: params.aspect_ratio,
        seed: params.seed,
      };

      // Add image parameters based on the model
      if (actualModelId === 'fal-ai/flux-pro/kontext/max/multi' && sourceImageUrls.length > 1) {
        falParams.image_urls = sourceImageUrls;
      } else if (sourceImageUrls.length > 0) {
        falParams.image_url = sourceImageUrls[0];
      }

      result = await generateWithFal(falParams);
    } else {
      return {
        success: false,
        error: `Unsupported provider: ${modelConfig.provider}`
      };
    }

    if (!result.success) {
      return result;
    }

    if (!result.imageUrls || result.imageUrls.length === 0) {
      return {
        success: false,
        error: 'No images generated'
      };
    }

    // Store generated images and create nodes
    const nodes: AppNode[] = [];
    const storedImageIds: string[] = [];

    for (const imageUrl of result.imageUrls) {
      try {
        const imageId = await imageService.storeImage(
          imageUrl,
          isEditOperation ? 'edited' : 'generated'
        );
        storedImageIds.push(imageId);
      } catch (error) {
        console.error('Error storing image:', error);
        return {
          success: false,
          error: 'Failed to store generated images'
        };
      }
    }

    // Construct serializable generation parameters for storage in the node
    let serializableParams: SerializableGenerationParams;

    if (modelConfig.provider === 'openai') {
      serializableParams = {
        prompt: params.prompt,
        model: modelId,
        n: params.n,
        sourceImages: params.sourceImages,
        maskImage: params.maskImage,
        size: params.size,
        quality: params.quality,
        style: params.style,
        background: params.background,
      };
    } else if (modelConfig.provider === 'google') {
      serializableParams = {
        prompt: params.prompt,
        model: modelId,
        n: params.n,
        sourceImages: params.sourceImages,
        maskImage: params.maskImage,
        size: params.size,
        aspectRatio: params.aspectRatio,
        personGeneration: params.personGeneration,
      };
    } else if (modelConfig.provider === 'fal') {
      serializableParams = {
        prompt: params.prompt,
        model: modelId,
        n: params.n,
        sourceImages: params.sourceImages,
        maskImage: params.maskImage,
        aspect_ratio: params.aspect_ratio,
        guidance_scale: params.guidance_scale,
        seed: params.seed,
      };
    } else {
      // This should not be reached if modelConfig validation is correct
      serializableParams = {
        prompt: params.prompt,
        model: modelId,
      };
    }

    // Create nodes with image IDs using our helper
    for (let index = 0; index < storedImageIds.length; index++) {
      const imageId = storedImageIds[index];
      const newNode = createImageNode(imageId, {
        position: {
          x: position.x + (index * 20), // Offset multiple images slightly
          y: position.y
        },
        source: isEditOperation ? 'edited' : 'generated',
        prompt: params.prompt,
        generationParams: serializableParams,
        isEdited: isEditOperation,
        revisedPrompt: result.revisedPrompt,
        modelConfig
      });
      nodes.push(newNode);
    }

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

// Export model configs for UI components
export { MODEL_CONFIGS, getModelConfig, getAvailableParameters } from './models/modelConfig';

