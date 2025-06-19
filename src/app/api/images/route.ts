import { NextResponse } from 'next/server'

export async function GET() {
  return NextResponse.json({ 
    images: [
      { id: 1, name: 'Image 1', url: '/hitslop.png' },
      { id: 2, name: 'Image 2', url: '/hitslop.png' }
    ]
  })
}

export async function POST(request: Request) {
  try {
    const body = await request.json()
    
    // Placeholder for actual image generation logic
    return NextResponse.json({ 
      success: true, 
      message: 'Image generated successfully',
      imageUrl: '/hitslop.png',
      prompt: body.prompt || 'Default prompt' 
    })
  } catch (error) {
    return NextResponse.json(
      { error: 'Failed to generate image' },
      { status: 500 }
    )
  }
}