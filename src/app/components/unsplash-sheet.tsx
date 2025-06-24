import React from 'react';
import { useState, useEffect, useCallback } from 'react';
import { useReactFlow } from '@xyflow/react';
import { Search, Loader2, ExternalLink, Shuffle } from 'lucide-react';
import { Masonry } from 'masonic';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from '@/app/components/ui/sheet';
import { Input } from '@/app/components/ui/input';
import { Button } from '@/app/components/ui/button';
import { createImageNode } from '@/app/lib/utils';
import { imageService } from '@/app/services/database';
import { useNodePlacement } from '@/app/lib/useNodePlacement';

interface UnsplashPhoto {
  id: string;
  width: number;
  height: number;
  urls: {
    raw: string;
    full: string;
    regular: string;
    small: string;
    thumb: string;
  };
  user: {
    name: string;
    links: {
      html: string;
    };
    username: string;
  };
  alt_description: string;
  description: string;
  links: {
    download_location: string;
    html: string;
  };
}

// Extended photo with onSelect handler
interface EnhancedUnsplashPhoto extends UnsplashPhoto {
  onSelect: (_photo: UnsplashPhoto) => void;
}

interface UnsplashResponse {
  results?: UnsplashPhoto[];
  total?: number;
  total_pages?: number;
}

interface UnsplashSheetProps {
  isOpen: boolean;
  onOpenChange: (_open: boolean) => void;
  setNodesToFocus: (_nodeId: string | null) => void;
}

// Masonry photo card component
const PhotoCard = ({
  data,
  width,
}: {
  data: EnhancedUnsplashPhoto;
  width: number;
}) => {
  const APP_NAME = 'hitslop';
  const aspectRatio = data.height / data.width;
  const cardHeight = width * aspectRatio;

  return (
    <div
      className="group relative bg-gray-100 rounded-lg overflow-hidden cursor-pointer hover:ring-2 hover:ring-blue-500 transition-all mb-2"
      style={{ height: cardHeight }}
      onClick={() => data.onSelect(data)}
    >
      <img
        src={data.urls.small}
        alt={data.alt_description || 'Unsplash photo'}
        className="w-full h-full object-cover"
        loading="lazy"
      />
      <div className="absolute inset-0 bg-black/0 group-hover:bg-black/10 transition-colors" />
      <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/60 to-transparent p-2 opacity-0 group-hover:opacity-100 transition-opacity">
        <p className="text-white text-xs truncate">
          by{' '}
          <a
            href={`${data.user.links.html}?utm_source=${APP_NAME}&utm_medium=referral`}
            target="_blank"
            rel="noopener noreferrer"
            onClick={(e) => e.stopPropagation()}
            className="hover:underline"
          >
            {data.user.name}
          </a>{' '}
          on{' '}
          <a
            href={`https://unsplash.com/?utm_source=${APP_NAME}&utm_medium=referral`}
            target="_blank"
            rel="noopener noreferrer"
            onClick={(e) => e.stopPropagation()}
            className="hover:underline"
          >
            Unsplash
          </a>
        </p>
      </div>
    </div>
  );
};

