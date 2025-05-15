'use client';

import React, { useEffect, useState } from 'react';
import { Container, Box } from '@mui/material';
import ShipmentsGrid from '@/src/components/ShipmentsGrid';
import BlockToast from '@/src/components/BlockToast';
import { Shipment, BlockchainWrite } from '@/src/types/shipment';
import { connectWS, extractShipmentWrites } from '@/src/lib/ws';

export default function Home() {
  const [shipments, setShipments] = useState<Shipment[]>([]);
  const [loading, setLoading] = useState(true);
  const [flashItem, setFlashItem] = useState<string | null>(null);

  // Fetch shipments on component mount
  useEffect(() => {
    fetchShipments();
    
    // Setup WebSocket connection for real-time updates
    connectWS((event) => {
      try {
        const blockData = JSON.parse(event.data);
        const writes = extractShipmentWrites(blockData);

        console.log("IN USE EFFECT HERE")
        
        if (writes.length > 0) {
          console.log("Detected, now gonna fetch")
          // If we detect changes to shipments, refresh the list
          fetchShipments();
          
          // Extract shipment IDs for animation
          const shipmentIds = writes.map((w: BlockchainWrite) => w.key);
          if (shipmentIds.length > 0) {
            setFlashItem(shipmentIds[0]);
          }
        }
      } catch (error) {
        console.error('Error processing WebSocket message:', error);
      }
    });
  }, []);

  // Fetch shipments from API
  const fetchShipments = async () => {
    try {
      setLoading(true);
      const response = await fetch('/api/shipment');
      if (!response.ok) {
        throw new Error('Failed to fetch shipments');
      }
      const data = await response.json();
      setShipments(data || []);
    } catch (error) {
      console.error('Error fetching shipments:', error);
    } finally {
      setLoading(false);
    }
  };

  // Handle shipment status update
  const handleStatusUpdate = async (id: string, status: string) => {
    try {
      const response = await fetch(`/api/shipment/${id}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ status }),
      });
      
      if (!response.ok) {
        throw new Error('Failed to update shipment status');
      }
      
      // No need to manually refresh - WebSocket will trigger refresh
    } catch (error) {
      console.error('Error updating shipment status:', error);
      throw error;
    }
  };

  return (
    <Container maxWidth="xl" sx={{ py: 4 }}>
      <Box sx={{ mb: 4 }}>
        <ShipmentsGrid 
          rows={shipments} 
          onStatusUpdate={handleStatusUpdate}
        />
      </Box>
      <BlockToast />
    </Container>
  );
}