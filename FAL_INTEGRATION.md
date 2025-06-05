# FAL FLUX Integration

This project now supports FAL's FLUX models for advanced image generation and editing.

## Setup

1. **Get a FAL API Key**
   - Visit [fal.ai](https://fal.ai) and create an account
   - Generate an API key from your dashboard

2. **Add Your API Key**
   - Click the "Keys" button in the top-right corner of the app
   - Enter your FAL API key in the "FAL API Key" field
   - Click "Save Keys"

## Available Models

### FLUX.1 Kontext Pro
- **Type**: Smart Text-to-Image & Image Editing
- **Description**: Intelligent FLUX model that automatically switches between text-to-image generation and image editing based on whether you upload a source image
- **Behavior**: 
  - **Without source image**: Creates new images from text prompts
  - **With source image**: Edits the uploaded image based on your prompt
- **Parameters**:
  - **Guidance Scale** (1-20): How closely the model follows your prompt (default: 3.5)
  - **Aspect Ratio**: Various ratios from 21:9 to 9:21 (default: 1:1)
  - **Seed**: Random seed for reproducible results (optional)
- **Simplified Settings**: Uses PNG format and optimal safety settings automatically

## How to Use

### Simple Workflow with FLUX.1 Kontext Pro

**For Text-to-Image Generation:**
1. **Create a Prompt Node** (FLUX.1 Kontext Pro is now the default)
2. **Enter Your Prompt**: Describe the image you want
   - Example: "A futuristic city skyline at sunset with flying cars"
   - Example: "Portrait of a wise old wizard with a long beard, photorealistic"
3. **Adjust Parameters** (optional): Set aspect ratio, guidance scale, or seed
4. **Generate**: Click the play button (▶) to create your image

**For Image Editing:**
1. **Create a Prompt Node** and **upload a source image** using the upload icon (📁)
2. **Enter Your Edit Prompt**: Describe what you want to change
   - Example: "Add a red hat to the person" 
   - Example: "Change the background to a beach scene"
3. **Adjust Parameters** (optional): Fine-tune generation settings
4. **Generate**: The model automatically switches to edit mode and processes your changes

The model intelligently detects whether you have a source image and automatically uses the appropriate FLUX variant (text-to-image or image-to-image) behind the scenes.

## Tips for Best Results

- **Be Specific**: Clear, detailed prompts work better than vague descriptions
- **Context Matters**: FLUX Kontext understands the context of your image, so you don't need to describe everything in detail
- **Experiment with Guidance**: Try different guidance scale values to find the right balance
- **Source Image Quality**: Higher quality source images generally produce better results

## Troubleshooting

- **"FAL API key not found"**: Make sure you've added your API key in the Keys dialog
- **"Invalid FAL API key"**: Check that your API key is correct and has sufficient credits
- **"FAL API quota exceeded"**: You've reached your API limits, check your fal.ai account
- **Poor results**: Try adjusting the guidance scale - higher values make the model follow your prompt more closely

## Cost Considerations

FAL FLUX models are marked as "high cost" tier. Each generation uses credits from your FAL account. Monitor your usage on the fal.ai dashboard. 