export function UnsplashSheet({
  isOpen,
  onOpenChange,
  setNodesToFocus,
}: UnsplashSheetProps) {
  const { setNodes, screenToFlowPosition } = useReactFlow();
  const { findNonOverlappingPosition } = useNodePlacement();
  const [searchQuery, setSearchQuery] = useState('');
  const [photos, setPhotos] = useState<EnhancedUnsplashPhoto[]>([]);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [isRandom, setIsRandom] = useState(true); // Default to random photos
  const APP_NAME = 'hitslop';

  const fetchPhotos = useCallback(
    async (
      query: string,
      pageNum: number = 1,
      append: boolean = false,
      random: boolean = false,
    ) => {
      setLoading(true);
      try {
        const params = new URLSearchParams({
          page: pageNum.toString(),
          per_page: '20', // Increased to get more photos per page
        });

        if (random) {
          params.set('random', 'true');
        } else if (query.trim()) {
          params.set('query', query.trim());
        }

        const response = await fetch(`/api/unsplash?${params}`);
        const data: UnsplashResponse = await response.json();

        if (response.ok) {
          // Handle both search results and list response formats
          const fetchedPhotos =
            data.results || (data as unknown as UnsplashPhoto[]);

          if (Array.isArray(fetchedPhotos)) {
            // Add the onSelect handler to each photo
            const photosWithHandlers = fetchedPhotos.map((photo) => ({
              ...photo,
              onSelect: handlePhotoSelect,
            })) as EnhancedUnsplashPhoto[];

            if (append) {
              setPhotos((prev) => [...prev, ...photosWithHandlers]);
            } else {
              setPhotos(photosWithHandlers);
            }

            // Check if there are more pages
            if (data.total_pages) {
              setHasMore(pageNum < data.total_pages);
            } else {
              // If no total_pages info, assume there's more if we got a full page
              setHasMore(fetchedPhotos.length === 20);
            }

            // Random photos don't support pagination
            if (random) {
              setHasMore(false);
            }
          } else {
            console.error('Unexpected response format:', data);
            setPhotos([]);
            setHasMore(false);
          }
        } else {
          console.error('Failed to fetch photos:', data);
          setPhotos([]);
          setHasMore(false);
        }
      } catch (error) {
        console.error('Error fetching photos:', error);
        setPhotos([]);
        setHasMore(false);
      } finally {
        setLoading(false);
      }
    },
    [],
  );

  // Load initial photos when sheet opens
  useEffect(() => {
    if (isOpen && photos.length === 0) {
      fetchPhotos('', 1, false, isRandom);
    }
  }, [isOpen, photos.length, fetchPhotos, isRandom]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setPage(1);
    setIsRandom(false); // Switch to search mode
    fetchPhotos(searchQuery, 1, false, false);
  };

  const loadMore = () => {
    const nextPage = page + 1;
    setPage(nextPage);
    fetchPhotos(searchQuery, nextPage, true, false);
  };

  const handleRandomize = () => {
    setSearchQuery('');
    setIsRandom(true);
    setPage(1);
    fetchPhotos('', 1, false, true);
  };

  // Track download when a photo is selected
  const trackPhotoDownload = async (downloadLocation: string) => {
    try {
      const response = await fetch(
        `/api/unsplash?downloadLocation=${encodeURIComponent(
          downloadLocation,
        )}`,
      );
      if (!response.ok) {
        console.error('Failed to track download:', await response.json());
      }
    } catch (error) {
      console.error('Error tracking download:', error);
    }
  };

  const handlePhotoSelect = async (photo: UnsplashPhoto) => {
    try {
      // Track the download with Unsplash
      if (photo.links?.download_location) {
        await trackPhotoDownload(photo.links.download_location);
      }

      // Store the image in our database and get the imageId
      const imageId = await imageService.storeImage(
        photo.urls.regular,
        'unsplash',
        {
          width: photo.width,
          height: photo.height,
          tags: [
            photo.user.name,
            'unsplash',
            // Add these tags to carry the metadata we need
            `source:Unsplash`,
            `sourceUrl:${
              photo.links.html || `https://unsplash.com/photos/${photo.id}`
            }`,
            `author:${photo.user.name}`,
            `authorUrl:${photo.user.links.html}`,
          ],
        },
      );

      // Get the center of the current viewport
      const centerPosition = screenToFlowPosition({
        x: window.innerWidth / 2,
        y: window.innerHeight / 2,
      });

      // Find a non-overlapping position for the new node
      const nonOverlappingPosition = findNonOverlappingPosition(
        centerPosition,
        'image-node',
      );

      // Create a new image node using the stored image ID
      const newNode = await createImageNode(imageId, {
        position: nonOverlappingPosition,
        source: 'unsplash',
        photographer: photo.user.name,
        photographer_url: photo.user.links.html,
        alt: photo.alt_description || photo.description || 'Unsplash photo',
        attribution: {
          service: 'Unsplash',
          serviceUrl: `https://unsplash.com/?utm_source=${APP_NAME}&utm_medium=referral`,
          creator: photo.user.name,
          creatorUrl: `${photo.user.links.html}?utm_source=${APP_NAME}&utm_medium=referral`,
          photoUrl: `${photo.links.html}?utm_source=${APP_NAME}&utm_medium=referral`,
        },
      });

      // Add the new node to the flow
      setNodes((nds) => [...nds, newNode]);

      // Set the node to focus once it's initialized
      setNodesToFocus(newNode.id);

      // Close the sheet
      onOpenChange(false);
    } catch (error) {
      console.error('Failed to add image:', error);
    }
  };

  return (
    <Sheet open={isOpen} onOpenChange={onOpenChange}>
      <SheetContent
        side="left"
        className="sm:max-w-md md:max-w-lg lg:max-w-xl xl:max-w-2xl overflow-hidden p-0"
      >
        <SheetHeader className="px-4 py-3 border-b">
          <SheetTitle className="flex items-center gap-2">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 32 32"
              className="w-5 h-5"
              fill="currentColor"
            >
              <path d="M10 9V0h12v9H10zm12 5h10v18H0V14h10v9h12v-9z" />
            </svg>
            Unsplash Photos
          </SheetTitle>
        </SheetHeader>

        <div className="flex flex-col h-full">
          {/* Search Bar */}
          <div className="p-3 border-b">
            <div className="flex gap-2 mb-2">
              <div className="relative flex-grow">
                <form onSubmit={handleSearch} className="flex gap-2">
                  <div className="relative flex-grow">
                    <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground w-4 h-4" />
                    <Input
                      placeholder="Search photos..."
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                      className="pl-10"
                    />
                  </div>
                  <Button type="submit" size="sm" disabled={loading}>
                    {loading ? (
                      <Loader2 className="w-4 h-4 animate-spin" />
                    ) : (
                      'Search'
                    )}
                  </Button>
                </form>
              </div>
            </div>
            <div className="flex justify-between items-center">
              <Button
                onClick={handleRandomize}
                variant="outline"
                size="sm"
                className="text-xs flex items-center"
                disabled={loading}
              >
                <Shuffle className="w-3 h-3 mr-1" />
                Random Photos
              </Button>
              {isRandom && (
                <span className="text-xs text-muted-foreground">
                  Showing random photos
                </span>
              )}
            </div>
          </div>

          {/* Photo Grid */}
          <div className="flex-1 overflow-y-auto px-3">
            {loading && photos.length === 0 ? (
              <div className="flex items-center justify-center h-32">
                <Loader2 className="w-6 h-6 animate-spin" />
              </div>
            ) : (
              <div className="py-3">
                {photos.length > 0 && (
                  <Masonry
                    items={photos}
                    columnCount={3}
                    columnGutter={8}
                    render={PhotoCard}
                  />
                )}

                {/* Load More Button */}
                {hasMore && photos.length > 0 && (
                  <div className="mt-4 mb-4 text-center">
                    <Button
                      onClick={loadMore}
                      disabled={loading}
                      variant="outline"
                      size="sm"
                    >
                      {loading ? (
                        <>
                          <Loader2 className="w-4 h-4 animate-spin mr-2" />
                          Loading...
                        </>
                      ) : (
                        'Load More'
                      )}
                    </Button>
                  </div>
                )}

                {/* Random button for results view */}
                {!isRandom && photos.length > 0 && !hasMore && (
                  <div className="mt-2 mb-4 text-center">
                    <Button
                      onClick={handleRandomize}
                      variant="outline"
                      size="sm"
                      disabled={loading}
                    >
                      <Shuffle className="w-4 h-4 mr-2" />
                      Show Random Photos
                    </Button>
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Attribution Footer */}
          <div className="p-3 border-t bg-muted/30">
            <div className="flex items-center justify-center text-xs text-muted-foreground">
              <span>Photos provided by</span>
              <a
                href={`https://unsplash.com/?utm_source=${APP_NAME}&utm_medium=referral`}
                target="_blank"
                rel="noopener noreferrer"
                className="ml-1 flex items-center gap-1 hover:text-foreground"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 32 32"
                  className="w-3 h-3"
                  fill="currentColor"
                >
                  <path d="M10 9V0h12v9H10zm12 5h10v18H0V14h10v9h12v-9z" />
                </svg>
                Unsplash
                <ExternalLink className="w-3 h-3" />
              </a>
            </div>
          </div>
        </div>
      </SheetContent>
    </Sheet>
  );
}
