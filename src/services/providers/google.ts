import { GoogleGenAI } from '@google/genai';
import { apiKeyService } from '../database';

export interface GoogleImageParams {
  prompt: string;
  model?: 'imagen-3.0-generate-002' | 'gemini-2.0-flash-preview-image-generation';
  size?: '1024x1024' | '1536x1024' | '1024x1536';
  n?: number;
}

export interface ImageResult {
  success: boolean;
  imageUrls?: string[];
  error?: string;
  revisedPrompt?: string;
}

// Initialize Google Gen AI client with placeholder - will be set dynamically
let googleAI: GoogleGenAI | null = null;

async function getGoogleClient(): Promise<GoogleGenAI | null> {
  if (!googleAI) {
    const apiKey = await apiKeyService.getApiKey('google');
    if (!apiKey) {
      return null;
    }
    googleAI = new GoogleGenAI({ vertexai: false, apiKey });
  }
  return googleAI;
}

// Reset client when API key changes
export function resetGoogleClient() {
  googleAI = null;
}

/**
 * Generate images using Google's Gen AI models
 */
export const generateWithGoogle = async (params: GoogleImageParams): Promise<ImageResult> => {
  try {
    const client = await getGoogleClient();
    if (!client) {
      return {
        success: false,
        error: 'Google API key is not configured. Please set up your API key in settings.'
      };
    }

    const { prompt, model = 'imagen-3.0-generate-002', n = 1 } = params;

    try {
      // Use Imagen for dedicated image generation
      if (model.startsWith('imagen')) {
        const response = await client.models.generateImages({
          model,
          prompt,
          config: {
            numberOfImages: n
          }
        });

        if (!response.generatedImages?.length) {
          return {
            success: false,
            error: 'No images were generated'
          };
        }

        // Extract image URLs from response
        const imageUrls = response.generatedImages
          .filter(img => img.image?.imageBytes) // Filter out any images without bytes
          .map(img => `data:image/png;base64,${img.image!.imageBytes}`); // Non-null assertion since we filtered

        if (!imageUrls.length) {
          return {
            success: false,
            error: 'Generated images contained no valid image data'
          };
        }

        return {
          success: true,
          imageUrls
        };

      } else {
        // Use Gemini for multimodal generation
        const response = await client.models.generateContent({
          model,
          contents: prompt,
          config: {
            responseModalities: ['TEXT', 'IMAGE']
          }
        });

        if (!response.candidates?.[0]?.content?.parts) {
          return {
            success: false,
            error: 'No content was generated'
          };
        }

        // Extract image data from parts
        const imageUrls = response.candidates[0].content.parts
          .filter(part => part.inlineData?.data) // Filter out parts without image data
          .map(part => `data:image/png;base64,${part.inlineData!.data}`); // Non-null assertion since we filtered

        if (!imageUrls.length) {
          return {
            success: false,
            error: 'Generated content contained no valid image data'
          };
        }

        return {
          success: true,
          imageUrls
        };
      }

    } catch (error) {
      console.error('Google image generation error:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown Google API error'
      };
    }
  } catch (error) {
    console.error('Google Gen AI error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown Google API error'
    };
  }
};