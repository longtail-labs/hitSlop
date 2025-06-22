import React from 'react';
import { NodeToolbar, Position } from '@xyflow/react';
import {
  Menubar,
  MenubarMenu,
  MenubarTrigger,
} from '@/app/components/ui/menubar';
import { Copy, Download, Edit3, Trash2 } from 'lucide-react';

interface ImageNodeToolbarProps {
  isVisible: boolean;
  onDuplicate: () => void;
  onDownload: () => void;
  onEdit: (_event: React.MouseEvent) => void;
  onDelete: () => void;
}

export const ImageNodeToolbar: React.FC<ImageNodeToolbarProps> = ({
  isVisible,
  onDuplicate,
  onDownload,
  onEdit,
  onDelete,
}) => {
  return (
    <NodeToolbar isVisible={isVisible} position={Position.Top} offset={10}>
      <Menubar>
        <MenubarMenu>
          <MenubarTrigger
            className="px-2 py-1 gap-1 text-xs font-recursive"
            onClick={onDuplicate}
            style={{
              fontVariationSettings: '"MONO" 0.8, "wght" 500, "CASL" 0.2',
            }}
          >
            <Copy size={12} />
            Duplicate
          </MenubarTrigger>
        </MenubarMenu>
        <MenubarMenu>
          <MenubarTrigger
            className="px-2 py-1 gap-1 text-xs font-recursive"
            onClick={onDownload}
            style={{
              fontVariationSettings: '"MONO" 0.8, "wght" 500, "CASL" 0.2',
            }}
          >
            <Download size={12} />
            Download
          </MenubarTrigger>
        </MenubarMenu>
        <MenubarMenu>
          <MenubarTrigger
            className="px-2 py-1 gap-1 text-xs font-recursive"
            onClick={onEdit}
            style={{
              fontVariationSettings: '"MONO" 0.8, "wght" 500, "CASL" 0.2',
            }}
          >
            <Edit3 size={12} />
            Edit
          </MenubarTrigger>
        </MenubarMenu>
        <MenubarMenu>
          <MenubarTrigger
            className="px-2 py-1 gap-1 text-xs font-recursive text-destructive hover:bg-destructive/10 focus:bg-destructive/10 focus:text-destructive"
            onClick={onDelete}
            style={{
              fontVariationSettings: '"MONO" 0.8, "wght" 500, "CASL" 0.2',
            }}
          >
            <Trash2 size={12} />
            Delete
          </MenubarTrigger>
        </MenubarMenu>
      </Menubar>
    </NodeToolbar>
  );
};
