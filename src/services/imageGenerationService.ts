import { AppNode, SerializableGenerationParams } from '../nodes/types';
import { generateWithOpenAI } from './providers/openai';
import { generateWithGoogle } from './providers/google';
import { getModelConfig, validateModelParameters, MODEL_CONFIGS } from './models/modelConfig';

export type ModelId = keyof typeof MODEL_CONFIGS;

export interface ImageOperationParams {
  prompt: string;
  sourceImages?: string[]; // Base64 encoded images
  maskImage?: string; // Optional base64 encoded mask
  model?: ModelId; // Now accepts any model ID from config
  size?: string;
  n?: number;
  // Dynamic parameters based on model config
  [key: string]: any;
  // Streaming support
  enableStreaming?: boolean;
  partialImages?: number; // 1-3 partial images for streaming
  onPartialImageUpdate?: (_nodeId: string, _partialImageUrl: string) => void;
  onProgressUpdate?: (_nodeId: string, _status: string) => void;
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

    // Determine whether to generate or edit based on sourceImages
    const isEditOperation = params.sourceImages && params.sourceImages.length > 0;

    console.log(`Performing image ${isEditOperation ? 'edit' : 'generation'} with model ${modelConfig.name}:`, params);

    let result;

    // Route to appropriate provider based on model configuration
    if (modelConfig.provider === 'openai') {
      // Prepare OpenAI-specific parameters
      const openAIParams = {
        prompt: params.prompt,
        model: modelId,
        size: params.size,
        n: params.n,
        quality: params.quality,
        outputFormat: 'png', // Always use PNG
        moderation: 'low', // Always use low moderation
        background: params.background,
        sourceImages: params.sourceImages,
        maskImage: params.maskImage,
        stream: modelId === 'gpt-image-1', // Always stream for GPT Image 1
        partialImages: 2, // Default to 2 partial images
        onPartialImage: nodeId ? (partialImageUrl: string) => {
          params.onPartialImageUpdate?.(nodeId, partialImageUrl);
        } : undefined,
        onProgress: nodeId ? (status: string) => {
          params.onProgressUpdate?.(nodeId, status);
        } : undefined,
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

    // Create nodes for each generated image
    const nodes: AppNode[] = [];
    // Construct serializable generation parameters for storage in the node
    const serializableParams: SerializableGenerationParams = {
      prompt: params.prompt,
      model: params.model,
      size: params.size,
      n: params.n,
      sourceImages: params.sourceImages,
      maskImage: params.maskImage,
      // Add other model-specific parameters that were actually used and are serializable
      // These would come from params, e.g., params.quality, params.aspectRatio, etc.
    };
    // Add known dynamic params to serializableParams if they exist in 'params'
    if (params.quality !== undefined) serializableParams.quality = params.quality;
    if (params.background !== undefined) serializableParams.background = params.background;
    if (params.aspectRatio !== undefined) serializableParams.aspectRatio = params.aspectRatio;
    if (params.personGeneration !== undefined) serializableParams.personGeneration = params.personGeneration;

    result.imageUrls.forEach((imageUrl, index) => {
      const newNode: AppNode = {
        id: nodeId || `image-node-${Date.now()}-${index}`,
        type: 'image-node',
        position: position, // This position will be overridden by the caller's layout logic
        data: {
          imageUrl,
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

