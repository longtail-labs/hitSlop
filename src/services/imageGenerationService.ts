import { AppNode, SerializableGenerationParams } from '../nodes/types';
import { generateWithOpenAI } from './providers/openai';
import { generateWithGoogle } from './providers/google';
import { getModelConfig, validateModelParameters, MODEL_CONFIGS } from './models/modelConfig';
import { imageService } from './database';

export type ModelId = keyof typeof MODEL_CONFIGS;

export interface ImageOperationParams {
  prompt: string;
  sourceImages?: string[]; // Can be either Base64 encoded images OR image IDs (we'll handle both)
  maskImage?: string; // Optional base64 encoded mask OR image ID
  model?: ModelId; // Now accepts any model ID from config
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
 * Convert image references (IDs or data URLs) to data URLs for API calls
 */
async function resolveImageReferences(imageReferences?: string[]): Promise<string[]> {
  if (!imageReferences || imageReferences.length === 0) return [];

  const resolvedImages: string[] = [];

  for (const reference of imageReferences) {
    // Check if it's already a data URL
    if (reference.startsWith('data:')) {
      resolvedImages.push(reference);
    } else {
      // Assume it's an image ID, try to resolve it
      try {
        const imageUrl = await imageService.getImage(reference);
        if (imageUrl) {
          resolvedImages.push(imageUrl);
        } else {
          console.warn(`Image ID ${reference} not found in storage`);
        }
      } catch (error) {
        console.error(`Error resolving image ID ${reference}:`, error);
      }
    }
  }

  return resolvedImages;
}

/**
 * Process an image operation (generation or editing) based on provided parameters
 */
export const processImageOperation = async (
  params: ImageOperationParams,
  position: { x: number, y: number },
  nodeId?: string
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

    // Resolve image references to data URLs for API calls
    const sourceImageUrls = await resolveImageReferences(params.sourceImages);
    const maskImageUrl = params.maskImage ? (await resolveImageReferences([params.maskImage]))[0] : undefined;

    // Validate parameters for this model
    const validation = validateModelParameters(modelId, params);
    if (!validation.valid) {
      return {
        success: false,
        error: `Parameter validation failed: ${validation.errors.join(', ')}`
      };
    }

    // Determine whether to generate or edit based on sourceImages
    const isEditOperation = sourceImageUrls && sourceImageUrls.length > 0;

    console.log(`Performing image ${isEditOperation ? 'edit' : 'generation'} with model ${modelConfig.name}:`, params);

    let result;

    // Route to appropriate provider based on model configuration
    if (modelConfig.provider === 'openai') {
      // Prepare OpenAI-specific parameters with resolved image URLs
      const openAIParams = {
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
      };

      result = await generateWithOpenAI(openAIParams);
    } else if (modelConfig.provider === 'google') {
      // Prepare Google-specific parameters
      const googleParams = {
        prompt: params.prompt,
        model: modelId,
        size: params.size,
        n: params.n,
        aspectRatio: params.aspectRatio,
        personGeneration: params.personGeneration,
      };

      result = await generateWithGoogle(googleParams);
    } else {
      return {
        success: false,
        error: `Unsupported provider: ${modelConfig.provider}`
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

    // Store images in optimized storage and create nodes with image IDs
    const nodes: AppNode[] = [];
    const storedImageIds: string[] = [];

    // Store generated images in the database
    for (let i = 0; i < result.imageUrls.length; i++) {
      const imageUrl = result.imageUrls[i];
      try {
        const imageId = await imageService.storeImage(
          imageUrl,
          isEditOperation ? 'edited' : 'generated',
          {
            // We could extract dimensions here if needed
            // width: extractImageWidth(imageUrl),
            // height: extractImageHeight(imageUrl),
          }
        );
        storedImageIds.push(imageId);
      } catch (error) {
        console.error('Error storing image:', error);
        // Fallback to storing the URL directly for backward compatibility
        storedImageIds.push(imageUrl);
      }
    }

    // Convert source image IDs/URLs for storage in generation params
    const sourceImageIds: string[] = [];
    if (params.sourceImages) {
      for (const reference of params.sourceImages) {
        // If it's already an ID (not a data URL), use it as-is
        if (!reference.startsWith('data:')) {
          sourceImageIds.push(reference);
        } else {
          // Store the source image and get its ID
          try {
            const sourceImageId = await imageService.storeImage(reference, 'uploaded');
            sourceImageIds.push(sourceImageId);
          } catch (error) {
            console.error('Error storing source image:', error);
            sourceImageIds.push(reference); // Fallback to URL
          }
        }
      }
    }

    // Handle mask image ID/URL
    let maskImageId: string | null = null;
    if (params.maskImage) {
      if (!params.maskImage.startsWith('data:')) {
        maskImageId = params.maskImage;
      } else {
        try {
          maskImageId = await imageService.storeImage(params.maskImage, 'uploaded');
        } catch (error) {
          console.error('Error storing mask image:', error);
          maskImageId = params.maskImage; // Fallback to URL
        }
      }
    }

    // Construct serializable generation parameters for storage in the node
    const serializableParams: SerializableGenerationParams = {
      prompt: params.prompt,
      model: params.model,
      size: params.size,
      n: params.n,
      sourceImages: sourceImageIds.length > 0 ? sourceImageIds : undefined,
      maskImage: maskImageId,
      // Add other model-specific parameters that were actually used and are serializable
    };

    // Add known dynamic params to serializableParams if they exist in 'params'
    if (params.quality !== undefined) serializableParams.quality = params.quality;
    if (params.background !== undefined) serializableParams.background = params.background;
    if (params.style !== undefined) serializableParams.style = params.style;
    if (params.aspectRatio !== undefined) serializableParams.aspectRatio = params.aspectRatio;
    if (params.personGeneration !== undefined) serializableParams.personGeneration = params.personGeneration;

    // Create nodes with optimized storage (image IDs instead of URLs)
    storedImageIds.forEach((imageId, index) => {
      const newNode: AppNode = {
        id: nodeId || `image-node-${Date.now()}-${index}`,
        type: 'image-node',
        position: position, // This position will be overridden by the caller's layout logic
        data: {
          imageId, // Use the stored image ID
          prompt: params.prompt,
          generationParams: serializableParams, // Use the explicitly constructed serializable params
          isEdited: isEditOperation,
          revisedPrompt: result.revisedPrompt,
          modelConfig // Include model config in node data
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

// Export model configs for UI components
export { MODEL_CONFIGS, getModelConfig, getAvailableParameters } from './models/modelConfig';

