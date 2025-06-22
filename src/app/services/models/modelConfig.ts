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
  dependsOn?: string[];
  enabledWhen?: Record<string, any>;
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

// Common parameter definitions to reduce repetition
const QUALITY_PARAM: ModelParameter = {
  name: 'quality',
  type: 'select',
  options: ['auto', 'low', 'medium', 'high'],
  default: 'auto',
  label: 'Quality',
  description: 'Image quality level'
};

const ASPECT_RATIO_PARAM: ModelParameter = {
  name: 'aspectRatio',
  type: 'select',
  options: ['1:1', '3:4', '4:3', '9:16', '16:9'],
  default: '1:1',
  label: 'Aspect Ratio',
  description: 'Image aspect ratio'
};

const GUIDANCE_SCALE_PARAM: ModelParameter = {
  name: 'guidance_scale',
  type: 'number',
  default: 3.5,
  label: 'Guidance Scale',
  description: 'How closely the model should follow your prompt (1-20)'
};

const SEED_PARAM: ModelParameter = {
  name: 'seed',
  type: 'number',
  label: 'Seed',
  description: 'Random seed for reproducible results (optional)'
};

// Base configurations to reduce repetition
const BASE_OPENAI_CONFIG = {
  provider: 'openai' as ModelProvider,
  apiEndpoint: 'image' as const,
  defaultSize: '1024x1024',
  supportedSizes: ['1024x1024', '1536x1024', '1024x1536'],
};

const BASE_GOOGLE_CONFIG = {
  provider: 'google' as ModelProvider,
  apiEndpoint: 'imagen' as const,
  defaultSize: '1024x1024',
  supportedSizes: ['1024x1024'],
  maxImages: 4,
  avgLatency: 'medium' as const,
};

export const MODEL_CONFIGS: Record<string, ModelConfig> = {
  'gpt-image-1': {
    ...BASE_OPENAI_CONFIG,
    id: 'gpt-image-1',
    name: 'GPT Image 1',
    description: 'Latest multimodal model with superior instruction following',
    capabilities: ['generation', 'editing', 'inpainting', 'multi_turn', 'transparent_background', 'high_quality'],
    parameters: [
      QUALITY_PARAM,
      {
        name: 'background',
        type: 'select',
        options: ['auto', 'transparent', 'opaque'],
        default: 'opaque',
        label: 'Background',
        description: 'Background type'
      }
    ],
    maxImages: 10,
    costTier: 'high',
    avgLatency: 'medium'
  },

  'dall-e-3': {
    ...BASE_OPENAI_CONFIG,
    id: 'dall-e-3',
    name: 'DALL-E 3',
    description: 'High-quality image generation with improved prompt understanding',
    capabilities: ['generation', 'high_quality'],
    parameters: [
      { ...QUALITY_PARAM, options: ['standard', 'hd'], default: 'standard' },
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
    supportedSizes: ['1024x1024', '1024x1792', '1792x1024'],
    costTier: 'medium',
    avgLatency: 'medium'
  },

  'dall-e-2': {
    ...BASE_OPENAI_CONFIG,
    id: 'dall-e-2',
    name: 'DALL-E 2',
    description: 'Lower cost option with editing and variations support',
    capabilities: ['generation', 'editing', 'inpainting', 'variations'],
    parameters: [],
    maxImages: 10,
    supportedSizes: ['256x256', '512x512', '1024x1024'],
    costTier: 'low',
    avgLatency: 'fast'
  },

  'imagen-3.0-generate-002': {
    ...BASE_GOOGLE_CONFIG,
    id: 'imagen-3.0-generate-002',
    name: 'Imagen 3',
    description: 'Google\'s flagship image generation model with photorealistic quality',
    capabilities: ['generation', 'high_quality', 'aspect_ratios'],
    parameters: [ASPECT_RATIO_PARAM],
    costTier: 'medium'
  },

  'imagen-3.0-fast-generate-001': {
    ...BASE_GOOGLE_CONFIG,
    id: 'imagen-3.0-fast-generate-001',
    name: 'Imagen 3 Fast',
    description: 'Faster version of Imagen 3 with slightly lower quality',
    capabilities: ['generation', 'aspect_ratios'],
    parameters: [ASPECT_RATIO_PARAM],
    costTier: 'low',
    avgLatency: 'fast'
  },

  'gemini-2.0-flash-preview-image-generation': {
    ...BASE_GOOGLE_CONFIG,
    id: 'gemini-2.0-flash-preview-image-generation',
    name: 'Gemini 2.0 Flash',
    description: 'Multimodal model that can generate images as part of conversations',
    capabilities: ['generation', 'editing', 'multi_turn'],
    parameters: [],
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
      GUIDANCE_SCALE_PARAM,
      {
        name: 'aspect_ratio',
        type: 'select',
        options: ['21:9', '16:9', '4:3', '3:2', '1:1', '2:3', '3:4', '9:16', '9:21'],
        default: '1:1',
        label: 'Aspect Ratio',
        description: 'Image aspect ratio'
      },
      SEED_PARAM
    ],
    maxImages: 10,
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