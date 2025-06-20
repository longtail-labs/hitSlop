import { X, Play } from 'lucide-react';
import { Button } from '@/app/components/ui/button';

interface TutorialBoxProps {
  onDismiss: () => void;
  onPlayClick: () => void;
}

export function TutorialBox({ onDismiss, onPlayClick }: TutorialBoxProps) {
  return (
    <div className="fixed bottom-4 right-4 w-80 bg-white border border-gray-200 rounded-lg shadow-lg overflow-hidden z-50">
      {/* Close button */}
      <button
        onClick={onDismiss}
        className="absolute top-2 right-2 p-1 hover:bg-gray-100 rounded-full z-10"
        title="Dismiss tutorial"
      >
        <X className="h-4 w-4 text-gray-600" />
      </button>

      {/* Image with play button overlay */}
      <div
        className="relative bg-gray-100 h-48 flex items-center justify-center cursor-pointer"
        onClick={onPlayClick}
      >
        {/* Placeholder for tutorial image - you can replace with actual image */}
        <div className="absolute inset-0 bg-gradient-to-br from-blue-400 to-purple-600 opacity-20"></div>

        {/* Play button overlay */}
        <div className="relative z-10 bg-white bg-opacity-90 rounded-full p-4 hover:bg-opacity-100 transition-all duration-200 shadow-lg">
          <Play className="h-8 w-8 text-blue-600 ml-1" fill="currentColor" />
        </div>

        {/* Tutorial preview content */}
        <div className="absolute bottom-4 left-4 right-4 text-center">
          <div className="bg-black bg-opacity-50 text-white px-3 py-2 rounded text-sm">
            Quick Demo Preview
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="p-4">
        <h3 className="font-bold text-lg mb-2">See how it works</h3>
        <p className="text-gray-600 text-sm mb-3">
          Watch a quick tutorial to learn how to create and edit images with
          hitSlop
        </p>
        <Button onClick={onPlayClick} className="w-full" size="sm">
          <Play className="h-4 w-4 mr-2" />
          Watch Tutorial
        </Button>
      </div>
    </div>
  );
}