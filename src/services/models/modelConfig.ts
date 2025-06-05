export type ModelProvider = 'openai' | 'google' | 'fal';

export type ModelCapability =
  | 'generation'
  | 'editing'
  | 'inpainting'
  | 'variations'
  | 'multi_turn'
  | 'transparent_background'
  | 'high_quality'
  | 'aspect_ratios';

export interface ModelParameter {
  name: string;
  type: 'string' | 'number' | 'boolean' | 'select';
  options?: (string | number)[];
  default?: any;
  label: string;
  description?: string;
  dependsOn?: string[]; // Other parameters this depends on
  enabledWhen?: Record<string, any>; // Conditions when this parameter is available
}

export interface ModelConfig {
  id: string;
  name: string;
  provider: ModelProvider;
  description: string;
  capabilities: ModelCapability[];
  parameters: ModelParameter[];
  maxImages: number;
  defaultSize: string;
  supportedSizes: string[];
  apiEndpoint: 'image' | 'responses' | 'gemini' | 'imagen' | 'fal';
  costTier: 'low' | 'medium' | 'high';
  avgLatency: 'fast' | 'medium' | 'slow';
}

export const MODEL_CONFIGS: Record<string, ModelConfig> = {
  'gpt-image-1': {
    id: 'gpt-image-1',
    name: 'GPT Image 1',
    provider: 'openai',
    description: 'Latest multimodal model with superior instruction following',
    capabilities: [
      'generation',
      'editing',
      'inpainting',
      'multi_turn',
      'transparent_background',
      'high_quality'
    ],
    parameters: [
      {
        name: 'quality',
        type: 'select',
        options: ['auto', 'low', 'medium', 'high'],
        default: 'auto',
        label: 'Quality',
        description: 'Image quality level'
      },
      {
        name: 'background',
        type: 'select',
        options: ['auto', 'transparent', 'opaque'],
        default: 'auto',
        label: 'Background',
        description: 'Background type'
      }
    ],
    maxImages: 10,
    defaultSize: '1024x1024',
    supportedSizes: ['1024x1024', '1536x1024', '1024x1536'],
    apiEndpoint: 'image',
    costTier: 'high',
    avgLatency: 'medium'
  },

  'dall-e-3': {
    id: 'dall-e-3',
    name: 'DALL-E 3',
    provider: 'openai',
    description: 'High-quality image generation with improved prompt understanding',
    capabilities: ['generation', 'high_quality'],
    parameters: [
      {
        name: 'quality',
        type: 'select',
        options: ['standard', 'hd'],
        default: 'standard',
        label: 'Quality',
        description: 'Image quality level'
      },
      {
        name: 'style',
        type: 'select',
        options: ['vivid', 'natural'],
        default: 'vivid',
        label: 'Style',
        description: 'Image style'
      }
    ],
    maxImages: 1,
    defaultSize: '1024x1024',
    supportedSizes: ['1024x1024', '1024x1792', '1792x1024'],
    apiEndpoint: 'image',
    costTier: 'medium',
    avgLatency: 'medium'
  },

  'dall-e-2': {
    id: 'dall-e-2',
    name: 'DALL-E 2',
    provider: 'openai',
    description: 'Lower cost option with editing and variations support',
    capabilities: ['generation', 'editing', 'inpainting', 'variations'],
    parameters: [],
    maxImages: 10,
    defaultSize: '1024x1024',
    supportedSizes: ['256x256', '512x512', '1024x1024'],
    apiEndpoint: 'image',
    costTier: 'low',
    avgLatency: 'fast'
  },

  'imagen-3.0-generate-002': {
    id: 'imagen-3.0-generate-002',
    name: 'Imagen 3',
    provider: 'google',
    description: 'Google\'s flagship image generation model with photorealistic quality',
    capabilities: ['generation', 'high_quality', 'aspect_ratios'],
    parameters: [
      {
        name: 'aspectRatio',
        type: 'select',
        options: ['1:1', '3:4', '4:3', '9:16', '16:9'],
        default: '1:1',
        label: 'Aspect Ratio',
        description: 'Image aspect ratio'
      }
    ],
    maxImages: 4,
    defaultSize: '1024x1024',
    supportedSizes: ['1024x1024'],
    apiEndpoint: 'imagen',
    costTier: 'medium',
    avgLatency: 'medium'
  },

  'imagen-3.0-fast-generate-001': {
    id: 'imagen-3.0-fast-generate-001',
    name: 'Imagen 3 Fast',
    provider: 'google',
    description: 'Faster version of Imagen 3 with slightly lower quality',
    capabilities: ['generation', 'aspect_ratios'],
    parameters: [
      {
        name: 'aspectRatio',
        type: 'select',
        options: ['1:1', '3:4', '4:3', '9:16', '16:9'],
        default: '1:1',
        label: 'Aspect Ratio',
        description: 'Image aspect ratio'
      }
    ],
    maxImages: 4,
    defaultSize: '1024x1024',
    supportedSizes: ['1024x1024'],
    apiEndpoint: 'imagen',
    costTier: 'low',
    avgLatency: 'fast'
  },

  'gemini-2.0-flash-preview-image-generation': {
    id: 'gemini-2.0-flash-preview-image-generation',
    name: 'Gemini 2.0 Flash',
    provider: 'google',
    description: 'Multimodal model that can generate images as part of conversations',
    capabilities: ['generation', 'editing', 'multi_turn'],
    parameters: [],
    maxImages: 4,
    defaultSize: '1024x1024',
    supportedSizes: ['1024x1024'],
    apiEndpoint: 'gemini',
    costTier: 'medium',
    avgLatency: 'fast'
  },

  'flux-kontext-auto': {
    id: 'flux-kontext-auto',
    name: 'FLUX.1 Kontext Pro',
    provider: 'fal',
    description: 'Intelligent FLUX model that switches between text-to-image generation, single image editing, and multi-image editing based on context',
    capabilities: ['generation', 'editing', 'high_quality', 'aspect_ratios'],
    parameters: [
      {
        name: 'guidance_scale',
        type: 'number',
        default: 3.5,
        label: 'Guidance Scale',
        description: 'How closely the model should follow your prompt (1-20)'
      },
      {
        name: 'aspect_ratio',
        type: 'select',
        options: ['21:9', '16:9', '4:3', '3:2', '1:1', '2:3', '3:4', '9:16', '9:21'],
        default: '1:1',
        label: 'Aspect Ratio',
        description: 'Image aspect ratio'
      },
      {
        name: 'seed',
        type: 'number',
        label: 'Seed',
        description: 'Random seed for reproducible results (optional)'
      }
    ],
    maxImages: 10, // Increased to support multi-image editing
    defaultSize: '1024x1024',
    supportedSizes: ['1024x1024'],
    apiEndpoint: 'fal',
    costTier: 'high',
    avgLatency: 'medium'
  }
};

