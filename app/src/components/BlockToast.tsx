'use client';

import React, { useEffect, useState } from 'react';
import { Alert, Snackbar, Typography, Box } from '@mui/material';
import { connectWS, extractShipmentWrites } from '@/src/lib/ws';
import { BlockchainWrite } from '@/src/types/shipment';

export default function BlockToast() {
  const [open, setOpen] = useState(false);
  const [blockNumber, setBlockNumber] = useState<number | null>(null);
  const [shipmentIds, setShipmentIds] = useState<string[]>([]);

  useEffect(() => {
    // Connect to WebSocket and listen for block events
    connectWS((event) => {
      try {
        const blockData = JSON.parse(event.data);
        
        // Extract block number
        const number = blockData?.header?.number;
        if (number) {
          setBlockNumber(number);
          
          // Extract shipment IDs from write set
          const writes = extractShipmentWrites(blockData);
          if (writes.length > 0) {
            setShipmentIds(writes.map((w: BlockchainWrite) => w.key));
          } else {
            setShipmentIds([]);
          }
          
          // Show notification
          setOpen(true);
        }
      } catch (error) {
        console.error('Error processing WebSocket message:', error);
      }
    });
    
    return () => {
      // Clean up WebSocket connection (handled by ws.ts)
    };
  }, []);

  // Close notification after 4 seconds
  const handleClose = () => {
    setOpen(false);
  };

  return (
    <Snackbar
      open={open}
      autoHideDuration={4000}
      onClose={handleClose}
      anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
    >
      <Alert 
        severity="info" 
        variant="filled"
        sx={{ 
          width: '100%',
          backgroundColor: '#2196f3',
          color: 'white'
        }}
      >
        <Box>
          <Typography variant="subtitle1" sx={{ fontWeight: 'bold' }}>
            New Block #{blockNumber} Committed
          </Typography>
          {shipmentIds.length > 0 && (
            <Typography variant="body2">
              Affected shipments: {shipmentIds.join(', ')}
            </Typography>
          )}
        </Box>
      </Alert>
    </Snackbar>
  );
}