'use client';

import React, { useEffect, useState } from 'react';
import { 
  Container, 
  Paper, 
  Typography, 
  Box, 
  Grid, 
  Chip, 
  Button,
  Divider,
  CircularProgress,
  Stepper,
  Step,
  StepLabel,
  StepContent,
  Alert
} from '@mui/material';
import { useRouter } from 'next/navigation';
import { Shipment, ShipmentStatus, BlockchainWrite } from '@/src/types/shipment';
import { connectWS, extractShipmentWrites } from '@/src/lib/ws';

interface DetailPageProps {
  params: {
    id: string;
  };
}

export default function ShipmentDetailPage({ params }: DetailPageProps) {
  const { id } = params;
  const router = useRouter();
  const [shipment, setShipment] = useState<Shipment | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  useEffect(() => {
    fetchShipment();

    // Setup WebSocket connection for real-time updates
    connectWS((event) => {
      try {
        const blockData = JSON.parse(event.data);
        const writes = extractShipmentWrites(blockData);
        
        // Check if this shipment was updated
        const thisShipmentUpdated = writes.some((w: BlockchainWrite) => w.key === id);
        if (thisShipmentUpdated) {
          setRefreshTrigger(prev => prev + 1);
        }
      } catch (err) {
        console.error('Error processing WebSocket message:', err);
      }
    });
  }, [id, refreshTrigger]);

  const fetchShipment = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const response = await fetch(`/api/shipment/${id}`);
      
      if (!response.ok) {
        if (response.status === 404) {
          setError(`Shipment with ID ${id} not found`);
        } else {
          setError('Failed to fetch shipment details');
        }
        return;
      }
      
      const data = await response.json();
      setShipment(data);
    } catch (err) {
      console.error('Error fetching shipment:', err);
      setError('An unexpected error occurred');
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case ShipmentStatus.CREATED:
        return '#3f51b5'; // Blue
      case ShipmentStatus.PICKED_UP:
        return '#ff9800'; // Orange
      case ShipmentStatus.IN_TRANSIT:
        return '#ffeb3b'; // Yellow
      case ShipmentStatus.DELIVERED:
        return '#4caf50'; // Green
      case ShipmentStatus.EXCEPTION:
        return '#f44336'; // Red
      default:
        return '#9e9e9e'; // Grey
    }
  };

  const getStatusStep = (status: string) => {
    switch (status) {
      case ShipmentStatus.CREATED:
        return 0;
      case ShipmentStatus.PICKED_UP:
        return 1;
      case ShipmentStatus.IN_TRANSIT:
        return 2;
      case ShipmentStatus.DELIVERED:
        return 3;
      case ShipmentStatus.EXCEPTION:
        return 2; // Special case, can happen during transit
      default:
        return 0;
    }
  };

  // Handle going back to dashboard
  const handleBack = () => {
    router.push('/');
  };

  if (loading) {
    return (
      <Container maxWidth="md" sx={{ py: 8, textAlign: 'center' }}>
        <CircularProgress />
        <Typography sx={{ mt: 2 }}>Loading shipment details...</Typography>
      </Container>
    );
  }

  if (error) {
    return (
      <Container maxWidth="md" sx={{ py: 4 }}>
        <Alert severity="error" sx={{ mb: 3 }}>{error}</Alert>
        <Button variant="contained" onClick={handleBack}>Return to Dashboard</Button>
      </Container>
    );
  }

  if (!shipment) {
    return (
      <Container maxWidth="md" sx={{ py: 4 }}>
        <Alert severity="warning" sx={{ mb: 3 }}>Shipment not found</Alert>
        <Button variant="contained" onClick={handleBack}>Return to Dashboard</Button>
      </Container>
    );
  }

  return (
    <Container maxWidth="md" sx={{ py: 4 }}>
      <Paper elevation={3} sx={{ p: 4 }}>
        <Typography variant="h4" gutterBottom>
          Shipment Details
        </Typography>
        
        <Box sx={{ mb: 4 }}>
          <Grid container spacing={2}>
            <Grid item xs={12} sm={6}>
              <Typography variant="subtitle2" color="text.secondary">Shipment ID</Typography>
              <Typography variant="h6">{shipment.id}</Typography>
            </Grid>
            <Grid item xs={12} sm={6}>
              <Typography variant="subtitle2" color="text.secondary">Status</Typography>
              <Chip 
                label={shipment.status} 
                style={{ 
                  backgroundColor: getStatusColor(shipment.status),
                  color: 'white',
                  fontWeight: 'bold'
                }}
              />
            </Grid>
            <Grid item xs={12} sm={6}>
              <Typography variant="subtitle2" color="text.secondary">Origin</Typography>
              <Typography variant="body1">{shipment.origin}</Typography>
            </Grid>
            <Grid item xs={12} sm={6}>
              <Typography variant="subtitle2" color="text.secondary">Destination</Typography>
              <Typography variant="body1">{shipment.destination}</Typography>
            </Grid>
            <Grid item xs={12} sm={6}>
              <Typography variant="subtitle2" color="text.secondary">Current Owner</Typography>
              <Typography variant="body1">{shipment.owner_msp}</Typography>
            </Grid>
            <Grid item xs={12} sm={6}>
              <Typography variant="subtitle2" color="text.secondary">Last Updated</Typography>
              <Typography variant="body1">
                {new Date(shipment.last_update).toLocaleString()}
              </Typography>
            </Grid>
          </Grid>
        </Box>
        
        <Divider sx={{ my: 3 }} />
        
        <Typography variant="h5" gutterBottom>Shipment Journey</Typography>
        
        <Box sx={{ maxWidth: 600, mx: 'auto', my: 3 }}>
          <Stepper activeStep={getStatusStep(shipment.status)} orientation="vertical">
            <Step>
              <StepLabel>Created</StepLabel>
              <StepContent>
                <Typography>
                  Shipment has been created and is waiting for pickup.
                </Typography>
              </StepContent>
            </Step>
            <Step>
              <StepLabel>Picked Up</StepLabel>
              <StepContent>
                <Typography>
                  Shipment has been picked up by the transporter.
                </Typography>
              </StepContent>
            </Step>
            <Step>
              <StepLabel>In Transit</StepLabel>
              <StepContent>
                <Typography>
                  Shipment is in transit from {shipment.origin} to {shipment.destination}.
                </Typography>
              </StepContent>
            </Step>
            <Step>
              <StepLabel>Delivered</StepLabel>
              <StepContent>
                <Typography>
                  Shipment has been delivered successfully to its destination.
                </Typography>
              </StepContent>
            </Step>
          </Stepper>
        </Box>
        
        <Box sx={{ mt: 4, display: 'flex', justifyContent: 'flex-start' }}>
          <Button variant="outlined" onClick={handleBack}>
            Back to Dashboard
          </Button>
        </Box>
      </Paper>
    </Container>
  );
}