// Helper functions
export function getModelConfig(modelId: string): ModelConfig | undefined {
  return MODEL_CONFIGS[modelId];
}

export function getModelsByProvider(provider: ModelProvider): ModelConfig[] {
  return Object.values(MODEL_CONFIGS).filter(model => model.provider === provider);
}

export function getModelsWithCapability(capability: ModelCapability): ModelConfig[] {
  return Object.values(MODEL_CONFIGS).filter(model =>
    model.capabilities.includes(capability)
  );
}

export function getAvailableParameters(modelId: string, currentParams: Record<string, any> = {}): ModelParameter[] {
  const config = getModelConfig(modelId);
  if (!config) return [];

  return config.parameters.filter(param => {
    if (!param.enabledWhen) return true;

    // Check if all enabledWhen conditions are met
    return Object.entries(param.enabledWhen).every(([key, value]) =>
      currentParams[key] === value
    );
  });
}

export function validateModelParameters(modelId: string, params: Record<string, any>): { valid: boolean; errors: string[] } {
  const config = getModelConfig(modelId);
  if (!config) return { valid: false, errors: ['Unknown model'] };

  const errors: string[] = [];
  const availableParams = getAvailableParameters(modelId, params);

  // Check if number of images exceeds model limit
  if (params.n && params.n > config.maxImages) {
    errors.push(`Model ${config.name} supports maximum ${config.maxImages} images`);
  }

  // Check if size is supported
  if (params.size && !config.supportedSizes.includes(params.size)) {
    errors.push(`Model ${config.name} doesn't support size ${params.size}`);
  }

  // Validate parameter values
  availableParams.forEach(paramConfig => {
    const value = params[paramConfig.name];
    if (value !== undefined && paramConfig.options) {
      if (!paramConfig.options.includes(value)) {
        errors.push(`Invalid value '${value}' for parameter '${paramConfig.label}'`);
      }
    }
  });

  return { valid: errors.length === 0, errors };
} 