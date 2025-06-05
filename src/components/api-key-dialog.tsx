import React, { useState, useEffect } from 'react';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { apiKeyService } from '@/services/database';
import { resetOpenAIClient } from '@/services/providers/openai';
import { resetGoogleClient } from '@/services/providers/google';
import { resetFalClient } from '@/services/providers/fal';

interface ApiKeyDialogProps {
  open?: boolean;
  onOpenChange?: (open: boolean) => void;
  trigger?: React.ReactNode;
}

export function ApiKeyDialog({
  open,
  onOpenChange,
  trigger,
}: ApiKeyDialogProps) {
  const [openaiKey, setOpenaiKey] = useState('');
  const [googleKey, setGoogleKey] = useState('');
  const [falKey, setFalKey] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isLoadingKeys, setIsLoadingKeys] = useState(true);

  useEffect(() => {
    if (open) {
      loadExistingKeys();
    }
  }, [open]);

  const loadExistingKeys = async () => {
    setIsLoadingKeys(true);
    try {
      const keys = await apiKeyService.getAllApiKeys();
      setOpenaiKey(keys.openai || '');
      setGoogleKey(keys.google || '');
      setFalKey(keys.fal || '');
    } catch (error) {
      console.error('Failed to load API keys:', error);
    } finally {
      setIsLoadingKeys(false);
    }
  };

  const handleSave = async () => {
    setIsLoading(true);
    try {
      if (openaiKey.trim()) {
        await apiKeyService.saveApiKey('openai', openaiKey.trim());
        resetOpenAIClient();
      } else {
        await apiKeyService.deleteApiKey('openai');
      }

      if (googleKey.trim()) {
        await apiKeyService.saveApiKey('google', googleKey.trim());
        resetGoogleClient();
      } else {
        await apiKeyService.deleteApiKey('google');
      }

      if (falKey.trim()) {
        await apiKeyService.saveApiKey('fal', falKey.trim());
        resetFalClient();
      } else {
        await apiKeyService.deleteApiKey('fal');
      }

      onOpenChange?.(false);
    } catch (error) {
      console.error('Failed to save API keys:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const content = (
    <DialogContent className="sm:max-w-md">
      <DialogHeader>
        <DialogTitle>API Keys Configuration</DialogTitle>
        <DialogDescription>
          Enter your API keys for the different providers. Keys are stored
          locally and securely.
        </DialogDescription>
      </DialogHeader>
      <div className="grid gap-4 py-4">
        <div className="grid gap-2">
          <Label htmlFor="openai-key">OpenAI API Key</Label>
          <Input
            id="openai-key"
            type="password"
            placeholder="sk-..."
            value={openaiKey}
            onChange={(e) => setOpenaiKey(e.target.value)}
            disabled={isLoadingKeys}
          />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="google-key">Google API Key</Label>
          <Input
            id="google-key"
            type="password"
            placeholder="Enter Google API key"
            value={googleKey}
            onChange={(e) => setGoogleKey(e.target.value)}
            disabled={isLoadingKeys}
          />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="fal-key">FAL API Key</Label>
          <Input
            id="fal-key"
            type="password"
            placeholder="Enter FAL API key"
            value={falKey}
            onChange={(e) => setFalKey(e.target.value)}
            disabled={isLoadingKeys}
          />
        </div>
      </div>
      <DialogFooter>
        <Button onClick={handleSave} disabled={isLoading || isLoadingKeys}>
          {isLoading ? 'Saving...' : 'Save Keys'}
        </Button>
      </DialogFooter>
    </DialogContent>
  );

  if (trigger) {
    return (
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogTrigger asChild>{trigger}</DialogTrigger>
        {content}
      </Dialog>
    );
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      {content}
    </Dialog>
  );
}
