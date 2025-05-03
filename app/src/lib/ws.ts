'use client';

import { BlockchainWrite } from '@/src/types/shipment';

let socket: WebSocket | null = null;

export const connectWS = (cb: (evt: MessageEvent) => void) => {
  if (socket) {
    return socket;
  }

  const wsUrl = process.env.NEXT_PUBLIC_WS_URL || 'ws://localhost:3001/ws';
  socket = new WebSocket(wsUrl);

  socket.onopen = () => {
    console.log('WebSocket connected');
  };

  socket.onclose = () => {
    console.log('WebSocket disconnected');
    socket = null;
  };

  socket.onerror = (error) => {
    console.error('WebSocket error:', error);
  };

  socket.onmessage = cb;

  return socket;
};

export const closeWS = () => {
  if (socket) {
    socket.close();
    socket = null;
  }
};

// Helper to detect write events in block data
export const extractShipmentWrites = (blockData: any): BlockchainWrite[] => {
  try {
    if (!blockData?.block?.data?.data) {
      return [];
    }

    return blockData.block.data.data
      .flatMap((tx: any) => 
        (tx.payload?.data?.actions || []).flatMap((action: any) => 
          action.payload?.action?.proposal_response_payload?.extension?.results?.ns_rwset || []
        )
      )
      .filter((rwset: any) => rwset.namespace === 'shipping')
      .flatMap((rwset: any) => rwset.rwset?.writes || [])
      .filter((write: any) => write.key.startsWith('SHIP'));
  } catch (error) {
    console.error('Error parsing block data:', error);
    return [];
  }
};