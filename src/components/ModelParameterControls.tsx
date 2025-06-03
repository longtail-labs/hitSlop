import React from 'react';
import {
  getModelConfig,
  getAvailableParameters,
  ModelParameter,
  MODEL_CONFIGS,
} from '../services/models/modelConfig';
import type { ModelId } from '../services/imageGenerationService';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Button } from '@/components/ui/button';

interface ModelParameterControlsProps {
  modelId: ModelId;
  currentParams: Record<string, any>;
  onParameterChange: (_paramName: string, _value: any) => void;
  className?: string;
  showModelSelector?: boolean;
  selectedModel?: ModelId;
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  onModelChange?: (_model: ModelId) => void;
}

export function ModelParameterControls({
  modelId,
  currentParams,
  onParameterChange,
  className = '',
  showModelSelector = false,
  selectedModel,
  onModelChange,
}: ModelParameterControlsProps) {
  const modelConfig = getModelConfig(modelId);
  const availableParams = getAvailableParameters(modelId, currentParams);

  if (!modelConfig) {
    return null;
  }

  const renderParameter = (param: ModelParameter) => {
    const currentValue = currentParams[param.name] ?? param.default;

    if (param.type === 'boolean') {
      return (
        <div key={param.name} className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={currentValue}
            onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
              onParameterChange(param.name, e.target.checked)
            }
            id={param.name}
            className="w-4 h-4"
          />
          <label htmlFor={param.name} className="text-xs">
            {param.label}
          </label>
        </div>
      );
    }

    if (param.type === 'select' && param.options) {
      const formatValue = (value: string | number) => {
        if (typeof value === 'string') {
          return value.charAt(0).toUpperCase() + value.slice(1);
        }
        return value.toString();
      };

      return (
        <DropdownMenu key={param.name}>
          <DropdownMenuTrigger asChild>
            <Button
              variant="outline"
              size="sm"
              className="h-8 text-xs px-2 py-1 bg-muted border border-border min-w-20"
              title={param.description}
            >
              {formatValue(currentValue)}
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent>
            {param.options.map((option) => (
              <DropdownMenuItem
                key={option}
                onClick={() => onParameterChange(param.name, option)}
                className={currentValue === option ? 'bg-accent' : ''}
              >
                {formatValue(option)}
              </DropdownMenuItem>
            ))}
          </DropdownMenuContent>
        </DropdownMenu>
      );
    }

    return null;
  };

  // Always available parameters
  const sizeOptions = modelConfig.supportedSizes.map((size) => {
    if (size === '1024x1024') return '1024²';
    if (size === '1536x1024') return '1536×1024';
    if (size === '1024x1536') return '1024×1536';
    if (size === '1024x1792') return '1024×1792';
    if (size === '1792x1024') return '1792×1024';
    if (size === '256x256') return '256²';
    if (size === '512x512') return '512²';
    return size;
  });

  const currentSize = currentParams.size || modelConfig.defaultSize;
  const currentSizeLabel =
    sizeOptions[modelConfig.supportedSizes.indexOf(currentSize)] || currentSize;

  const maxImages = Math.min(modelConfig.maxImages, 9);
  const imageCountOptions = Array.from({ length: maxImages }, (_, i) => i + 1);

  // Check if model uses aspect ratio instead of specific sizes
  const usesAspectRatio = availableParams.some(
    (param) => param.name === 'aspectRatio',
  );

  return (
    <div className={`flex gap-2 flex-wrap ${className}`}>
      {/* Model Selection */}
      {showModelSelector && onModelChange && (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="outline"
              size="sm"
              className="h-8 text-xs px-2 py-1 bg-muted border border-border w-32"
            >
              {modelConfig?.name || 'Unknown Model'}
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent>
            {Object.values(MODEL_CONFIGS).map((config) => (
              <DropdownMenuItem
                key={config.id}
                onClick={() => onModelChange(config.id)}
                className={selectedModel === config.id ? 'bg-accent' : ''}
              >
                <div className="flex flex-col">
                  <span>{config.name}</span>
                  <span className="text-xs text-muted-foreground">
                    {config.provider}
                  </span>
                </div>
              </DropdownMenuItem>
            ))}
          </DropdownMenuContent>
        </DropdownMenu>
      )}

      {/* Size Control - only show if model doesn't use aspect ratio */}
      {!usesAspectRatio && (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="outline"
              size="sm"
              className="h-8 text-xs px-2 py-1 bg-muted border border-border w-24"
            >
              {currentSizeLabel}
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent>
            {modelConfig.supportedSizes.map((size, index) => (
              <DropdownMenuItem
                key={size}
                onClick={() => onParameterChange('size', size)}
                className={currentSize === size ? 'bg-accent' : ''}
              >
                {sizeOptions[index]}
              </DropdownMenuItem>
            ))}
          </DropdownMenuContent>
        </DropdownMenu>
      )}

      {/* Image Count Control */}
      {maxImages > 1 && (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="outline"
              size="sm"
              className="h-8 text-xs px-2 py-1 bg-muted border border-border w-20"
            >
              {currentParams.n || 1}{' '}
              {(currentParams.n || 1) === 1 ? 'img' : 'imgs'}
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent>
            {imageCountOptions.map((num) => (
              <DropdownMenuItem
                key={num}
                onClick={() => onParameterChange('n', num)}
                className={(currentParams.n || 1) === num ? 'bg-accent' : ''}
              >
                {num} {num === 1 ? 'img' : 'imgs'}
              </DropdownMenuItem>
            ))}
          </DropdownMenuContent>
        </DropdownMenu>
      )}

      {/* Model-specific parameters */}
      {availableParams.map(renderParameter)}
    </div>
  );
}
