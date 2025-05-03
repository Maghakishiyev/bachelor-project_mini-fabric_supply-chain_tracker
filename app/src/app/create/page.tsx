'use client';

import React from 'react';
import { Container } from '@mui/material';
import ShipmentForm from '@/src/components/ShipmentForm';
import { ShipmentInput } from '@/src/types/shipment';

export default function CreateShipmentPage() {
  // Handle form submission
  const handleSubmit = async (data: ShipmentInput) => {
    try {
      const response = await fetch('/api/shipment', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(data),
      });

      const result = await response.json();
      
      if (!response.ok) {
        return { 
          success: false, 
          error: result.error || 'Failed to create shipment' 
        };
      }
      
      return { success: true };
    } catch (error) {
      console.error('Error creating shipment:', error);
      return { 
        success: false, 
        error: 'An unexpected error occurred' 
      };
    }
  };

  return (
    <Container maxWidth="lg" sx={{ py: 4 }}>
      <ShipmentForm onSubmit={handleSubmit} />
    </Container>
  );
}