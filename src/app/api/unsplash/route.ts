import { NextRequest, NextResponse } from 'next/server';
import { createApi } from 'unsplash-js';
import nodeFetch from 'node-fetch';

// Initialize Unsplash client
const unsplashApi = createApi({
  accessKey: process.env.UNSPLASH_ACCESS_KEY || '',
  fetch: nodeFetch as unknown as typeof fetch,
});

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams;
    const query = searchParams.get('query');
    const page = parseInt(searchParams.get('page') || '1');
    const per_page = parseInt(searchParams.get('per_page') || '12');
    const photoId = searchParams.get('photoId');
    const downloadLocation = searchParams.get('downloadLocation');
    const random = searchParams.get('random') === 'true';

    if (!process.env.UNSPLASH_ACCESS_KEY) {
      return NextResponse.json(
        { error: 'Unsplash API key not configured' },
        { status: 500 }
      );
    }

    // Handle tracking download
    if (downloadLocation) {
      const downloadResponse = await unsplashApi.photos.trackDownload({
        downloadLocation: downloadLocation,
      });
      
      if (downloadResponse.errors) {
        console.error('Unsplash download tracking error:', downloadResponse.errors);
        return NextResponse.json(
          { error: downloadResponse.errors[0] },
          { status: 500 }
        );
      }
      
      return NextResponse.json({ success: true });
    }

    // Handle photo detail request
    if (photoId) {
      const photoResponse = await unsplashApi.photos.get({ photoId });
      
      if (photoResponse.errors) {
        console.error('Unsplash photo fetch error:', photoResponse.errors);
        return NextResponse.json(
          { error: photoResponse.errors[0] },
          { status: 500 }
        );
      }
      
      return NextResponse.json(photoResponse.response);
    }

    // Handle different types of photo requests
    let response;

    if (random) {
      // Get random photos
      response = await unsplashApi.photos.getRandom({
        count: per_page,
        // Optional filters
        orientation: 'landscape',
      });
    } else if (query && query.trim() !== '') {
      // Search for photos with query
      response = await unsplashApi.search.getPhotos({
        query: query.trim(),
        page,
        perPage: per_page,
      });
    } else {
      // Get photos list when no query and not random
      response = await unsplashApi.photos.list({
        page,
        perPage: per_page,
      });
    }

    if (response.errors) {
      console.error('Unsplash API errors:', response.errors);
      return NextResponse.json(
        { error: response.errors[0] },
        { status: 500 }
      );
    }

    // Format response for consistent handling in the frontend
    if (random) {
      // When using getRandom with count parameter, the response is an array of photos
      // But we need to format it like other responses for consistent handling
      return NextResponse.json({
        results: response.response,
        // No pagination info for random photos
        total_pages: 1
      });
    }

    return NextResponse.json(response.response);
  } catch (error) {
    console.error('Unsplash API error:', error);
    return NextResponse.json(
      { error: 'Failed to fetch photos from Unsplash' },
      { status: 500 }
    );
  }
}